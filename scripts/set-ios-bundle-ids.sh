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

ruby - "$PROJECT_FILE" "$APP_BUNDLE_ID" "$EXTENSION_BUNDLE_ID" <<'RUBY'
project_file, app_bundle_id, extension_bundle_id = ARGV
lines = File.readlines(project_file)
current_target = nil

lines.map! do |line|
  stripped = line.strip
  current_target =
    case line
    when /^  DekabristiIOS:\s*$/
      "app"
    when /^  DekabristiIOSShareExtension:\s*$/
      "extension"
    when /^  [A-Za-z0-9]+:\s*$/
      nil
    else
      current_target
    end

  if stripped.start_with?("PRODUCT_BUNDLE_IDENTIFIER:")
    replacement =
      case current_target
      when "app"
        app_bundle_id
      when "extension"
        extension_bundle_id
      end

    if replacement
      indent = line[/^\s*/]
      line = "#{indent}PRODUCT_BUNDLE_IDENTIFIER: #{replacement}\n"
    end
  end

  line
end

File.write(project_file, lines.join)
RUBY

echo "Updated iOS bundle identifiers in apple/project.yml"
echo "  App:       $APP_BUNDLE_ID"
echo "  Extension: $EXTENSION_BUNDLE_ID"
