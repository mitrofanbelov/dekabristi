#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"

echo "==> Checking prerequisites"
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required on the Mac mini."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode and the command line tools are required."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installing XcodeGen via Homebrew"
    brew install xcodegen
  else
    echo "Homebrew is not installed, so XcodeGen could not be installed automatically."
    echo "Install it from https://github.com/yonaskolb/XcodeGen and rerun this script."
    exit 1
  fi
fi

echo "==> Preparing Python environment"
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -e "$ROOT_DIR/backend[dev]"

echo "==> Generating Xcode project"
"$ROOT_DIR/scripts/generate-apple-project.sh"

echo "==> Done"
echo "Next steps:"
echo "1. Start the backend with ./scripts/run-backend.sh"
echo "2. Open apple/Dekabristi.xcodeproj in Xcode"
echo "3. Run the DekabristiMac scheme"
