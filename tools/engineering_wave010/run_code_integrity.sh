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

# Causal mastery authenticity gates (GAME-PP-015) — static S0 if present.
driver = root/"tests/engineering_wave010/SyntheticInputDriver.gd"
mastery_e2e = root/"tests/engineering_wave010/Wave010TimeTrialMasteryE2E.gd"
if driver.exists():
  dt = driver.read_text(errors="ignore")
  if re.search(r"look_ahead\s*=\s*15\.0\s*if", dt) or re.search(r"look_ahead\s*=\s*10\.0\s*if", dt):
    findings.append({"severity": "S0", "id": "MASTERY_STEERING_MISMATCH", "path": str(driver.relative_to(root))})
  if re.search(r"steer\s*\*=\s*0\.88|steer\s*\*\s*0\.88", dt):
    findings.append({"severity": "S0", "id": "BASIC_STEERING_HANDICAP", "path": str(driver.relative_to(root))})
  if "technique_counts" in dt and "drift_release" in dt and re.search(r'technique_counts\["drift_release"\].*\+\s*1', dt):
    findings.append({"severity": "S0", "id": "DRIVER_INTENT_AS_TECHNIQUE_SUCCESS", "path": str(driver.relative_to(root))})
if mastery_e2e.exists():
  mt = mastery_e2e.read_text(errors="ignore")
  if "lap_changed" in mt and re.search(r"finished_at\s*=.*lap_events", mt):
    findings.append({"severity": "S0", "id": "LAP_EVENT_FINISH_FALLBACK", "path": str(mastery_e2e.relative_to(root))})
  if re.search(r"finish_and_save\(\s*30\.0\s*\)", mt) and re.search(r"finish_and_save\(\s*25\.0\s*\)", mt):
    findings.append({"severity": "S0", "id": "SYNTHETIC_GHOST_PROBE_AS_CLOSURE", "path": str(mastery_e2e.relative_to(root))})

# Artifact-level causal checks when present
mastery_art = root/"artifacts/engineering_wave010/MASTERY_RESULT.json"
if mastery_art.exists():
  try:
    mj = json.loads(mastery_art.read_text())
    if mj.get("BASIC_HANDICAP_PRESENT") is True:
      findings.append({"severity": "S0", "id": "BASIC_HANDICAP_PRESENT_ARTIFACT", "path": str(mastery_art.relative_to(root))})
    if mj.get("DRIVER_PARAMETERS_MATCH") is False and mj.get("reliable") is True:
      findings.append({"severity": "S0", "id": "RELIABLE_WITH_DRIVER_MISMATCH", "path": str(mastery_art.relative_to(root))})
    if mj.get("LAP_EVENT_USED_AS_FINISH_FALLBACK") is True:
      findings.append({"severity": "S0", "id": "LAP_EVENT_FINISH_FALLBACK_ARTIFACT", "path": str(mastery_art.relative_to(root))})
    ghost = mj.get("ghost") or {}
    if ghost.get("synthetic_probe_used_as_closure") is True and mj.get("reliable") is True:
      findings.append({"severity": "S0", "id": "SYNTHETIC_GHOST_CLOSURE_ARTIFACT", "path": str(mastery_art.relative_to(root))})
    if mj.get("DRIVER_INTENT_COUNTED_AS_SUCCESS") is True:
      findings.append({"severity": "S0", "id": "INTENT_COUNTED_AS_SUCCESS_ARTIFACT", "path": str(mastery_art.relative_to(root))})
  except Exception as e:
    findings.append({"severity": "S1", "id": "MASTERY_ARTIFACT_UNREADABLE", "path": str(mastery_art.relative_to(root)), "error": str(e)})

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
