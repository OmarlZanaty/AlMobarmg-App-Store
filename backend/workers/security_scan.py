from __future__ import annotations

import asyncio
import json
import logging
import tempfile
import uuid
from collections.abc import Iterable
from pathlib import Path
from typing import Any

import httpx
import resend
from sqlalchemy import select

from backend.config import settings
from backend.database import AsyncSessionLocal
from backend.models.app import App
from backend.models.enums import AppStatus, RiskLevel
from backend.models.security_report import SecurityReport
from backend.models.user import User
from backend.services.storage_service import storage_service
from backend.workers.celery_app import celery_app

logger = logging.getLogger(__name__)

DANGEROUS_PERMISSIONS = {
    "SEND_SMS",
    "READ_CONTACTS",
    "RECORD_AUDIO",
    "ACCESS_FINE_LOCATION",
    "CAMERA",
    "READ_CALL_LOG",
    "PROCESS_OUTGOING_CALLS",
}


async def _download_to_temp(url: str, destination: Path) -> None:
    signed = await storage_service.generate_signed_url(url, expires_seconds=1800)
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.get(signed)
        response.raise_for_status()
        destination.write_bytes(response.content)


async def _mobsf_scan(file_path: Path) -> dict[str, Any]:
    headers = {"Authorization": settings.mobsf_api_key}

    async with httpx.AsyncClient(timeout=90.0) as client:
        with file_path.open("rb") as fp:
            upload_resp = await client.post(
                f"{settings.mobsf_url.rstrip('/')}/api/v1/upload",
                headers=headers,
                files={"file": (file_path.name, fp, "application/octet-stream")},
            )
        upload_resp.raise_for_status()
        upload_data = upload_resp.json()

        scan_payload = {
            "scan_type": upload_data.get("scan_type", "apk"),
            "file_name": upload_data.get("file_name", file_path.name),
            "hash": upload_data.get("hash"),
            "re_scan": "0",
        }
        scan_resp = await client.post(f"{settings.mobsf_url.rstrip('/')}/api/v1/scan", headers=headers, data=scan_payload)
        scan_resp.raise_for_status()

        report_payload = {
            "hash": scan_payload["hash"],
            "scan_type": scan_payload["scan_type"],
        }

        elapsed = 0
        while elapsed <= 900:
            report_resp = await client.post(
                f"{settings.mobsf_url.rstrip('/')}/api/v1/report_json",
                headers=headers,
                data=report_payload,
            )
            if report_resp.status_code == 200:
                body = report_resp.json()
                if body:
                    return body
            await asyncio.sleep(15)
            elapsed += 15

    raise TimeoutError("MobSF scan timeout")


async def _virustotal_scan(file_path: Path) -> dict[str, Any]:
    headers = {"x-apikey": settings.virustotal_api_key}
    async with httpx.AsyncClient(timeout=60.0) as client:
        with file_path.open("rb") as fp:
            submit = await client.post("https://www.virustotal.com/api/v3/files", headers=headers, files={"file": fp})
        submit.raise_for_status()
        analysis_id = submit.json().get("data", {}).get("id")
        if not analysis_id:
            return {"error": "Missing analysis id"}

        for _ in range(12):
            result = await client.get(f"https://www.virustotal.com/api/v3/analyses/{analysis_id}", headers=headers)
            if result.status_code == 200:
                data = result.json().get("data", {})
                attrs = data.get("attributes", {})
                if attrs.get("status") == "completed":
                    return result.json()
            await asyncio.sleep(15)

    return {"error": "VirusTotal timed out"}


def _extract_findings(mobsf_reports: Iterable[dict[str, Any]]) -> tuple[list[str], list[str], bool, bool]:
    dangerous: set[str] = set()
    suspicious_apis: set[str] = set()
    obfuscated = False
    excess_network = False

    for report in mobsf_reports:
        permissions = report.get("permissions") or report.get("permission") or {}
        if isinstance(permissions, dict):
            for perm in permissions.keys():
                short = perm.split(".")[-1]
                if short in DANGEROUS_PERMISSIONS:
                    dangerous.add(short)

        apis = report.get("urls") or report.get("api") or report.get("code_analysis", {})
        flat = json.dumps(apis).lower()
        if any(k in flat for k in ("runtime.exec", "dexclassloader", "loadlibrary", "reflection")):
            suspicious_apis.update(["runtime_exec", "dynamic_loading"])

        if "obfus" in json.dumps(report).lower():
            obfuscated = True

        if isinstance(report.get("domains"), list) and len(report.get("domains")) > 30:
            excess_network = True

    return sorted(dangerous), sorted(suspicious_apis), obfuscated, excess_network


