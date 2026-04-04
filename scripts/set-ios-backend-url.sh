#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 http://<host>:8000/api/v1"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
URL="$1"

/usr/libexec/PlistBuddy -c "Set :DEKABRISTI_API_BASE_URL $URL" "$ROOT_DIR/apple/App/Config/iOS-Info.plist"
/usr/libexec/PlistBuddy -c "Set :DEKABRISTI_API_BASE_URL $URL" "$ROOT_DIR/apple/Extensions/Config/iOS-ShareExtension-Info.plist"

echo "Updated iPhone build backend URL to: $URL"
