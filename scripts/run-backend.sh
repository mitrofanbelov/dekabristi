#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install -e "$ROOT_DIR/backend[dev]"

export DEKABRISTI_SECRET_KEY="${DEKABRISTI_SECRET_KEY:-local-development-secret-that-is-at-least-32-bytes}"

"$VENV_DIR/bin/uvicorn" app.main:app --host 0.0.0.0 --port 8000 --app-dir "$ROOT_DIR/backend"
