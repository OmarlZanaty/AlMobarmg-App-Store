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
from backend.workers import celery_app

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
        verdict = "completed"
        subject = "Security scan completed"
    else:
        verdict = "rejected"
        subject = "Security scan found critical risks"

    html = f"""
    <h2>App Security Scan Result</h2>
    <p><strong>App:</strong> {app_name}</p>
    <p><strong>Verdict:</strong> {verdict}</p>
    <p><strong>Security Score:</strong> {score}/100</p>
    <p><strong>Summary:</strong> {summary}</p>
    """

    await asyncio.to_thread(
        resend.Emails.send,
        {
            "from": settings.email_from,
            "to": email,
            "subject": subject,
            "html": html,
        },
    )


async def _scan(app_id: str) -> None:
    temp_file: Path | None = None

    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError:
        logger.error("Invalid app_id", extra={"app_id": app_id})
        return

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(App).where(App.id == app_uuid))
        app = result.scalar_one_or_none()
        if app is None:
            logger.error("App not found", extra={"app_id": app_id})
            return

        user_result = await db.execute(select(User).where(User.id == app.developer_id))
        developer = user_result.scalar_one_or_none()
        if developer is None:
            logger.error("Developer not found", extra={"developer_id": str(app.developer_id)})
            return

        report_result = await db.execute(select(SecurityReport).where(SecurityReport.app_id == app.id))
        report = report_result.scalar_one_or_none()

        if report is None:
            report = SecurityReport(app_id=app.id)
            db.add(report)
            await db.flush()

        app.status = AppStatus.reviewing
        await db.commit()

        try:
            if not app.android_file_url:
                raise ValueError("Android file URL is missing")

            with tempfile.NamedTemporaryFile(prefix="scan_", suffix=".apk", delete=False) as fp:
                temp_file = Path(fp.name)

            await _download_to_temp(app.android_file_url, temp_file)

            mobsf_report = await _mobsf_scan(temp_file)
            vt_report = await _virustotal_scan(temp_file)

            dangerous_permissions, suspicious_apis, obfuscated, excess_network = _extract_findings([mobsf_report])
            score = _calculate_score(
                dangerous_permissions,
                suspicious_apis,
                obfuscated,
                excess_network,
                [vt_report],
            )
            risk = _risk_level(score)

            findings = {
                "dangerous_permissions": dangerous_permissions,
                "suspicious_apis": suspicious_apis,
                "obfuscated_code": obfuscated,
                "excessive_network_calls": excess_network,
                "mobsf_raw": mobsf_report,
                "virustotal_result": vt_report,
            }

            ai_summary, ai_dev, ai_user = await _generate_ai_reports(findings)

            report.security_score = score
            report.risk_level = risk
            report.dangerous_permissions = dangerous_permissions
            report.suspicious_apis = suspicious_apis
            report.obfuscated_code = obfuscated
            report.excessive_network_calls = excess_network
            report.virustotal_result = vt_report
            report.ai_summary = ai_summary
            report.ai_developer_report = ai_dev
            report.ai_user_report = ai_user

            if score < 20:
                app.status = AppStatus.rejected
            else:
                app.status = AppStatus.published

            await db.commit()

            await _send_scan_email(developer.email, app.name, score, ai_summary)

        except Exception as exc:
            logger.exception("Security scan failed", extra={"app_id": app_id})
            report.ai_summary = f"Scan failed: {exc}"
            report.risk_level = RiskLevel.critical
            report.security_score = 0
            app.status = AppStatus.rejected
            await db.commit()

    if temp_file and temp_file.exists():
        temp_file.unlink(missing_ok=True)


@celery_app.task(name="scan_app")
def scan_app(app_id: str) -> None:
    asyncio.run(_scan(app_id))
