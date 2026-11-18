#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Pass --universal for a release that runs on Apple Silicon and Intel Macs.
arguments=(-c release)
if [[ "${1:-}" == "--universal" ]]; then
    arguments+=(--arch arm64 --arch x86_64)
fi
swift build "${arguments[@]}"
binary_dir=$(swift build "${arguments[@]}" --show-bin-path)
app="dist/Lunch Bell.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/LunchBell" "$app/Contents/MacOS/LunchBell"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/Icon.swift "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/Lunch-Bell-macOS.zip"
echo "Built $app and dist/Lunch-Bell-macOS.zip"
