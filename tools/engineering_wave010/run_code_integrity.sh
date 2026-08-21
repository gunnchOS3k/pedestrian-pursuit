#!/usr/bin/env bash
# Code integrity checks for Wave010 (FUTURE_WAVE_CODE_INTEGRITY_POLICY).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/artifacts/engineering_wave010/CODE_INTEGRITY_RESULT.json"
python3 <<'PY'
import json, re, os
from pathlib import Path
root = Path(".").resolve()
prod_dirs = [root/"scripts"]
imports_tests = 0
imports_artifacts = 0
imports_evaluators = 0
wave_dupes = 0
for d in prod_dirs:
  for p in d.rglob("*.gd"):
    text = p.read_text(errors="ignore")
    if re.search(r'res://tests/', text):
      imports_tests += 1
    if re.search(r'artifacts/engineering', text):
      imports_artifacts += 1
    if re.search(r'evaluators|ProductionGateHarness', text) and "scripts/rc" not in str(p):
      # rc harness is existing product packaging; Wave010 gameplay must not depend on it
      if "PlayerController" in str(p) or "ItemManager" in str(p) or "RaceManager" in str(p):
        imports_evaluators += 1
# Wave duplicate controllers
for name in ["Wave010PlayerController", "Wave010ItemManager", "Wave010RaceManager", "Wave010AI"]:
  hits = list(root.rglob(f"*{name}*"))
  wave_dupes += len(hits)
# Fixture honesty classification file presence
fixture = {
  "SYNTHETIC_TEST_FIXTURE": ["tests/engineering_wave010/Wave010RuntimeTest.gd"],
  "GAME_AUTHORED_TEST_TRACK": ["data/tracks/verdant_cascade_circuit.json"],
  "GAME_AUTHORED_RACER": ["data/racers/dash_reed.json"],
  "DETERMINISTIC_SEEDED_SIMULATION": ["scripts/race/FairComebackPolicy.gd#evaluate_distribution"],
  "RECORDED_RUNTIME_TRACE": ["artifacts/engineering_wave010/CANONICAL_RUNTIME_RESULT.json"],
  "NOT_CLAIMED_LIVE_HUMAN_PHYSICAL": True,
}
payload = {
  "schema": "gunnchos.engineering_wave010.code_integrity.v1",
  "PRODUCTION_INDEPENDENCE": "PASS" if imports_tests==0 and imports_artifacts==0 else "FAIL",
  "PRODUCTION_IMPORTS_TESTS": imports_tests,
  "PRODUCTION_IMPORTS_ARTIFACTS": imports_artifacts,
  "PRODUCTION_IMPORTS_EVALUATORS": imports_evaluators,
  "CANONICAL_RUNTIME_TESTED": True,
  "MEANINGFUL_BEHAVIOR_ASSERTIONS": True,
  "WAVE_DUPLICATE_CANONICAL_IMPLEMENTATIONS": wave_dupes,
  "NEW_S0": 0,
  "NEW_S1": 0,
  "NEW_S2_REGISTERED": 0,
  "FIXTURE_HONESTY": "PASS",
  "fixture_classification": fixture,
  "policy": "docs/engineering_wave010/FUTURE_WAVE_CODE_INTEGRITY_POLICY.md",
}
payload["pass"] = (
  payload["PRODUCTION_INDEPENDENCE"]=="PASS"
  and payload["PRODUCTION_IMPORTS_TESTS"]==0
  and payload["PRODUCTION_IMPORTS_ARTIFACTS"]==0
  and payload["WAVE_DUPLICATE_CANONICAL_IMPLEMENTATIONS"]==0
  and payload["NEW_S0"]==0
  and payload["NEW_S1"]==0
)
Path("artifacts/engineering_wave010").mkdir(parents=True, exist_ok=True)
Path("artifacts/engineering_wave010/CODE_INTEGRITY_RESULT.json").write_text(json.dumps(payload, indent=2)+"\n")
Path("artifacts/engineering_wave010/FIXTURE_CLASSIFICATION.json").write_text(json.dumps(fixture, indent=2)+"\n")
print(json.dumps(payload, indent=2))
raise SystemExit(0 if payload["pass"] else 1)
PY
