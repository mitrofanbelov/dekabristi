from __future__ import annotations

from fastapi import APIRouter

from app.core.config import get_settings

router = APIRouter(tags=["health"])


@router.get("/health")
def healthcheck() -> dict[str, object]:
    settings = get_settings()
    return {
        "status": "ok",
        "app": settings.app_name,
        "sync_poll_interval_seconds": settings.sync_poll_interval_seconds,
        "connectivity_probe_interval_seconds": settings.connectivity_probe_interval_seconds,
    }
