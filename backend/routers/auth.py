from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.database import get_db
from backend.models.enums import UserRole
from backend.models.user import User
from backend.services.auth_service import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    delete_refresh_token,
    generate_reset_token,
    hash_password,
    send_password_reset_email,
    send_welcome_email,
    store_refresh_token,
    verify_password,
    verify_refresh_token,
    verify_reset_token,
)
from backend.services.auth_service import redis_client

router = APIRouter(prefix="/api/auth", tags=["auth"])
logger = logging.getLogger(__name__)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=1)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=1)


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    token: str
    new_password: str = Field(min_length=8)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    name: str
    role: UserRole
    subscription_plan: str


class RegisterResponse(BaseModel):
    message: str
    user_id: str


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserResponse


class RefreshResponse(BaseModel):
    access_token: str
    token_type: str


class MessageResponse(BaseModel):
    message: str


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)) -> RegisterResponse:
    email = payload.email.lower()
    existing = await db.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    new_user = User(
        email=email,
        name=payload.name.strip(),
        password_hash=hash_password(payload.password),
        role=UserRole.developer,
        is_email_verified=True,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    return RegisterResponse(message="Account created successfully", user_id=str(new_user.id))


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> LoginResponse:
    email = payload.email.lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    if not user.is_email_verified:
        user.is_email_verified = True
        await db.commit()

    access_token = create_access_token(str(user.id), user.role.value)
    refresh_token = create_refresh_token(str(user.id), user.role.value)
    await store_refresh_token(str(user.id), refresh_token)

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=UserResponse(
            id=str(user.id),
            email=user.email,
            name=user.name,
            role=user.role,
            subscription_plan=user.subscription_plan.value,
        ),
    )


@router.post("/refresh", response_model=RefreshResponse)
async def refresh_tokens(payload: RefreshRequest) -> RefreshResponse:
    try:
        token_payload = decode_refresh_token(payload.refresh_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    user_id = token_payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    if not await verify_refresh_token(user_id, payload.refresh_token):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired or revoked")

    role = token_payload.get("role")
    if role is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    access_token = create_access_token(user_id, role)
    return RefreshResponse(access_token=access_token, token_type="bearer")


@router.post("/logout", response_model=MessageResponse)
async def logout(payload: LogoutRequest) -> MessageResponse:
    try:
        token_payload = decode_refresh_token(payload.refresh_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    user_id = token_payload.get("sub")
    if user_id:
        await delete_refresh_token(user_id)
    return MessageResponse(message="Logged out")


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(payload: VerifyEmailRequest, db: AsyncSession = Depends(get_db)) -> MessageResponse:
    email = payload.email.lower()
    user_result = await db.execute(select(User).where(User.email == email))
    user = user_result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if not user.is_email_verified:
        user.is_email_verified = True
        await db.commit()

    await redis_client.delete(f"otp:{email}")

    try:
        await send_welcome_email(user.email, user.name)
    except Exception:
        logger.exception("Failed to send welcome email", extra={"email": email})

    return MessageResponse(message="Email verification is disabled in this environment. Account is already active.")


@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(
    payload: ResendVerificationRequest,
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    email = payload.email.lower()
    user_result = await db.execute(select(User).where(User.email == email))
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if not user.is_email_verified:
        user.is_email_verified = True
        await db.commit()

    await redis_client.delete(f"otp:{email}")
    return MessageResponse(message="Email verification is disabled in this environment. Account is already active.")


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    email = payload.email.lower()
    user_result = await db.execute(select(User).where(User.email == email))
    user = user_result.scalar_one_or_none()

    if user:
        token = await generate_reset_token(email)
        try:
            await send_password_reset_email(email=email, token=token)
        except Exception:
            logger.exception("Failed to send password reset email", extra={"email": email})

    return MessageResponse(message="Reset email sent")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)) -> MessageResponse:
    email = payload.email.lower()
    if not await verify_reset_token(email, payload.token):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.password_hash = hash_password(payload.new_password)
    await db.commit()
    await redis_client.delete(f"reset:{email}")

    return MessageResponse(message="Password reset successful")
