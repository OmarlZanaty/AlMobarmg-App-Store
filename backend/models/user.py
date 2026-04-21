import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.database import Base
from backend.models.enums import SubscriptionPlan, UserRole


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role", native_enum=True),
        nullable=False,
        default=UserRole.user,
    )
    is_email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_identity_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    reputation_score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    subscription_plan: Mapped[SubscriptionPlan] = mapped_column(
        Enum(SubscriptionPlan, name="subscription_plan", native_enum=True),
        nullable=False,
        default=SubscriptionPlan.free,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    apps = relationship("App", back_populates="developer", cascade="all, delete-orphan")
    subscriptions = relationship("Subscription", back_populates="developer", cascade="all, delete-orphan")
    installs = relationship("Install", back_populates="user")
    fix_rejection_reports = relationship("FixRejectionReport", back_populates="developer")
