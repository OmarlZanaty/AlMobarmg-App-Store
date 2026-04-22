from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import UTC, datetime
from typing import Any

import resend
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from backend.config import settings
from backend.database import get_db
from backend.middleware.auth import get_current_admin
from backend.models.app import App
from backend.models.enums import AppStatus
from backend.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/admin", tags=["admin"], dependencies=[Depends(get_current_admin)])


class RejectRequest(BaseModel):
    reason: str = Field(min_length=20)


async def _send_admin_decision_email(to_email: str, app_name: str, approved: bool, reason: str | None = None) -> None:
    resend.api_key = settings.resend_api_key
    subject = f"App {'approved' if approved else 'rejected'}: {app_name}"
    html = (
        f"<p>Your app <strong>{app_name}</strong> has been approved and published.</p>"
        if approved
        else f"<p>Your app <strong>{app_name}</strong> has been rejected.</p><p>Reason: {reason}</p>"
    )
    await asyncio.to_thread(
        resend.Emails.send,
        {"from": settings.email_from, "to": to_email, "subject": subject, "html": html},
    )


@router.get("/queue", response_model=dict[str, Any])
async def review_queue(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    total = (await db.execute(select(func.count(App.id)).where(App.status == AppStatus.review))).scalar_one()
    apps = (
        await db.execute(
            select(App)
            .options(selectinload(App.security_reports), selectinload(App.developer))
            .where(App.status == AppStatus.review)
            .order_by(desc(App.created_at))
            .offset((page - 1) * limit)
            .limit(limit)
        )
    ).scalars().all()

    items: list[dict[str, Any]] = []
    for app in apps:
        report = max(app.security_reports, key=lambda item: item.scanned_at) if app.security_reports else None
        developer = app.developer

        items.append(
            {
                "app": {
                    "id": str(app.id),
                    "name": app.name,
                    "description": app.description,
                    "category": app.category,
                    "short_description": app.short_description,
                    "supported_platforms": app.supported_platforms,
                    "security_score": app.security_score,
                    "status": app.status.value,
                    "created_at": app.created_at.isoformat() if app.created_at else None,
                },
                "security_report_summary": (
                    {
                        "id": str(report.id),
                        "score": report.score,
                        "risk_level": report.risk_level.value,
                        "ai_summary": report.ai_summary,
                        "dangerous_permissions": report.dangerous_permissions,
                        "suspicious_apis": report.suspicious_apis,
                        "scanned_at": report.scanned_at.isoformat() if report.scanned_at else None,
                    }
                    if report
                    else None
                ),
                "developer": (
                    {
                        "id": str(developer.id),
                        "email": developer.email,
                        "reputation_score": developer.reputation_score,
                        "subscription_plan": developer.subscription_plan.value,
                    }
                    if developer
                    else None
                ),
            }
        )

    return {"page": page, "limit": limit, "total": total, "items": items}


@router.post("/apps/{app_id}/approve", response_model=dict[str, Any])
async def approve_app(app_id: str, db: AsyncSession = Depends(get_db)) -> dict[str, Any]:
    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid app_id") from exc

    app = (await db.execute(select(App).where(App.id == app_uuid))).scalar_one_or_none()
    if app is None:
        raise HTTPException(status_code=404, detail="App not found")
    if app.status != AppStatus.review:
        raise HTTPException(status_code=400, detail=f"App is in '{app.status.value}' status, not 'review'")

    developer = (await db.execute(select(User).where(User.id == app.developer_id))).scalar_one_or_none()

    app.status = AppStatus.approved
    app.published_at = datetime.now(UTC)
    await db.commit()

    if developer:
        try:
            await _send_admin_decision_email(developer.email, app.name, approved=True)
        except Exception:
            logger.exception("Failed sending approval email for app %s", app_id)

    return {
        "message": "App approved",
        "app": {
            "id": str(app.id),
            "status": app.status.value,
            "published_at": app.published_at.isoformat() if app.published_at else None,
        },
    }


@router.post("/apps/{app_id}/reject", response_model=dict[str, Any])
async def reject_app(app_id: str, payload: RejectRequest, db: AsyncSession = Depends(get_db)) -> dict[str, Any]:
    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid app_id") from exc

    app = (await db.execute(select(App).where(App.id == app_uuid))).scalar_one_or_none()
    if app is None:
        raise HTTPException(status_code=404, detail="App not found")
    if app.status not in {AppStatus.review, AppStatus.scanning}:
        raise HTTPException(status_code=400, detail=f"App cannot be rejected from '{app.status.value}' status")

    developer = (await db.execute(select(User).where(User.id == app.developer_id))).scalar_one_or_none()

    app.status = AppStatus.rejected
    await db.commit()

    if developer:
        try:
            await _send_admin_decision_email(developer.email, app.name, approved=False, reason=payload.reason)
        except Exception:
            logger.exception("Failed sending rejection email for app %s", app_id)

    return {
        "message": "App rejected",
        "app": {
            "id": str(app.id),
            "status": app.status.value,
            "published_at": app.published_at.isoformat() if app.published_at else None,
        },
    }
