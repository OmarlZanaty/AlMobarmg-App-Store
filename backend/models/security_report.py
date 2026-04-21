import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.database import Base
from backend.models.enums import RiskLevel


class SecurityReport(Base):
    __tablename__ = "security_reports"
    __table_args__ = (CheckConstraint("score >= 0 AND score <= 100", name="ck_security_reports_score_range"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    app_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("apps.id", ondelete="CASCADE"),
        nullable=False,
    )
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    risk_level: Mapped[RiskLevel] = mapped_column(
        Enum(RiskLevel, name="risk_level", native_enum=True),
        nullable=False,
    )
    mobsf_raw: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    virustotal_raw: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    ai_summary: Mapped[str] = mapped_column(Text, nullable=False)
    ai_developer_report: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    ai_user_report: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    dangerous_permissions: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    suspicious_apis: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    scanned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    app = relationship("App", back_populates="security_reports")
