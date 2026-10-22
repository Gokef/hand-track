#!/bin/zsh
# Builds Hand Track.app in this folder.
set -euo pipefail
cd "${0:A:h}"

swift build -c release

app="Hand Track.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/HandTrack "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
codesign --force --sign - "$app"

echo "Built $app. Start it with: open \"$app\""
