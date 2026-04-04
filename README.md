# dekabristi

MVP for a cross-device "save anything" application.

Current repository layout:

- `backend/` - FastAPI API for auth, items, uploads, and sync
- `apple/` - Swift shared client core for iOS/macOS offline-first flows
- `infra/` - local and future Mac mini deployment assets
- `docs/` - architecture notes and implementation decisions

## Product slice in this commit

- email/password authentication
- save links
- upload arbitrary files
- list saved items
- incremental sync endpoint
- delete items and edit comments
- basic offline-first client core for Apple platforms
- iOS and macOS share extension support for quick link saving from the system share sheet

## Local backend run

1. Create a virtual environment.
2. Install the backend package with dev extras:
   `pip install -e .[dev]`
3. Run the API:
   `uvicorn app.main:app --reload --app-dir backend`

## Docker

`infra/docker-compose.yml` contains the first local deployment template that can be adapted for the always-on Mac mini later.

## Apple device runbooks

- [Run on Mac mini](docs/mac-mini-run.md)
- [Run on iPhone](docs/iphone-run.md)
