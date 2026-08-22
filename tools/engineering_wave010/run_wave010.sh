#!/usr/bin/env bash
# make engineering-wave010 entrypoint
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-}"
resolve_godot() {
  if [[ -n "${GODOT_BIN}" && -x "${GODOT_BIN}" ]]; then echo "${GODOT_BIN}"; return; fi
  for c in /Applications/Godot.app/Contents/MacOS/Godot /opt/homebrew/bin/godot; do
    [[ -x "$c" ]] && { echo "$c"; return; }
  done
  command -v godot
}
GODOT="$(resolve_godot)"
mkdir -p artifacts/engineering_wave010 tmp
export GODOT_BIN="$GODOT"

echo "=== Wave010 Godot: $($GODOT --version) ==="

run() {
  local name="$1"; shift
  local log="tmp/wave010-${name}.log"
  echo "=== ${name} ==="
  set +e
  "$@" >"$log" 2>&1
  local code=$?
  set -e
  # Mutation logs intentionally contain "Wave010RuntimeTest FAIL" from killed mutants.
  if [[ "$name" == "mutation" ]]; then
    if [[ $code -ne 0 ]]; then
      echo "FAIL ${name}"
      tail -80 "$log" || true
      return 1
    fi
    echo "PASS ${name}"
    return 0
  fi
  if [[ $code -ne 0 ]] || grep -Eiq 'SCRIPT ERROR|Parse Error|Compilation failed|Wave010RuntimeTest FAIL|Wave010RaceSceneE2E FAIL|Wave010TimeTrialMasteryE2E FAIL' "$log"; then
    echo "FAIL ${name}"
    tail -80 "$log" || true
    return 1
  fi
  echo "PASS ${name}"
}

# Android export probe (honest)
ANDROID_EXPORT="BLOCKED_ENVIRONMENT"
if [[ -f export_presets.cfg ]] && command -v "$GODOT" >/dev/null; then
  if grep -q 'Android' export_presets.cfg 2>/dev/null; then
    if [[ -z "${ANDROID_SDK_ROOT:-}${ANDROID_HOME:-}" ]]; then
      ANDROID_EXPORT="BLOCKED_ENVIRONMENT"
    else
      ANDROID_EXPORT="ATTEMPTED"
    fi
  fi
fi
printf '%s\n' "{\"ANDROID_EXPORT\":\"$ANDROID_EXPORT\",\"PHYSICAL_ANDROID_VALIDATED\":false,\"HUMAN_PLAYTEST_COMPLETE\":false}" \
  > artifacts/engineering_wave010/MOBILE_INPUT_RESULT.json

run import "$GODOT" --headless --path "$ROOT" --import
run wave010_component_runtime "$GODOT" --headless --path "$ROOT" --script res://tests/engineering_wave010/Wave010RuntimeTest.gd
run wave010_racescene_e2e "$GODOT" --headless --path "$ROOT" --script res://tests/engineering_wave010/Wave010RaceSceneE2E.gd
run wave010_time_trial_mastery "$GODOT" --headless --path "$ROOT" --script res://tests/engineering_wave010/Wave010TimeTrialMasteryE2E.gd
run code_integrity bash tools/engineering_wave010/run_code_integrity.sh
run mutation python3 tools/engineering_wave010/run_mutation_campaign.py

# Competitive AI subset (canonical runner — not ProductionGateHarness proof)
run ai_subset env PP_AI_EVAL_SUBSET=1 PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=8 \
  "$GODOT" --headless --path "$ROOT" --script res://tests/CompetitiveAiEvalRunner.gd

python3 tools/engineering_wave010/emit_wave010_result.py

echo
python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("artifacts/engineering_wave010/WAVE010_RESULT.json").read_text())
status=d.get("ENGINEERING_WAVE_010")
print(f"ENGINEERING_WAVE_010={status}")
if status == "PASS":
    print("ENGINEERING_WAVE_010_PEDESTRIAN_PURSUIT_PASS")
else:
    print("ENGINEERING_WAVE_010_PEDESTRIAN_PURSUIT_PARTIAL")
PY
