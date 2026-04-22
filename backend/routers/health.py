from __future__ import annotations

import asyncio
import shutil
import time
from datetime import UTC, datetime

import httpx
from fastapi import APIRouter
from sqlalchemy import text

from backend.config import settings
from backend.database import engine
from backend.services.auth_service import redis_client
from backend.workers.celery_app import celery_app

router = APIRouter(prefix="/health", tags=["health"])


async def _check_database() -> tuple[dict[str, float | str], bool]:
    started = time.perf_counter()
    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        status = "ok" if latency_ms < 200 else "slow"
        return {"status": status, "latency_ms": latency_ms}, False
    except Exception:
        return {"status": "error", "latency_ms": round((time.perf_counter() - started) * 1000, 2)}, True


async def _check_redis() -> tuple[dict[str, float | str], bool]:
    started = time.perf_counter()
    try:
        await redis_client.ping()
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        status = "ok" if latency_ms < 100 else "slow"
        return {"status": status, "latency_ms": latency_ms}, False
    except Exception:
        return {"status": "error", "latency_ms": round((time.perf_counter() - started) * 1000, 2)}, True


async def _check_mobsf() -> tuple[dict[str, float | str], bool]:
    started = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(settings.mobsf_url)
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        if response.status_code >= 500 or latency_ms >= 5000:
            return {"status": "error", "latency_ms": latency_ms}, True
        return {"status": "ok", "latency_ms": latency_ms}, False
    except Exception:
        return {"status": "error", "latency_ms": round((time.perf_counter() - started) * 1000, 2)}, True


async def _check_celery() -> tuple[dict[str, str], bool]:
    try:
        inspect = celery_app.control.inspect()
        active = await asyncio.to_thread(inspect.active)
        if active:
            return {"status": "ok"}, False
        return {"status": "no_workers"}, True
    except Exception:
        return {"status": "no_workers"}, True


def _check_disk() -> tuple[dict[str, float | str], bool]:
    try:
        total, used, _ = shutil.disk_usage("/home/ubuntu")
        used_pct = round((used / total) * 100, 2)
        if used_pct > 80:
            return {"status": "warn", "used_pct": used_pct}, True
        return {"status": "ok", "used_pct": used_pct}, False
    except Exception:
        return {"status": "error", "used_pct": -1}, True


async def _build_health_payload() -> dict[str, object]:
    database, db_failed = await _check_database()
    redis, redis_failed = await _check_redis()
    mobsf, mobsf_failed = await _check_mobsf()
    celery, celery_failed = await _check_celery()
    disk, disk_warn = _check_disk()

    if db_failed or redis_failed:
        overall_status = "unhealthy"
    elif mobsf_failed or celery_failed or disk_warn:
        overall_status = "degraded"
    else:
        overall_status = "healthy"

    return {
        "status": overall_status,
        "timestamp": datetime.now(UTC).isoformat(),
        "components": {
            "database": database,
            "redis": redis,
            "mobsf": mobsf,
            "celery": celery,
            "disk": disk,
        },
    }


@router.get("")
async def health() -> dict[str, str]:
    payload = await _build_health_payload()
    return {"status": str(payload["status"]), "timestamp": str(payload["timestamp"])}


@router.get("/detailed")
async def detailed_health() -> dict[str, object]:
    return await _build_health_payload()
