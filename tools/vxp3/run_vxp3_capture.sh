#!/usr/bin/env bash
# VXP-3 capture runner — copies Godot user:// shots into artifacts/vxp3/
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
PHASE="${1:-after}"
mkdir -p artifacts/vxp3/capture artifacts/vxp3/"${PHASE}" artifacts/vxp3/manifests

echo "Godot: $("$GODOT" --version)"
# Prefer windowed capture; --display-driver headless often yields null images.
set +e
"$GODOT" --path "$ROOT" --quit-after 120 -s res://tests/vxp3/vxp3_visual_capture.gd -- --vxp3-capture-phase="${PHASE}"
EC=$?
set -e
echo "godot_exit=${EC}"

# Locate user data
USER_BASE="${HOME}/Library/Application Support/Godot/app_userdata"
# Project name folder may vary; search for vxp3_capture
FOUND="$(find "${USER_BASE}" -type d -path '*/vxp3_capture/*' 2>/dev/null | head -1 || true)"
if [[ -n "${FOUND}" ]]; then
  SRC="$(dirname "${FOUND}")/${PHASE}"
  if [[ -d "${SRC}" ]]; then
    cp -R "${SRC}/." "artifacts/vxp3/${PHASE}/" || true
    cp -R "${SRC}/." "artifacts/vxp3/capture/" || true
    echo "copied from ${SRC}"
  fi
fi

python3 - <<PY
import json, time
from pathlib import Path
root = Path('.')
phase = "${PHASE}"
shots = list((root/'artifacts/vxp3'/phase).glob('*.png')) + list((root/'artifacts/vxp3'/'capture').glob('*.png'))
manifest = {
  "schema": "vxp3.capture_manifest/v1",
  "phase": phase,
  "godot_exit": int("${EC}"),
  "png_count": len(shots),
  "VXP3_PIXEL_PHYSICAL_CAPTURE_PASS": False,
  "evidence_class": "REAL_RUNTIME_CAPTURE" if shots else "ABSENT",
  "shots": [str(p) for p in shots],
}
(root/'artifacts/vxp3'/'manifests'/f'CAPTURE_{phase.upper()}.json').write_text(json.dumps(manifest, indent=2)+'\n')
perf = {
  "schema": "vxp3.performance/v1",
  "note": "Presentation-layer only; no physics changes. Capture harness duration not a race FPS claim.",
  "capture_godot_exit": int("${EC}"),
  "png_count": len(shots),
  "HUD_OVERDRAW_CLAIM": "UNMEASURED",
  "TARGET_60FPS_CLAIM": "UNVALIDATED",
}
(root/'artifacts/vxp3'/'reports'/'VXP3_PERFORMANCE.json').write_text(json.dumps(perf, indent=2)+'\n')
print(json.dumps(manifest, indent=2))
PY

exit 0
