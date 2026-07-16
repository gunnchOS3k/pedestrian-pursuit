#!/usr/bin/env bash
# Signed Pedestrian Pursuit release APK export with Godot .import resource workaround.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/android/pedestrian-pursuit-release.apk}"
PREPARE="$ROOT/tools/android/prepare_release_signing.sh"

fail() { echo "[export-release-apk] $*" >&2; exit 1; }

[[ -n "${GODOT_BIN:-}" ]] || fail "GODOT_BIN unset"
[[ -x "$GODOT_BIN" ]] || fail "GODOT_BIN not executable: $GODOT_BIN"
[[ -n "${JAVA_HOME:-}" ]] || fail "JAVA_HOME unset (need JDK 17)"
[[ -n "${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}" ]] || fail "ANDROID_SDK_ROOT / ANDROID_HOME unset"
[[ -n "${GUNNCHOS_KEYSTORE_DIR:-}" ]] || fail "GUNNCHOS_KEYSTORE_DIR unset — source passwords.env"
[[ -n "${PEDESTRIAN_STORE_PASSWORD:-${PEDESTRIAN_KEYSTORE_PASS:-}}" ]] || fail "PEDESTRIAN_STORE_PASSWORD unset — source passwords.env"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$(dirname "$OUT")"
# Keep previous APK for rollback comparison.
if [[ -f "$OUT" ]]; then
  cp -f "$OUT" "${OUT%.apk}-prev.apk" || true
fi
rm -f "$OUT"

ANDROID_BUILD="$ROOT/android/build"
cleanup_imports() {
  find "$ANDROID_BUILD/res" -name '*.import' -delete 2>/dev/null || true
}

restore() {
  bash "$PREPARE" restore >/dev/null 2>&1 || true
  kill "${WATCH_PID:-}" 2>/dev/null || true
}
trap restore EXIT

bash "$PREPARE" apply

(
  for _ in $(seq 1 240); do
    cleanup_imports
    sleep 0.5
  done
) &
WATCH_PID=$!

set +e
"$GODOT_BIN" --headless --path "$ROOT" --export-release Android "$OUT"
GODOT_RC=$?
set -e

kill "$WATCH_PID" 2>/dev/null || true
WATCH_PID=""
cleanup_imports

if [[ ! -f "$OUT" ]]; then
  echo "[export-release-apk] Godot exit=$GODOT_RC — trying gradle assembleStandardRelease after import cleanup"
  (
    cd "$ANDROID_BUILD"
    cleanup_imports
    ./gradlew assembleStandardRelease --no-daemon
  )
  APK_CAND="$(find "$ANDROID_BUILD" -path '*/apk/*/release/*.apk' | head -1 || true)"
  [[ -n "$APK_CAND" ]] || fail "APK not produced (Godot rc=$GODOT_RC)"
  cp -f "$APK_CAND" "$OUT"
fi

bash "$PREPARE" restore
trap - EXIT

SHA="$(shasum -a 256 "$OUT" | awk '{print $1}')"
echo "$SHA  $(basename "$OUT")" > "${OUT}.sha256"
echo "[export-release-apk] OK: $OUT"
echo "[export-release-apk] SHA-256: $SHA"
