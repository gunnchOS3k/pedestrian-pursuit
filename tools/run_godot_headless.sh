#!/usr/bin/env bash
# Pedestrian Pursuit — headless Godot verification for post-merge main.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return
  fi
  echo "ERROR: Godot 4.5 binary not found. Set GODOT_BIN." >&2
  exit 2
}

GODOT="$(resolve_godot)"
mkdir -p tmp
VERSION="$("$GODOT" --version)"
echo "Godot: ${VERSION}"
echo "Binary: ${GODOT}"

# Patterns that mean the GDScript failed even if Godot exited 0 (false-green).
GODOT_FATAL_PATTERNS='SCRIPT ERROR|Parse Error|Compilation failed|Failed to load script|autoload dependency|FATAL ERROR'

run_step() {
  local name="$1"
  shift
  local log="tmp/godot-${name}.log"
  echo "=== ${name} ==="
  set +e
  "$@" >"${log}" 2>&1
  local code=$?
  set -e
  if [[ $code -ne 0 ]]; then
    echo "FAIL ${name} (exit ${code})"
    tail -80 "${log}" || true
    return $code
  fi
  if grep -Eiq "${GODOT_FATAL_PATTERNS}" "${log}"; then
    echo "FAIL ${name} (Godot reported SCRIPT/Parse/Compilation failure while exit=0 — false-green rejected)"
    rg -n -i "${GODOT_FATAL_PATTERNS}" "${log}" | head -40 || true
    return 1
  fi
  echo "PASS ${name}"
  return 0
}

run_step import "$GODOT" --headless --path "$ROOT" --import
run_step startup "$GODOT" --headless --path "$ROOT" --quit-after 2
run_step TestRunner "$GODOT" --headless --path "$ROOT" --script res://tests/TestRunner.gd
run_step G2C6RuntimeTest "$GODOT" --headless --path "$ROOT" --script res://tests/G2C6RuntimeTest.gd
run_step CupFlowTest "$GODOT" --headless --path "$ROOT" --script res://tests/CupFlowTest.gd
run_step BetaProductStateTest "$GODOT" --headless --path "$ROOT" --script res://tests/BetaProductStateTest.gd
# AlphaProductStateTest / DigitalRcProductStateTest retired from --script runner:
# they printed PASS while SCRIPT ERROR / Compilation failed (autoload-blind).
# Authoritative product evidence: ProductionGateHarness --production-gate below.
echo "=== retired_false_green_script_smokes ==="
echo "RETIRED AlphaProductStateTest DigitalRcProductStateTest (superseded by ProductionGateHarness)"

run_step ProductionGateHarness \
  env PP_PRODUCTION_GATE=1 \
  "$GODOT" --headless --path "$ROOT" --rendering-driver opengl3 -- --production-gate

run_step CompetitiveAiEvalSubset \
  env PP_AI_EVAL_SUBSET=1 PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=8 \
  "$GODOT" --headless --path "$ROOT" --script res://tests/CompetitiveAiEvalRunner.gd

echo
echo "PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS"
echo "Headless suites green with false-green SCRIPT ERROR rejection; Alpha/DigitalRc --script smokes retired; ProductionGateHarness authoritative (AI full matrix is a separate evidence run)."
echo "Full AI matrix: PP_AI_EVAL_TIME_SCALE=24 $GODOT --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd"
