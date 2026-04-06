#!/bin/bash
set -euo pipefail

DEFAULT_URL="http://192.168.0.220:8000/api/v1"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
URL="${1:-$DEFAULT_URL}"

/usr/libexec/PlistBuddy -c "Set :DEKABRISTI_API_BASE_URL $URL" "$ROOT_DIR/apple/App/Config/iOS-Info.plist"
/usr/libexec/PlistBuddy -c "Set :DEKABRISTI_API_BASE_URL $URL" "$ROOT_DIR/apple/Extensions/Config/iOS-ShareExtension-Info.plist"

echo "Updated iPhone build backend URL to: $URL"
