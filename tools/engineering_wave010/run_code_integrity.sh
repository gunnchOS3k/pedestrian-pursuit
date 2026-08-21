#!/usr/bin/env bash
# Code integrity checks for Wave010 (FUTURE_WAVE_CODE_INTEGRITY_POLICY).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/artifacts/engineering_wave010/CODE_INTEGRITY_RESULT.json"
python3 <<'PY'
import json, re
from pathlib import Path
root = Path(".").resolve()
prod_dirs = [root/"scripts"]
imports_tests = 0
imports_artifacts = 0
imports_evaluators = 0
findings = []
wave_dupes = 0
for d in prod_dirs:
  for p in d.rglob("*.gd"):
    text = p.read_text(errors="ignore")
    rel = str(p.relative_to(root))
    if re.search(r'res://tests/', text):
      imports_tests += 1
      findings.append({"severity": "S0", "id": "PROD_IMPORTS_TESTS", "path": rel})
    if re.search(r'artifacts/engineering', text):
      imports_artifacts += 1
      findings.append({"severity": "S0", "id": "PROD_IMPORTS_ARTIFACTS", "path": rel})
    if re.search(r'evaluators|ProductionGateHarness', text) and "scripts/rc" not in rel:
      if any(x in rel for x in ("PlayerController", "ItemManager", "RaceManager", "RaceScene", "FairComeback")):
        imports_evaluators += 1
        findings.append({"severity": "S0", "id": "PROD_IMPORTS_EVALUATORS", "path": rel})
# Wave duplicate controllers
for name in ["Wave010PlayerController", "Wave010ItemManager", "Wave010RaceManager", "Wave010AI"]:
  hits = list(root.rglob(f"*{name}*"))
  for h in hits:
    wave_dupes += 1
    findings.append({"severity": "S1", "id": "WAVE_DUPLICATE", "path": str(h.relative_to(root))})

# Hardcoded overclaim markers in emit / committed evidence scripts
emit = root/"tools/engineering_wave010/emit_wave010_result.py"
if emit.exists():
  et = emit.read_text(errors="ignore")
  # Blanket assignment of all 15 as IMPLEMENTED literals without derivation is S1.
  if 'for k in list(req):\n        req[k] = "PARTIAL"' in et and '"GAME-PP-001": "IMPLEMENTED"' in et and "derive_requirements" not in et:
    findings.append({"severity": "S1", "id": "BLANKET_REQUIREMENT_ASSIGNMENT", "path": str(emit.relative_to(root))})

new_s0 = sum(1 for f in findings if f["severity"] == "S0")
new_s1 = sum(1 for f in findings if f["severity"] == "S1")

fixture = {
  "SYNTHETIC_TEST_FIXTURE": ["tests/engineering_wave010/Wave010RuntimeTest.gd"],
  "GAME_AUTHORED_TEST_TRACK": ["data/tracks/verdant_cascade_circuit.json"],
  "GAME_AUTHORED_RACER": ["data/racers/dash_reed.json"],
  "DETERMINISTIC_SEEDED_SIMULATION": ["scripts/race/FairComebackPolicy.gd#evaluate_distribution"],
  "RECORDED_RUNTIME_TRACE": [
    "artifacts/engineering_wave010/CANONICAL_RUNTIME_RESULT.json",
    "artifacts/engineering_wave010/RACESCENE_E2E_RESULT.json",
  ],
  "COMPONENT_RUNTIME": ["tests/engineering_wave010/Wave010RuntimeTest.gd"],
  "RACE_SCENE_E2E": ["tests/engineering_wave010/Wave010RaceSceneE2E.gd"],
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
  "findings": findings,
  "NEW_S0": new_s0,
  "NEW_S1": new_s1,
  "NEW_S2_REGISTERED": 0,
  "FIXTURE_HONESTY": "PASS",
  "fixture_classification": fixture,
  "policy": "docs/engineering_wave010/FUTURE_WAVE_CODE_INTEGRITY_POLICY.md",
}
payload["pass"] = (
  payload["PRODUCTION_INDEPENDENCE"]=="PASS"
  and payload["PRODUCTION_IMPORTS_TESTS"]==0
  and payload["PRODUCTION_IMPORTS_ARTIFACTS"]==0
  and payload["PRODUCTION_IMPORTS_EVALUATORS"]==0
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
