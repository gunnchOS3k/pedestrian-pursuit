#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK_PATH="$PROJECT_ROOT/build/android/pedestrian-pursuit-debug.apk"
PACKAGE_ID="com.gunnchos3k.pedestrianpursuit"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="$(command -v godot4)"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4 was not found. Set GODOT_BIN to the editor executable." >&2
  exit 2
fi

if command -v adb >/dev/null 2>&1; then
  ADB_BIN="$(command -v adb)"
elif [[ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
else
  echo "adb was not found. Install Android SDK Platform-Tools and add it to PATH." >&2
  exit 2
fi

ADB=("$ADB_BIN")
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  ADB+=( -s "$ANDROID_SERIAL" )
fi

DEVICE_STATE="$("${ADB[@]}" get-state 2>/dev/null || true)"
if [[ "$DEVICE_STATE" != "device" ]]; then
  echo "No authorized Android device was found. Unlock it and enable USB debugging." >&2
  "$ADB_BIN" devices -l >&2
  exit 3
fi

mkdir -p "$(dirname "$APK_PATH")"
"$GODOT" --headless --path "$PROJECT_ROOT" --export-debug "Android Device" "$APK_PATH"
"${ADB[@]}" install -r "$APK_PATH"
"${ADB[@]}" shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 >/dev/null

echo "Installed and launched $PACKAGE_ID on the connected device."
