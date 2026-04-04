from __future__ import annotations

from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import Select, select
from sqlalchemy.orm import Session, selectinload

from app.api.dependencies import get_current_user
from app.db import get_db
from app.models import Attachment, Item, ItemKind, ItemStatus, User
from app.schemas.items import CreateLinkRequest, ItemListResponse, ItemResponse, SyncResponse
from app.services.file_storage import save_upload

router = APIRouter(prefix="/items", tags=["items"])


def _item_query_for_user(user_id: str) -> Select[tuple[Item]]:
    return (
        select(Item)
        .where(Item.user_id == user_id)
        .options(selectinload(Item.attachments))
    )


def _serialize_items(items: list[Item]) -> list[ItemResponse]:
    return [ItemResponse.model_validate(item) for item in items]


@router.post("/links", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
def create_link(
    payload: CreateLinkRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ItemResponse:
    title = payload.title or urlparse(str(payload.url)).netloc or str(payload.url)
    item = Item(
        user_id=current_user.id,
        kind=ItemKind.LINK,
        status=ItemStatus.AVAILABLE,
        title=title,
        source_url=str(payload.url),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return ItemResponse.model_validate(item)


@router.post("/files", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
def create_file_item(
    file: UploadFile = File(...),
    title: str | None = Form(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ItemResponse:
    item = Item(
        user_id=current_user.id,
        kind=ItemKind.FILE,
        status=ItemStatus.UPLOADING,
        title=title or file.filename or "Untitled file",
    )
    db.add(item)
    db.flush()

    stored_file = save_upload(current_user.id, item.id, file)

    attachment = Attachment(
        item_id=item.id,
        original_filename=stored_file.original_filename,
        stored_filename=stored_file.stored_filename,
        relative_path=stored_file.relative_path,
        content_type=stored_file.content_type,
        size_bytes=stored_file.size_bytes,
        sha256=stored_file.sha256,
    )
    db.add(attachment)

    item.status = ItemStatus.AVAILABLE
    db.commit()

    refreshed_item = db.scalar(
        _item_query_for_user(current_user.id).where(Item.id == item.id)
    )
    assert refreshed_item is not None
    return ItemResponse.model_validate(refreshed_item)


@router.get("", response_model=ItemListResponse)
def list_items(
    cursor: datetime | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ItemListResponse:
    query = _item_query_for_user(current_user.id).order_by(Item.updated_at.desc()).limit(limit)
    if cursor is not None:
        query = query.where(Item.updated_at < cursor)

    items = list(db.scalars(query).unique())
    next_cursor = items[-1].updated_at if items else None
    return ItemListResponse(items=_serialize_items(items), next_cursor=next_cursor)


@router.get("/sync", response_model=SyncResponse)
def sync_items(
    cursor: datetime | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SyncResponse:
    query = _item_query_for_user(current_user.id).order_by(Item.updated_at.asc()).limit(limit)
    if cursor is not None:
        query = query.where(Item.updated_at > cursor)

    items = list(db.scalars(query).unique())
    next_cursor = items[-1].updated_at if items else cursor
    return SyncResponse(
        items=_serialize_items(items),
        next_cursor=next_cursor,
        has_more=len(items) == limit,
    )


@router.get("/attachments/{attachment_id}/download")
def download_attachment(
    attachment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FileResponse:
    attachment = db.scalar(
        select(Attachment)
        .join(Attachment.item)
        .where(Attachment.id == attachment_id, Item.user_id == current_user.id)
    )
    if attachment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment not found.")

    from app.core.config import get_settings

    storage_path = get_settings().resolved_storage_dir / Path(attachment.relative_path)
    if not storage_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File is missing on disk.")

    return FileResponse(
        path=storage_path,
        media_type=attachment.content_type or "application/octet-stream",
        filename=attachment.original_filename,
    )
