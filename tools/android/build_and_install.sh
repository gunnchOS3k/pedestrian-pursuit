#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK_PATH="$PROJECT_ROOT/build/android/pedestrian-pursuit-debug.apk"
REVIEW_APK_PATH="$PROJECT_ROOT/build/android/pedestrian-pursuit-aa-guest-runners-owner-review.apk"
PACKAGE_ID="com.gunnchos.pedestrianpursuit"

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

python3 "$PROJECT_ROOT/tools/build_identity/generate_build_identity.py" --repo-root "$PROJECT_ROOT" --flavor guest-runner-review-debug
STAMPED_SHA="$(python3 - "$PROJECT_ROOT" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]) / "data/build_identity.json"
data = json.loads(p.read_text())
sha = str(data.get("git_sha") or "")
if not sha or sha.upper() == "UNKNOWN":
    raise SystemExit("Review APK refused: embedded SHA is UNKNOWN")
print(sha)
PY
)"
mkdir -p "$(dirname "$APK_PATH")" build/logs
"$GODOT" --headless --path "$PROJECT_ROOT" --export-debug "Android" "$APK_PATH" --verbose 2>&1 | tee build/logs/android-export.log
test -f "$APK_PATH" || { echo "APK not produced: $APK_PATH" >&2; exit 1; }
if ! grep -a -F "$STAMPED_SHA" "$APK_PATH" >/dev/null; then
  echo "Review APK refused: packed APK does not embed $STAMPED_SHA" >&2
  exit 1
fi
cp "$APK_PATH" "$REVIEW_APK_PATH"
shasum -a 256 "$REVIEW_APK_PATH" | tee "$REVIEW_APK_PATH.sha256"
if [[ "${SKIP_INSTALL:-0}" == "1" ]]; then
  echo "SKIP_INSTALL=1; exported $REVIEW_APK_PATH"
  exit 0
fi
"${ADB[@]}" install -r "$REVIEW_APK_PATH"
"${ADB[@]}" shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 >/dev/null

echo "Installed and launched $PACKAGE_ID on the connected device."
