from __future__ import annotations

from io import BytesIO

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client(tmp_path, monkeypatch) -> TestClient:
    monkeypatch.setenv("DEKABRISTI_DATABASE_URL", f"sqlite:///{(tmp_path / 'test.db').as_posix()}")
    monkeypatch.setenv("DEKABRISTI_STORAGE_DIR", str(tmp_path / "storage"))
    monkeypatch.setenv(
        "DEKABRISTI_SECRET_KEY",
        "test-secret-key-that-is-long-enough-for-sha256",
    )

    from app.core.config import get_settings
    from app.db import get_engine, get_session_factory
    from app.main import create_app

    get_settings.cache_clear()
    get_engine.cache_clear()
    get_session_factory.cache_clear()

    app = create_app()

    with TestClient(app) as test_client:
        yield test_client

    get_settings.cache_clear()
    get_engine.cache_clear()
    get_session_factory.cache_clear()


def auth_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "demo@example.com", "password": "verysecure123"},
    )
    assert response.status_code == 201
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_healthcheck(client: TestClient) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_register_login_and_profile(client: TestClient) -> None:
    register = client.post(
        "/api/v1/auth/register",
        json={"email": "demo@example.com", "password": "verysecure123"},
    )
    assert register.status_code == 201

    login = client.post(
        "/api/v1/auth/login",
        json={"email": "demo@example.com", "password": "verysecure123"},
    )
    assert login.status_code == 200

    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "demo@example.com"


def test_create_link_file_and_sync(client: TestClient) -> None:
    headers = auth_headers(client)

    link = client.post(
        "/api/v1/items/links",
        json={"url": "https://example.com/page", "title": "Example"},
        headers=headers,
    )
    assert link.status_code == 201
    assert link.json()["kind"] == "link"

    file_response = client.post(
        "/api/v1/items/files",
        files={"file": ("hello.txt", BytesIO(b"hello world"), "text/plain")},
        headers=headers,
    )
    assert file_response.status_code == 201
    assert file_response.json()["attachments"][0]["original_filename"] == "hello.txt"

    feed = client.get("/api/v1/items", headers=headers)
    assert feed.status_code == 200
    assert len(feed.json()["items"]) == 2

    sync = client.get("/api/v1/items/sync", headers=headers)
    assert sync.status_code == 200
    assert len(sync.json()["items"]) == 2
    assert sync.json()["has_more"] is False


def test_update_comment_delete_item_and_download_attachment(client: TestClient) -> None:
    headers = auth_headers(client)

    file_response = client.post(
        "/api/v1/items/files",
        files={"file": ("hello.txt", BytesIO(b"hello world"), "text/plain")},
        headers=headers,
    )
    assert file_response.status_code == 201
    item_payload = file_response.json()
    item_id = item_payload["id"]
    attachment_id = item_payload["attachments"][0]["id"]

    comment_update = client.patch(
        f"/api/v1/items/{item_id}",
        json={"comment": "Need this on every device"},
        headers=headers,
    )
    assert comment_update.status_code == 200
    assert comment_update.json()["comment"] == "Need this on every device"

    download = client.get(f"/api/v1/items/attachments/{attachment_id}/download", headers=headers)
    assert download.status_code == 200
    assert download.content == b"hello world"

    delete_response = client.delete(f"/api/v1/items/{item_id}", headers=headers)
    assert delete_response.status_code == 200
    assert delete_response.json()["deleted_at"] is not None

    feed = client.get("/api/v1/items", headers=headers)
    assert feed.status_code == 200
    assert feed.json()["items"] == []

    sync = client.get("/api/v1/items/sync", headers=headers)
    assert sync.status_code == 200
    assert len(sync.json()["items"]) == 1
    assert sync.json()["items"][0]["deleted_at"] is not None

    missing_download = client.get(
        f"/api/v1/items/attachments/{attachment_id}/download",
        headers=headers,
    )
    assert missing_download.status_code == 404