def _calculate_score(
    dangerous_permissions: list[str],
    suspicious_apis: list[str],
    obfuscated: bool,
    excess_network: bool,
    vt_reports: Iterable[dict[str, Any]],
) -> int:
    score = 100
    score -= len(dangerous_permissions) * 8
    if suspicious_apis:
        score -= 15
    if obfuscated:
        score -= 10
    if excess_network:
        score -= 5

    vt_flagged = False
    for report in vt_reports:
        stats = report.get("data", {}).get("attributes", {}).get("stats", {})
        if (stats.get("malicious", 0) or 0) > 0:
            vt_flagged = True
            break

    if vt_flagged:
        score -= 50

    return max(score, 0)


def _risk_level(score: int) -> RiskLevel:
    if score >= 85:
        return RiskLevel.safe
    if score >= 65:
        return RiskLevel.low
    if score >= 45:
        return RiskLevel.medium
    if score >= 25:
        return RiskLevel.high
    return RiskLevel.critical


async def _generate_ai_reports(findings: dict[str, Any]) -> tuple[str, list[dict[str, Any]], dict[str, Any]]:
    if not settings.anthropic_api_key:
        return (
            "Automated scan completed. Please review permission and API findings before install.",
            [{"fix": "Review dangerous permissions and remove unused sensitive access."}],
            {"data_access": findings.get("dangerous_permissions", []), "note": "AI report unavailable"},
        )

    prompt = (
        "You are a mobile app security expert. Here are the MobSF security findings for an app: "
        f"{json.dumps(findings)[:12_000]}. "
        "Generate: 1) A 2-sentence user-friendly security summary, 2) Specific developer fix suggestions as JSON array, "
        "3) A user-readable breakdown of data access. Be factual, not alarmist. "
        "Respond strictly as JSON with keys ai_summary, ai_developer_report, ai_user_report."
    )

    headers = {"x-api-key": settings.anthropic_api_key, "anthropic-version": "2023-06-01"}
    payload = {
        "model": "claude-3-5-sonnet-20241022",
        "max_tokens": 900,
        "messages": [{"role": "user", "content": prompt}],
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload)
        response.raise_for_status()
        content = response.json().get("content", [])
        text_chunks = [c.get("text", "") for c in content if c.get("type") == "text"]
        parsed = json.loads("".join(text_chunks).strip())

    return (
        parsed.get("ai_summary", "Scan completed."),
        parsed.get("ai_developer_report", []),
        parsed.get("ai_user_report", {}),
    )


async def _send_scan_email(email: str, app_name: str, score: int, summary: str) -> None:
    resend.api_key = settings.resend_api_key
    if score >= 20:
        subject = f"Scan complete for {app_name}"
        html = f"<p>Your app scan is complete. Score: {score}/100. Under review.</p>"
    else:
        subject = f"High-risk scan result for {app_name}"
        html = f"<p>Your app was flagged as high-risk. Here's why: {summary}</p>"

    await asyncio.to_thread(
        resend.Emails.send,
        {"from": settings.email_from, "to": email, "subject": subject, "html": html},
    )


async def _set_app_pending_with_error(app_id: uuid.UUID, error_note: str) -> None:
    async with AsyncSessionLocal() as db:
        app = (await db.execute(select(App).where(App.id == app_id))).scalar_one_or_none()
        if app is None:
            return
        app.status = AppStatus.pending
        report = SecurityReport(
            app_id=app.id,
            score=0,
            risk_level=RiskLevel.critical,
            mobsf_raw={"error": error_note},
            virustotal_raw={},
            ai_summary=error_note,
            ai_developer_report={"error": error_note},
            ai_user_report={"error": error_note},
            dangerous_permissions=[],
            suspicious_apis=[],
        )
        db.add(report)
        await db.commit()


