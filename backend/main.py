from __future__ import annotations

import logging.config
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from backend.config import settings
from backend.database import engine
from backend.logging_config import get_logging_config
from backend.middleware.rate_limit import RateLimitMiddleware
from backend.routers.admin import router as admin_router
from backend.routers.apps import router as apps_router
from backend.routers.auth import router as auth_router
from backend.routers.payments import router as payments_router
from backend.services.auth_service import redis_client

logging.config.dictConfig(get_logging_config())


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        return response


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise RuntimeError("Database connection failed during startup") from exc
    yield
    await engine.dispose()
    await redis_client.close()


app = FastAPI(title="Al Mobarmg Store API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["34.242.156.156", "localhost", "127.0.0.1"],
)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_url],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(apps_router)
app.include_router(admin_router)
app.include_router(payments_router)


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"error": "Validation failed", "details": exc.errors()},
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(_: Request, exc: SQLAlchemyError) -> JSONResponse:
    return JSONResponse(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, content={"error": str(exc)})


@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, __: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "Internal server error"},
    )


@app.get("/health")
async def health() -> dict[str, str]:
    database = "ok"
    redis = "ok"
    mobsf = "ok"

    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
    except Exception:
        database = "error"

    try:
        await redis_client.ping()
    except Exception:
        redis = "error"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(settings.mobsf_url)
            if response.status_code >= 500:
                mobsf = "error"
    except Exception:
        mobsf = "error"

    return {"status": "ok", "database": database, "redis": redis, "mobsf": mobsf}
