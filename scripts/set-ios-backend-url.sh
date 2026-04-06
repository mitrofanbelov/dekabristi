#!/bin/bash
set -euo pipefail

DEFAULT_URL="http://192.168.0.220:8000/api/v1"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
URL="${1:-$DEFAULT_URL}"

set_plist_key() {
  local plist_path="$1"
  local key="$2"
  local value="$3"

  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_path"
  else
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_path"
  fi
}

set_plist_key "$ROOT_DIR/apple/App/Config/iOS-Info.plist" "DEKABRISTI_API_BASE_URL" "$URL"
set_plist_key "$ROOT_DIR/apple/Extensions/Config/iOS-ShareExtension-Info.plist" "DEKABRISTI_API_BASE_URL" "$URL"

echo "Updated iPhone build backend URL to: $URL"
