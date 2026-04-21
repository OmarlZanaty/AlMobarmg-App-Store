from __future__ import annotations

import time

from fastapi import Request
from fastapi.responses import JSONResponse
from redis.asyncio import Redis
from starlette.middleware.base import BaseHTTPMiddleware

from backend.config import settings


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app) -> None:
        super().__init__(app)
        self.redis: Redis = Redis.from_url(settings.redis_url, decode_responses=True)
        self.general_limit = 60
        self.auth_limit = 5
        self.payments_limit = 10
        self.window_seconds = 60

    @staticmethod
    def _get_real_ip(request: Request) -> str:
        forwarded_for = request.headers.get("x-forwarded-for", "")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        if request.client and request.client.host:
            return request.client.host
        return "unknown"

    def _get_route_group_and_limit(self, path: str) -> tuple[str, int]:
        if path in {"/api/auth/login", "/api/auth/register"}:
            return "auth", self.auth_limit
        if path.startswith("/api/payments"):
            return "payments", self.payments_limit
        return "general", self.general_limit

    async def dispatch(self, request: Request, call_next):
        if request.url.path == "/health":
            return await call_next(request)

        route_group, limit = self._get_route_group_and_limit(request.url.path)
        ip = self._get_real_ip(request)
        key = f"ratelimit:{route_group}:{ip}"

        now = time.time()
        window_start = now - self.window_seconds

        async with self.redis.pipeline(transaction=True) as pipe:
            (
                pipe.zremrangebyscore(key, 0, window_start)
                .zcard(key)
                .zadd(key, {str(now): now})
                .expire(key, self.window_seconds)
            )
            _, current_count, _, _ = await pipe.execute()

        if current_count >= limit:
            retry_after = self.window_seconds
            headers = {"Retry-After": str(retry_after)}
            return JSONResponse(
                status_code=429,
                content={"error": "Rate limit exceeded. Please try again later."},
                headers=headers,
            )

        return await call_next(request)
