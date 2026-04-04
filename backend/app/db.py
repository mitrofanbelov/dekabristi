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
    engine = get_engine()
    Base.metadata.create_all(bind=engine)

    if settings.is_sqlite:
        _apply_sqlite_schema_fixes(engine)


def get_db() -> Generator[Session, None, None]:
    session_factory = get_session_factory()
    db = session_factory()
    try:
        yield db
    finally:
        db.close()


def _apply_sqlite_schema_fixes(engine) -> None:
    with engine.begin() as connection:
        column_names = {
            row[1]
            for row in connection.exec_driver_sql("PRAGMA table_info(items)").fetchall()
        }

        if "comment" not in column_names:
            connection.exec_driver_sql("ALTER TABLE items ADD COLUMN comment TEXT")

        if "deleted_at" not in column_names:
            connection.exec_driver_sql("ALTER TABLE items ADD COLUMN deleted_at DATETIME")
