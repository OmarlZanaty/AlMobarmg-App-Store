import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.database import Base
from backend.models.enums import FixRejectionStatus


class FixRejectionReport(Base):
    __tablename__ = "fix_rejection_reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    developer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    app_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("apps.id", ondelete="SET NULL"),
        nullable=True,
    )
    rejection_reason: Mapped[str] = mapped_column(Text, nullable=False)
    mobsf_findings: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    ai_diagnosis: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    stripe_payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[FixRejectionStatus] = mapped_column(
        Enum(FixRejectionStatus, name="fix_rejection_status", native_enum=True),
        nullable=False,
        default=FixRejectionStatus.pending_payment,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    developer = relationship("User", back_populates="fix_rejection_reports")
    app = relationship("App", back_populates="fix_rejection_reports")
