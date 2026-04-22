from __future__ import annotations

import json
import time
from uuid import uuid4

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from backend.logging_config import get_logger

logger = get_logger("backend.request")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    _MASK_FIELDS = {"password", "new_password", "confirm_password", "current_password", "token", "secret"}

    async def dispatch(self, request: Request, call_next):
        if request.url.path in {"/health", "/favicon.ico"}:
            response = await call_next(request)
            response.headers["X-Request-ID"] = str(uuid4())
            return response

        request_id = str(uuid4())
        start = time.perf_counter()
        request_body = ""

        if request.method.upper() in {"POST", "PUT"}:
            body_bytes = await request.body()
            if body_bytes:
                parsed = self._parse_body(body_bytes)
                request_body = parsed[:500]

            async def receive() -> dict[str, object]:
                return {"type": "http.request", "body": body_bytes, "more_body": False}

            request = Request(request.scope, receive)

        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)

        client_ip = request.client.host if request.client else "unknown"
        log_entry = {
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
            "client_ip": client_ip,
        }
        if request_body:
            log_entry["request_body"] = request_body

        logger.info(json.dumps(log_entry, ensure_ascii=False))

        response.headers["X-Request-ID"] = request_id
        return response

    def _parse_body(self, body_bytes: bytes) -> str:
        try:
            body = json.loads(body_bytes)
            if isinstance(body, dict):
                masked = {key: ("***" if key.lower() in self._MASK_FIELDS else value) for key, value in body.items()}
                return json.dumps(masked, ensure_ascii=False)
            return json.dumps(body, ensure_ascii=False)
        except Exception:
            return body_bytes.decode("utf-8", errors="replace")
