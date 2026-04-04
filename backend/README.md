# Backend

FastAPI service for the first Dekabristi MVP.

## Features in the first slice

- email/password registration and login
- authenticated item feed
- link saving
- direct file upload to local storage
- attachment download
- incremental sync cursor based on `updated_at`

## Environment variables

- `DEKABRISTI_SECRET_KEY`
- `DEKABRISTI_DATABASE_URL`
- `DEKABRISTI_STORAGE_DIR`
- `DEKABRISTI_ACCESS_TOKEN_EXPIRATION_MINUTES`
- `DEKABRISTI_MAX_UPLOAD_SIZE_BYTES`

## Run

`uvicorn app.main:app --reload --app-dir backend`
