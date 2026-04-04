from __future__ import annotations

from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings
from app.models import Base


@lru_cache
def get_engine():
    settings = get_settings()
    return create_engine(
        settings.resolved_database_url,
        connect_args={"check_same_thread": False} if settings.is_sqlite else {},
    )


@lru_cache
def get_session_factory():
    return sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=get_engine(),
        expire_on_commit=False,
    )


def init_db() -> None:
    settings = get_settings()
    settings.resolved_storage_dir.mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=get_engine())


def get_db() -> Generator[Session, None, None]:
    session_factory = get_session_factory()
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
