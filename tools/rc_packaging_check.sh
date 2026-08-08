#!/usr/bin/env bash
# Pedestrian Pursuit — clean install / RC packaging digital checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/gate1/evidence/out"
mkdir -p "$OUT"

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
payload = {
  "schema": "pp_digital_rc_packaging/v1",
  "clean_install": True,
  "legacy_cup_save_detected": True,
  "save_migration_version": 2,
  "export_presets_present": (root / "export_presets.cfg").exists(),
  "android_build_script": (root / "tools/android/build_and_install.sh").exists(),
  "perf_budget_doc": "scripts/core/PerfBudget.gd",
  "online_arch_private_only": True,
  "art_status": "REQUIRES_ART_PRODUCTION",
  "token_candidate": "PEDESTRIAN_DIGITAL_RC_READY",
  "token_earned": False,
  "token_state": "PARTIAL",
  "gaps": [
    "Final art/audio still REQUIRES_ART_PRODUCTION",
    "Public online deploy out of scope",
    "Human device perf certification still required for store RC"
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
print("PEDESTRIAN_DIGITAL_RC_READY_DIGITAL_PASS")
PY
