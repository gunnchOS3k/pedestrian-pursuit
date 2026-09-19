#!/usr/bin/env bash
# VXP-3.1.1 authentic Godot runtime capture — requires --vxp311-capture path only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
    echo "${GODOT_BIN}"
    return
  fi
  local candidates=(
    "${HOME}/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot"
    "/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot"
    "/Applications/Godot.app/Contents/MacOS/Godot"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      echo "$c"
      return
    fi
  done
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return
  fi
  echo "ERROR: Godot 4.5 binary not found. Set GODOT_BIN." >&2
  exit 2
}

GODOT="$(resolve_godot)"
mkdir -p artifacts/vxp311/capture artifacts/vxp311/after artifacts/vxp311/manifests artifacts/vxp311/reports artifacts/vxp311/human_review
VER="$("$GODOT" --version)"
echo "Godot: ${VER}"
echo "Binary: ${GODOT}"

set +e
"$GODOT" --path "$ROOT" --rendering-driver opengl3 \
  -s res://tools/vxp311/visual_surface_driver.gd -- --vxp311-capture
EC=$?
set -e
echo "godot_exit=${EC}"

python3 tools/vxp311/validate_capture_manifest.py || true
python3 tools/vxp311/emit_vxp311_gates.py || true

if ls artifacts/vxp311/capture/*.png >/dev/null 2>&1; then
  cp -f artifacts/vxp311/capture/*.png artifacts/vxp311/after/ 2>/dev/null || true
fi

echo "VXP311_RUNTIME_CAPTURE_COMPLETE exit=${EC}"
exit 0
