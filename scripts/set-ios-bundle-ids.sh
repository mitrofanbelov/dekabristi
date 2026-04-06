#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/apple/project.yml"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <ios-app-bundle-id> [ios-share-extension-bundle-id]"
  echo "Example: $0 com.example.dekabristi.ios com.example.dekabristi.ios.share"
  exit 1
fi

APP_BUNDLE_ID="$1"
EXTENSION_BUNDLE_ID="${2:-$APP_BUNDLE_ID.share}"

perl -0pi -e 's/(DekabristiIOS:\n(?:.*\n)*?PRODUCT_BUNDLE_IDENTIFIER:\s*)\S+/$1'"$APP_BUNDLE_ID"'/s' "$PROJECT_FILE"
perl -0pi -e 's/(DekabristiIOSShareExtension:\n(?:.*\n)*?PRODUCT_BUNDLE_IDENTIFIER:\s*)\S+/$1'"$EXTENSION_BUNDLE_ID"'/s' "$PROJECT_FILE"

echo "Updated iOS bundle identifiers in apple/project.yml"
echo "  App:       $APP_BUNDLE_ID"
echo "  Extension: $EXTENSION_BUNDLE_ID"
