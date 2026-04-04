from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from app.core.config import get_settings

CHUNK_SIZE = 1024 * 1024


@dataclass(slots=True)
class StoredFile:
    original_filename: str
    stored_filename: str
    relative_path: str
    content_type: str | None
    size_bytes: int
    sha256: str


def save_upload(user_id: str, item_id: str, upload_file: UploadFile) -> StoredFile:
    settings = get_settings()
    suffix = Path(upload_file.filename or "").suffix[:16]
    stored_filename = f"{uuid4().hex}{suffix}"
    relative_path = Path(user_id) / item_id / stored_filename
    destination = settings.resolved_storage_dir / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)

    digest = hashlib.sha256()
    size_bytes = 0

    try:
        with destination.open("wb") as output:
            while True:
                chunk = upload_file.file.read(CHUNK_SIZE)
                if not chunk:
                    break

                size_bytes += len(chunk)
                if size_bytes > settings.max_upload_size_bytes:
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail=f"File exceeds {settings.max_upload_size_bytes} bytes.",
                    )

                digest.update(chunk)
                output.write(chunk)
    except Exception:
        if destination.exists():
            destination.unlink(missing_ok=True)
        raise
    finally:
        upload_file.file.close()

    return StoredFile(
        original_filename=upload_file.filename or "upload.bin",
        stored_filename=stored_filename,
        relative_path=relative_path.as_posix(),
        content_type=upload_file.content_type,
        size_bytes=size_bytes,
        sha256=digest.hexdigest(),
    )


def delete_stored_file(relative_path: str) -> None:
    settings = get_settings()
    destination = settings.resolved_storage_dir / Path(relative_path)
    destination.unlink(missing_ok=True)

    parent = destination.parent
    while parent != settings.resolved_storage_dir:
        try:
            parent.rmdir()
        except OSError:
            break
        parent = parent.parent
