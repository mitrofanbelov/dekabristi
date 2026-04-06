#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

APPLE_DIR="$ROOT_DIR/apple"
BACKUP_DIR="$(mktemp -d)"

FILES_TO_PRESERVE=(
  "$APPLE_DIR/App/Config/iOS-Info.plist"
  "$APPLE_DIR/App/Config/macOS-Info.plist"
  "$APPLE_DIR/App/Config/iOS-App.entitlements"
  "$APPLE_DIR/App/Config/macOS-App.entitlements"
  "$APPLE_DIR/Extensions/Config/iOS-ShareExtension-Info.plist"
  "$APPLE_DIR/Extensions/Config/macOS-ShareExtension-Info.plist"
  "$APPLE_DIR/Extensions/Config/iOS-ShareExtension.entitlements"
  "$APPLE_DIR/Extensions/Config/macOS-ShareExtension.entitlements"
  "$APPLE_DIR/Dekabristi.xcodeproj/xcshareddata/xcschemes/DekabristiIOS.xcscheme"
  "$APPLE_DIR/Dekabristi.xcodeproj/xcshareddata/xcschemes/DekabristiMac.xcscheme"
)

cleanup() {
  rm -rf "$BACKUP_DIR"
}

trap cleanup EXIT

for file in "${FILES_TO_PRESERVE[@]}"; do
  if [[ -f "$file" ]]; then
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
  fi
done

cd "$APPLE_DIR"
xcodegen generate

for file in "${FILES_TO_PRESERVE[@]}"; do
  backup_file="$BACKUP_DIR/$(basename "$file")"
  if [[ -f "$backup_file" ]]; then
    mkdir -p "$(dirname "$file")"
    cp "$backup_file" "$file"
  fi
done