async def _scan_app_async(app_id: str) -> None:
    temp_files: list[Path] = []
    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError:
        logger.error("Invalid app_id for scan: %s", app_id)
        return

    try:
        async with AsyncSessionLocal() as db:
            app = (await db.execute(select(App).where(App.id == app_uuid))).scalar_one_or_none()
            if app is None:
                logger.error("App not found for scan: %s", app_id)
                return

            binary_urls = [
                u
                for u in [
                    app.android_file_url,
                    app.windows_file_url,
                    app.mac_file_url,
                    app.linux_deb_url,
                    app.linux_appimage_url,
                    app.linux_rpm_url,
                ]
                if u
            ]

            mobsf_reports: list[dict[str, Any]] = []
            vt_reports: list[dict[str, Any]] = []

            for idx, url in enumerate(binary_urls, start=1):
                tmp_file = Path(tempfile.gettempdir()) / f"scan_{app.id}_{idx}"
                temp_files.append(tmp_file)
                await _download_to_temp(url, tmp_file)

                try:
                    mobsf_result: dict[str, Any] | None = None
                    for attempt in range(3):
                        try:
                            mobsf_result = await _mobsf_scan(tmp_file)
                            break
                        except TimeoutError:
                            logger.warning("MobSF timeout attempt %s for app %s", attempt + 1, app_id)
                            if attempt == 2:
                                await _set_app_pending_with_error(app.id, "MobSF timeout after retries")
                                return
                        except Exception:
                            logger.exception("MobSF scan failed for app %s", app_id)
                            if attempt == 2:
                                await _set_app_pending_with_error(app.id, "MobSF scan failed repeatedly")
                                return

                    if mobsf_result:
                        mobsf_reports.append(mobsf_result)

                    try:
                        vt_reports.append(await _virustotal_scan(tmp_file))
                    except Exception:
                        logger.exception("VirusTotal failure for app %s", app_id)
                        vt_reports.append({"error": "VirusTotal failed"})
                except Exception:
                    logger.exception("Binary scan pipeline failed for app %s", app_id)
                    await _set_app_pending_with_error(app.id, "Binary scan pipeline failed")
                    return

            dangerous_permissions, suspicious_apis, obfuscated, excess_network = _extract_findings(mobsf_reports)

            score = _calculate_score(
                dangerous_permissions=dangerous_permissions,
                suspicious_apis=suspicious_apis,
                obfuscated=obfuscated,
                excess_network=excess_network,
                vt_reports=vt_reports,
            )
            risk = _risk_level(score)

            findings = {
                "dangerous_permissions": dangerous_permissions,
                "suspicious_apis": suspicious_apis,
                "obfuscated_code": obfuscated,
                "excess_network_connections": excess_network,
                "mobsf_reports_count": len(mobsf_reports),
                "vt_reports_count": len(vt_reports),
            }

            try:
                ai_summary, ai_developer_report, ai_user_report = await _generate_ai_reports(findings)
            except Exception:
                logger.exception("AI report generation failed for app %s", app_id)
                ai_summary = "Scan completed. Some high-risk behaviors were found. Review details before publishing."
                ai_developer_report = [{"fix": "Run manual code review for dangerous permissions and suspicious API usage."}]
                ai_user_report = {"data_access": dangerous_permissions, "note": "AI report unavailable"}

            report = SecurityReport(
                app_id=app.id,
                score=score,
                risk_level=risk,
                mobsf_raw={"reports": mobsf_reports},
                virustotal_raw={"reports": vt_reports},
                ai_summary=ai_summary,
                ai_developer_report=ai_developer_report,
                ai_user_report=ai_user_report,
                dangerous_permissions=dangerous_permissions,
                suspicious_apis=suspicious_apis,
            )
            db.add(report)

            app.security_score = score
            app.status = AppStatus.review if score >= 20 else AppStatus.rejected
            await db.commit()

            developer = (await db.execute(select(User).where(User.id == app.developer_id))).scalar_one_or_none()
            if developer:
                try:
                    await _send_scan_email(developer.email, app.name, score, ai_summary)
                except Exception:
                    logger.exception("Failed to send scan email for app %s", app_id)

    except Exception:
        logger.exception("Unexpected scan failure for app %s", app_id)
        try:
            await _set_app_pending_with_error(uuid.UUID(app_id), "Unexpected scan error")
        except Exception:
            logger.exception("Failed to set pending status after scan failure for app %s", app_id)
    finally:
        for temp_file in temp_files:
            try:
                if temp_file.exists():
                    temp_file.unlink()
            except OSError:
                logger.warning("Failed to cleanup temp file: %s", temp_file)


@celery_app.task(name="scan_app")
def scan_app(app_id: str) -> None:
    asyncio.run(_scan_app_async(app_id))
