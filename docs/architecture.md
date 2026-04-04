# Architecture Notes

## MVP scope

- Apple-first client: iOS and macOS
- Backend API hosted on the always-on Mac mini later
- Authentication: email/password
- Content types: links and arbitrary files
- Share flows: dedicated iOS and macOS extensions in the Apple project phase

## Sync model

- The server is the source of truth.
- Clients keep a local cache and an outbox queue.
- `GET /api/v1/items` returns the latest feed ordered by newest updates.
- `GET /api/v1/items/sync?cursor=...` returns changes newer than the cursor.
- Clients trigger sync:
  - on launch
  - on manual refresh
  - every 10 minutes while active
  - best effort in the background based on platform capabilities

## Connectivity model

- Clients distinguish between:
  - no network path
  - network path exists but backend is unavailable
- Connectivity checks happen:
  - when the app launches
  - before sync attempts
  - before uploads
  - every 30 minutes as a health probe while the app remains active

## Storage model

- Files are stored on disk for the MVP.
- Metadata is stored in PostgreSQL in production and SQLite by default in local development.
- The storage layer is intentionally simple so it can be swapped for S3-compatible storage later.
