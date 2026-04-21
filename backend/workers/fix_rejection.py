from __future__ import annotations

import asyncio
import json
import logging
import tempfile
import uuid
from pathlib import Path
from typing import Any

import httpx
import resend
from celery import Celery
from sqlalchemy import select

from backend.config import settings
from backend.database import AsyncSessionLocal
from backend.models.enums import FixRejectionStatus
from backend.models.fix_rejection_report import FixRejectionReport
from backend.models.user import User
from backend.services.storage_service import storage_service
from backend.workers.security_scan import _mobsf_scan, _virustotal_scan

logger = logging.getLogger(__name__)

celery_app = Celery("fix_rejection", broker=settings.redis_url, backend=settings.redis_url)


async def _download_to_temp(url: str, destination: Path) -> None:
    signed = await storage_service.generate_signed_url(url, expires_seconds=1800)
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.get(signed)
        response.raise_for_status()
        destination.write_bytes(response.content)


def _summarize_mobsf_findings(report: dict[str, Any]) -> str:
    permissions = report.get("permissions") or report.get("permission") or {}
    perm_list = list(permissions.keys())[:20] if isinstance(permissions, dict) else []
    code_analysis = report.get("code_analysis") or {}
    trackers = report.get("trackers") or []
    return json.dumps(
        {
            "permissions": perm_list,
            "high_level_issues": code_analysis if isinstance(code_analysis, dict) else str(code_analysis)[:2000],
            "trackers_count": len(trackers) if isinstance(trackers, list) else 0,
        }
    )


async def _ai_diagnosis(
    rejection_reason: str,
    mobsf_findings_summary: str,
    vt_result: dict[str, Any],
) -> dict[str, Any]:
    if not settings.anthropic_api_key:
        return {
            "rejection_type": "technical_issue",
            "root_cause": "Anthropic API key is missing, so full AI diagnosis is unavailable.",
            "specific_issues": ["AI provider is not configured"],
            "fix_steps": [{"step": 1, "action": "Configure ANTHROPIC_API_KEY", "code_example": "ANTHROPIC_API_KEY=..."}],
            "can_publish_on_almobarmg": False,
            "almobarmg_reason": "Cannot complete policy-grade diagnosis without AI analysis.",
            "estimated_fix_time": "1 hour",
        }

    prompt = (
        f"A developer received this rejection from Google Play Store: {rejection_reason}\n\n"
        f"The app has these security findings from MobSF: {mobsf_findings_summary}\n"
        f"VirusTotal result: {json.dumps(vt_result)[:7000]}\n\n"
        "Analyze and respond with JSON only:\n"
        "{\n"
        "  'rejection_type': 'policy_violation | security_issue | technical_issue | mixed',\n"
        "  'root_cause': 'one clear sentence explaining the main cause',\n"
        "  'specific_issues': ['issue 1', 'issue 2', ...],\n"
        "  'fix_steps': [{'step': 1, 'action': '...', 'code_example': '...'}, ...],\n"
        "  'can_publish_on_almobarmg': true/false,\n"
        "  'almobarmg_reason': 'why it can or cannot be published on Al Mobarmg',\n"
        "  'estimated_fix_time': 'X hours/days'\n"
        "}"
    )

    headers = {"x-api-key": settings.anthropic_api_key, "anthropic-version": "2023-06-01"}
    payload = {
        "model": "claude-3-5-sonnet-20241022",
        "max_tokens": 1300,
        "messages": [{"role": "user", "content": prompt}],
    }

    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload)
        response.raise_for_status()
        content = response.json().get("content", [])
        text = "".join(chunk.get("text", "") for chunk in content if chunk.get("type") == "text").strip()

    cleaned = text.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    return json.loads(cleaned)


async def _send_email(to_email: str, diagnosis: dict[str, Any]) -> None:
    resend.api_key = settings.resend_api_key
    steps = diagnosis.get("fix_steps") or []
    steps_html = "".join(
        f"<li><strong>Step {step.get('step', i)}:</strong> {step.get('action', '')}<br/><pre>{step.get('code_example', '')}</pre></li>"
        for i, step in enumerate(steps, start=1)
    )

    html = f"""
    <h2>Fix My Rejection Report</h2>
    <p><strong>Rejection Type:</strong> {diagnosis.get('rejection_type', 'unknown')}</p>
    <p><strong>Root Cause:</strong> {diagnosis.get('root_cause', 'N/A')}</p>
    <p><strong>Can be published on Al Mobarmg:</strong> {'YES' if diagnosis.get('can_publish_on_almobarmg') else 'NO'}</p>
    <p><strong>Reason:</strong> {diagnosis.get('almobarmg_reason', 'N/A')}</p>
    <p><strong>Estimated fix time:</strong> {diagnosis.get('estimated_fix_time', 'N/A')}</p>
    <h3>Fix Steps</h3>
    <ol>{steps_html}</ol>
    """

    await asyncio.to_thread(
        resend.Emails.send,
        {"from": settings.email_from, "to": to_email, "subject": "Your Fix My Rejection report", "html": html},
    )


async def _process(report_id: str) -> None:
    temp_file: Path | None = None

    try:
        report_uuid = uuid.UUID(report_id)
    except ValueError:
        logger.error("Invalid report_id for fix rejection", extra={"report_id": report_id})
        return

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(FixRejectionReport).where(FixRejectionReport.id == report_uuid))
        report = result.scalar_one_or_none()
        if report is None:
            logger.error("Fix rejection report not found", extra={"report_id": report_id})
            return

        developer_result = await db.execute(select(User).where(User.id == report.developer_id))
        developer = developer_result.scalar_one_or_none()
        if developer is None:
            logger.error("Developer not found", extra={"developer_id": str(report.developer_id)})
            return

        android_file_url = (report.mobsf_findings or {}).get("android_file_url")

        mobsf_report: dict[str, Any] = {}
        vt_result: dict[str, Any] = {}

        try:
            if android_file_url:
                with tempfile.NamedTemporaryFile(prefix="fix_rejection_", suffix=".apk", delete=False) as fp:
                    temp_file = Path(fp.name)

                await _download_to_temp(android_file_url, temp_file)
                mobsf_report = await _mobsf_scan(temp_file)
                vt_result = await _virustotal_scan(temp_file)

            mobsf_summary = _summarize_mobsf_findings(mobsf_report) if mobsf_report else "No Android binary uploaded"
            diagnosis = await _ai_diagnosis(report.rejection_reason, mobsf_summary, vt_result)

            report.mobsf_findings = {
                **(report.mobsf_findings or {}),
                "mobsf_raw": mobsf_report,
                "mobsf_findings_summary": mobsf_summary,
                "virustotal_result": vt_result,
            }
            report.ai_diagnosis = diagnosis
            report.status = FixRejectionStatus.completed
            await db.commit()

            await _send_email(developer.email, diagnosis)

        except Exception as exc:
            logger.exception("Fix rejection processing failed", extra={"report_id": report_id})
            report.ai_diagnosis = {"error": str(exc)}
            report.status = "failed"
            await db.commit()

    if temp_file and temp_file.exists():
        temp_file.unlink(missing_ok=True)


@celery_app.task(name="process_fix_rejection")
def process_fix_rejection(report_id: str) -> None:
    asyncio.run(_process(report_id))
