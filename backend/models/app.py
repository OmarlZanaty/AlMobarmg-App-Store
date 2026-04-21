import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.database import Base
from backend.models.enums import AppStatus


class App(Base):
    __tablename__ = "apps"
    __table_args__ = (
        CheckConstraint("security_score IS NULL OR (security_score >= 0 AND security_score <= 100)", name="ck_apps_security_score_range"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    developer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    package_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    short_description: Mapped[str] = mapped_column(String(200), nullable=False)
    icon_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    screenshots: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    version: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[AppStatus] = mapped_column(
        Enum(AppStatus, name="app_status", native_enum=True),
        nullable=False,
        default=AppStatus.pending,
    )
    security_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    supported_platforms: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)

    android_file_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    ios_pwa_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    windows_file_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    mac_file_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    linux_deb_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    linux_appimage_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    linux_rpm_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    file_sizes: Mapped[dict[str, float]] = mapped_column(JSONB, nullable=False, default=dict)
    total_installs: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    developer = relationship("User", back_populates="apps")
    security_reports = relationship("SecurityReport", back_populates="app", cascade="all, delete-orphan")
    installs = relationship("Install", back_populates="app", cascade="all, delete-orphan")
    fix_rejection_reports = relationship("FixRejectionReport", back_populates="app")
