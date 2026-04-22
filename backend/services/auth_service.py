from __future__ import annotations

import asyncio
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import resend
from jose import JWTError, jwt
from passlib.context import CryptContext
from redis.asyncio import Redis

from backend.config import settings

pwd_context = CryptContext(schemes=["pbkdf2_sha256", "bcrypt"], deprecated="auto")
redis_client: Redis = Redis.from_url(settings.redis_url, decode_responses=True)

ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7
OTP_TTL_SECONDS = 10 * 60
RESET_TOKEN_TTL_SECONDS = 60 * 60


async def hash_password(password: str) -> str:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, pwd_context.hash, password)


async def verify_password(plain: str, hashed: str) -> bool:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, pwd_context.verify, plain, hashed)


def create_access_token(user_id: str, role: str) -> str:
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": user_id,
        "role": role,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_refresh_token(user_id: str, role: str) -> str:
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": user_id,
        "role": role,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
    }
    return jwt.encode(payload, settings.jwt_refresh_secret, algorithm="HS256")


async def store_refresh_token(user_id: str, token: str) -> None:
    # Improvement: store SHA256(token) in Redis for defense in depth.
    await redis_client.set(f"refresh:{user_id}", token, ex=REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60)


async def verify_refresh_token(user_id: str, token: str) -> bool:
    stored_token = await redis_client.get(f"refresh:{user_id}")
    return bool(stored_token and secrets.compare_digest(stored_token, token))


async def delete_refresh_token(user_id: str) -> None:
    await redis_client.delete(f"refresh:{user_id}")


async def generate_otp(email: str) -> str:
    otp = f"{secrets.randbelow(1_000_000):06d}"
    await redis_client.set(f"otp:{email.lower()}", otp, ex=OTP_TTL_SECONDS)
    return otp


async def verify_otp(email: str, otp: str) -> bool:
    stored_otp = await redis_client.get(f"otp:{email.lower()}")
    return bool(stored_otp and secrets.compare_digest(stored_otp, otp))


async def generate_reset_token(email: str) -> str:
    token = secrets.token_hex(16)
    await redis_client.set(f"reset:{email.lower()}", token, ex=RESET_TOKEN_TTL_SECONDS)
    return token


async def verify_reset_token(email: str, token: str) -> bool:
    stored_token = await redis_client.get(f"reset:{email.lower()}")
    return bool(stored_token and secrets.compare_digest(stored_token, token))


async def send_verification_email(email: str, otp: str, name: str) -> None:
    resend.api_key = settings.resend_api_key
    html = (
        f"<h2>Welcome, {name}</h2>"
        "<p>Your verification code is:</p>"
        f"<h1>{otp}</h1>"
        "<p>This code expires in 10 minutes.</p>"
    )
    await asyncio.to_thread(
        resend.Emails.send,
        {
            "from": settings.email_from,
            "to": email,
            "subject": "Verify your email - Al Mobarmg Store",
            "html": html,
        },
    )


async def send_password_reset_email(email: str, token: str) -> None:
    resend.api_key = settings.resend_api_key
    reset_url = f"{settings.frontend_url.rstrip('/')}/reset-password?email={email}&token={token}"
    html = (
        "<h2>Password reset requested</h2>"
        f"<p>Click here to reset your password:</p><p><a href=\"{reset_url}\">Reset password</a></p>"
        "<p>This link expires in 1 hour.</p>"
    )
    await asyncio.to_thread(
        resend.Emails.send,
        {
            "from": settings.email_from,
            "to": email,
            "subject": "Reset your password - Al Mobarmg Store",
            "html": html,
        },
    )


async def send_welcome_email(email: str, name: str) -> None:
    resend.api_key = settings.resend_api_key
    html = (
        f"<h2>Welcome to Al Mobarmg Store, {name}!</h2>"
        "<p>Your account is verified and ready to publish and install apps safely.</p>"
    )
    await asyncio.to_thread(
        resend.Emails.send,
        {
            "from": settings.email_from,
            "to": email,
            "subject": "Welcome to Al Mobarmg Store",
            "html": html,
        },
    )


def decode_refresh_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.jwt_refresh_secret, algorithms=["HS256"])
    except JWTError as exc:
        raise ValueError("Invalid refresh token") from exc
    if payload.get("type") != "refresh":
        raise ValueError("Invalid token type")
    return payload
