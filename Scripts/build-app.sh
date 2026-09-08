#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"

swift build -c release --product CurrantMarkApp
swift build -c release --product currantmark

APP_DIR="$ROOT_DIR/build/CurrantMark.app"
rm -rf "$APP_DIR"
mkdir -p \
    "$APP_DIR/Contents/Helpers" \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/.build/release/CurrantMarkApp" "$APP_DIR/Contents/MacOS/CurrantMark"
cp "$ROOT_DIR/.build/release/currantmark" "$APP_DIR/Contents/Helpers/currantmark"
cp "$ROOT_DIR/Sources/CurrantMark/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Sources/CurrantMarkCore/Resources/Style.css" "$APP_DIR/Contents/Resources/Style.css"

echo "Built $APP_DIR"
