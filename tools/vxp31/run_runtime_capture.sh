#!/usr/bin/env bash
# VXP-3.1 authentic Godot runtime capture — requires --vxp31-capture path only.
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
mkdir -p artifacts/vxp31/capture artifacts/vxp31/after artifacts/vxp31/manifests artifacts/vxp31/reports
VER="$("$GODOT" --version)"
echo "Godot: ${VER}"
echo "Binary: ${GODOT}"

# Prefer windowed/GL so viewport textures are real (not null headless frames).
# Do NOT use a short --quit-after; the driver calls quit() when the journey completes.
set +e
"$GODOT" --path "$ROOT" --rendering-driver opengl3 \
  -s res://tools/vxp31/visual_surface_driver.gd -- --vxp31-capture
EC=$?
set -e
echo "godot_exit=${EC}"

python3 tools/vxp31/validate_capture_manifest.py || true
python3 tools/vxp31/emit_vxp31_gates.py || true

# Copy successful PNGs into after/ for before-after packets
if ls artifacts/vxp31/capture/*.png >/dev/null 2>&1; then
  cp -f artifacts/vxp31/capture/*.png artifacts/vxp31/after/ 2>/dev/null || true
fi

echo "VXP31_RUNTIME_CAPTURE_COMPLETE exit=${EC}"
exit 0
