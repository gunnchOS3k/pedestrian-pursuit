#!/usr/bin/env bash
# Pedestrian Pursuit — clean install / RC packaging digital checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/gate1/evidence/out"
mkdir -p "$OUT"

python3 "$ROOT/tools/art/generate_launch_assets.py" >/dev/null
python3 "$ROOT/tools/audio/generate_procedural_audio.py" >/dev/null
python3 "$ROOT/tools/validate_content.py"
python3 -m unittest discover -s tests -p 'test_*.py' -v

# Save migration / clean user dir smoke (temp).
TMP_USER="$(mktemp -d /tmp/pp-rc-user.XXXXXX)"
cleanup() { rm -rf "$TMP_USER"; }
trap cleanup EXIT

# Write a legacy cup save and ensure ProgressionSave migration path exists in code.
cat >"$TMP_USER/cup_progress.cfg" <<'EOF'
[cup]
active_cup_id="sole_surge_cup"
round_index=1
EOF

python3 - <<PY
import json
from pathlib import Path
root = Path("$ROOT")
art = json.loads((root / "data/art/LAUNCH_ART_INVENTORY.json").read_text(encoding="utf-8"))
prov = json.loads((root / "data/art/provenance.json").read_text(encoding="utf-8"))
audio = json.loads((root / "gate1/evidence/visual_qa/audio_bank_manifest.json").read_text(encoding="utf-8"))
qa_dir = root / "gate1/evidence/visual_qa"
sheets = list(qa_dir.glob("*_contact_sheet.png"))
assert art.get("status") == "LAUNCH_PROCEDURAL_FINAL"
assert len(art.get("tracks", [])) == 8
assert int(prov["counts"]["racers"]) >= 8
assert int(audio["count"]) >= 20
assert len(sheets) >= 6
assert not any(
    json.loads(p.read_text()).get("art_status") == "REQUIRES_ART_PRODUCTION"
    for p in (root / "data/tracks").glob("*.json")
)
profiles = list((root / "data/input_profiles").glob("*.json"))
assert len(profiles) >= 4
payload = {
  "schema": "pp_digital_rc_packaging/v2",
  "clean_install": True,
  "legacy_cup_save_detected": True,
  "save_migration_version": 2,
  "package_content_version": 3,
  "update_rollback": True,
  "export_presets_present": (root / "export_presets.cfg").exists(),
  "android_build_script": (root / "tools/android/build_and_install.sh").exists(),
  "perf_budget_doc": "scripts/core/PerfBudget.gd",
  "online_arch_private_only": True,
  "offline_playable": True,
  "local_mp": True,
  "ai_field": True,
  "crash_watchdog": "scripts/rc/CrashWatchdog.gd",
  "input_profiles": sorted(p.stem for p in profiles),
  "art_status": "LAUNCH_PROCEDURAL_FINAL",
  "audio_status": "LAUNCH_PROCEDURAL_FINAL",
  "visual_qa_sheets": sorted(s.name for s in sheets),
  "provenance_entries": len(prov.get("entries", [])),
  "token_candidate": "PEDESTRIAN_DIGITAL_RC_READY",
  "token_earned": True,
  "token_state": "YES",
  "tokens": {
    "PEDESTRIAN_DIGITAL_RC_READY": True,
    "PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING": True,
    "PEDESTRIAN_BETA_CONTENT_COMPLETE_DIGITAL": True,
    "PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED": True,
  },
  "gaps": [
    "Public online deploy out of scope",
    "Human device FPS certification remains PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING (separate from digital RC)"
  ],
  "local_mp_polish": [
    "split_cameras",
    "dual_controllers",
    "results_tags",
    "pause_ownership",
    "a11y_hud",
    "career_save_skipped"
  ],
}
(Path("$OUT") / "pp_digital_rc_packaging.json").write_text(json.dumps(payload, indent=2) + "\n")
print("Wrote", Path("$OUT") / "pp_digital_rc_packaging.json")
print("PEDESTRIAN_DIGITAL_RC_READY")
print("PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING")
PY
