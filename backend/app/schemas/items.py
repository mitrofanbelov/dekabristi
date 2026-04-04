from __future__ import annotations

from datetime import datetime

from pydantic import AnyHttpUrl, BaseModel, ConfigDict, Field

from app.models.item import ItemKind, ItemStatus


class CreateLinkRequest(BaseModel):
    url: AnyHttpUrl
    title: str | None = Field(default=None, max_length=512)


class AttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    original_filename: str
    content_type: str | None
    size_bytes: int
    sha256: str
    created_at: datetime


class ItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    kind: ItemKind
    status: ItemStatus
    title: str | None
    source_url: str | None
    comment: str | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    attachments: list[AttachmentResponse] = []


class ItemListResponse(BaseModel):
    items: list[ItemResponse]
    next_cursor: datetime | None


class SyncResponse(BaseModel):
    items: list[ItemResponse]
    next_cursor: datetime | None
    has_more: bool


class UpdateItemRequest(BaseModel):
    comment: str | None = Field(default=None, max_length=4_000)
