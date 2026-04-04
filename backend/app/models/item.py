from __future__ import annotations

import enum

from sqlalchemy import Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class ItemKind(str, enum.Enum):
    LINK = "link"
    FILE = "file"


class ItemStatus(str, enum.Enum):
    QUEUED = "queued"
    UPLOADING = "uploading"
    AVAILABLE = "available"
    FAILED = "failed"


class Item(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "items"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[ItemKind] = mapped_column(
        Enum(ItemKind, native_enum=False),
        nullable=False,
        index=True,
    )
    status: Mapped[ItemStatus] = mapped_column(
        Enum(ItemStatus, native_enum=False),
        nullable=False,
        default=ItemStatus.AVAILABLE,
    )
    title: Mapped[str | None] = mapped_column(String(512), nullable=True)
    source_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    user = relationship("User", back_populates="items")
    attachments = relationship(
        "Attachment",
        back_populates="item",
        cascade="all, delete-orphan",
        order_by="Attachment.created_at.desc()",
    )
