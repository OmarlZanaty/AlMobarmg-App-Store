from __future__ import annotations

import asyncio
import json
import logging
import uuid

import stripe
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.config import settings
from backend.database import get_db
from backend.middleware.auth import get_current_developer, get_current_user
from backend.models.enums import FixRejectionStatus, SubscriptionPlan, SubscriptionStatus
from backend.models.fix_rejection_report import FixRejectionReport
from backend.models.subscription import Subscription
from backend.models.user import User
from backend.services.storage_service import storage_service
from backend.workers.fix_rejection import process_fix_rejection

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/payments", tags=["payments"])

stripe.api_key = settings.stripe_secret_key

PLAN_PRICE_IDS = {
    SubscriptionPlan.pro: "price_pro_monthly",
    SubscriptionPlan.studio: "price_studio_monthly",
}


class CreateSubscriptionRequest(BaseModel):
    plan: SubscriptionPlan


@router.post("/fix-rejection")
async def create_fix_rejection_payment(
    rejection_reason: str = Form(..., min_length=20),
    android_file: UploadFile | None = File(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    android_file_url: str | None = None

    if android_file is not None:
        file_bytes = await android_file.read()
        if not file_bytes:
            raise HTTPException(status_code=400, detail="android_file cannot be empty")
        filename = android_file.filename or f"fix_rejection_{uuid.uuid4().hex}.apk"
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "apk"
        android_file_url = await storage_service.upload_file(
            file_bytes=file_bytes,
            filename=f"fix_rejection_{uuid.uuid4().hex}.{ext}",
            content_type=android_file.content_type or "application/octet-stream",
            folder=f"fix-rejection/{current_user.id}",
        )

    payment_intent = await asyncio.to_thread(
        stripe.PaymentIntent.create,
        amount=499,
        currency="usd",
        automatic_payment_methods={"enabled": True},
        metadata={"feature": "fix_rejection", "developer_id": str(current_user.id)},
    )

    report = FixRejectionReport(
        developer_id=current_user.id,
        rejection_reason=rejection_reason.strip(),
        stripe_payment_intent_id=payment_intent.id,
        status=FixRejectionStatus.pending_payment,
        mobsf_findings={"android_file_url": android_file_url} if android_file_url else {},
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    return {
        "payment_intent_client_secret": payment_intent.client_secret,
        "report_id": str(report.id),
    }


@router.post("/webhook")
async def stripe_webhook(request: Request, db: AsyncSession = Depends(get_db)) -> dict[str, bool]:
    payload = await request.body()
    signature = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(payload=payload, sig_header=signature, secret=settings.stripe_webhook_secret)
    except Exception:
        logger.exception("Invalid Stripe webhook")
        return {"received": True}

    event_type = event.get("type", "")
    event_data = event.get("data", {}).get("object", {})
    payment_intent_id = event_data.get("id")

    if not payment_intent_id:
        return {"received": True}

    result = await db.execute(
        select(FixRejectionReport).where(FixRejectionReport.stripe_payment_intent_id == payment_intent_id)
    )
    report = result.scalar_one_or_none()

    if report is None:
        return {"received": True}

    if event_type == "payment_intent.succeeded":
        report.status = FixRejectionStatus.processing
        await db.commit()
        process_fix_rejection.delay(str(report.id))
    elif event_type == "payment_intent.payment_failed":
        report.status = FixRejectionStatus.failed
        await db.commit()

    return {"received": True}


@router.post("/create-subscription")
async def create_subscription(
    payload: CreateSubscriptionRequest,
    current_developer: User = Depends(get_current_developer),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str | None]:
    if payload.plan not in {SubscriptionPlan.pro, SubscriptionPlan.studio}:
        raise HTTPException(status_code=400, detail="Invalid plan")

    existing = await db.execute(
        select(Subscription).where(Subscription.developer_id == current_developer.id).order_by(Subscription.created_at.desc())
    )
    latest = existing.scalar_one_or_none()
    customer_id = latest.stripe_customer_id if latest and latest.stripe_customer_id else None

    if not customer_id:
        customer = await asyncio.to_thread(
            stripe.Customer.create,
            email=current_developer.email,
            metadata={"developer_id": str(current_developer.id)},
        )
        customer_id = customer.id

    price_id = PLAN_PRICE_IDS[payload.plan]
    stripe_subscription = await asyncio.to_thread(
        stripe.Subscription.create,
        customer=customer_id,
        items=[{"price": price_id}],
        payment_behavior="default_incomplete",
        payment_settings={"save_default_payment_method": "on_subscription"},
        expand=["latest_invoice.payment_intent"],
        metadata={"developer_id": str(current_developer.id), "plan": payload.plan.value},
    )

    latest_invoice = stripe_subscription.get("latest_invoice") or {}
    payment_intent = latest_invoice.get("payment_intent") or {}
    client_secret = payment_intent.get("client_secret")

    subscription = Subscription(
        developer_id=current_developer.id,
        plan=payload.plan,
        status=SubscriptionStatus.active,
        stripe_customer_id=customer_id,
        stripe_subscription_id=stripe_subscription.id,
    )
    db.add(subscription)
    await db.commit()

    return {"subscription_id": stripe_subscription.id, "client_secret": client_secret}


@router.post("/portal")
async def create_billing_portal(
    current_developer: User = Depends(get_current_developer),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    result = await db.execute(
        select(Subscription)
        .where(Subscription.developer_id == current_developer.id)
        .where(Subscription.stripe_customer_id.is_not(None))
        .order_by(Subscription.created_at.desc())
    )
    subscription = result.scalar_one_or_none()
    if subscription is None or not subscription.stripe_customer_id:
        raise HTTPException(status_code=404, detail="No Stripe customer found")

    session = await asyncio.to_thread(
        stripe.billing_portal.Session.create,
        customer=subscription.stripe_customer_id,
        return_url=settings.frontend_url,
    )
    return {"url": session.url}
