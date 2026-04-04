from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="DEKABRISTI_",
        env_file=".env",
        extra="ignore",
    )

    app_name: str = "Dekabristi API"
    api_v1_prefix: str = "/api/v1"
    secret_key: str = "change-me-before-production-please-use-a-32-byte-secret"
    access_token_expiration_minutes: int = 60 * 24 * 7
    database_url: str | None = None
    storage_dir: str | None = None
    max_upload_size_bytes: int = 250 * 1024 * 1024
    sync_poll_interval_seconds: int = 600
    connectivity_probe_interval_seconds: int = 1800
    cors_origins: list[str] = []

    @property
    def backend_dir(self) -> Path:
        return Path(__file__).resolve().parents[2]

    @property
    def resolved_database_url(self) -> str:
        if self.database_url:
            return self.database_url

        local_db = self.backend_dir / "dekabristi.db"
        return f"sqlite:///{local_db.as_posix()}"

    @property
    def resolved_storage_dir(self) -> Path:
        if self.storage_dir:
            return Path(self.storage_dir).expanduser().resolve()

        return (self.backend_dir / "storage").resolve()

    @property
    def is_sqlite(self) -> bool:
        return self.resolved_database_url.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()
