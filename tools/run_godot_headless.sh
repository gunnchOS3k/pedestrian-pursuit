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
  echo "PASS ${name}"
  return 0
}

run_step import "$GODOT" --headless --path "$ROOT" --import
run_step startup "$GODOT" --headless --path "$ROOT" --quit-after 2
run_step TestRunner "$GODOT" --headless --path "$ROOT" --script res://tests/TestRunner.gd
run_step G2C6RuntimeTest "$GODOT" --headless --path "$ROOT" --script res://tests/G2C6RuntimeTest.gd
run_step CupFlowTest "$GODOT" --headless --path "$ROOT" --script res://tests/CupFlowTest.gd
run_step AlphaProductStateTest "$GODOT" --headless --path "$ROOT" --script res://tests/AlphaProductStateTest.gd
run_step BetaProductStateTest "$GODOT" --headless --path "$ROOT" --script res://tests/BetaProductStateTest.gd
run_step DigitalRcProductStateTest "$GODOT" --headless --path "$ROOT" --script res://tests/DigitalRcProductStateTest.gd
run_step CompetitiveAiEvalSubset \
  env PP_AI_EVAL_SUBSET=1 PP_AI_EVAL_TIME_SCALE=20 PP_AI_EVAL_MAX_SEC=8 \
  "$GODOT" --headless --path "$ROOT" --script res://tests/CompetitiveAiEvalRunner.gd

echo
echo "PEDESTRIAN_MAIN_GODOT_HEADLESS_PASS"
echo "Beta/Digital-RC headless suites green (AI full matrix is a separate evidence run)."
echo "Full AI matrix: PP_AI_EVAL_TIME_SCALE=24 $GODOT --headless --path . --script res://tests/CompetitiveAiEvalRunner.gd"
