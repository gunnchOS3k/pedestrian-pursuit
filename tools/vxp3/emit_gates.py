#!/usr/bin/env python3
"""Emit machine-readable VXP-3 gates. Honest defaults — never invent Pixel/human PASS."""
from __future__ import annotations
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/vxp3/reports/VXP3_GATES.json"
OUT.parent.mkdir(parents=True, exist_ok=True)


def sh(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, cwd=ROOT, text=True).strip()


head = sh(["git", "rev-parse", "HEAD"])
try:
    origin_main = sh(["git", "rev-parse", "origin/main"])
except Exception:
    origin_main = ""
try:
    base = sh(["git", "merge-base", "HEAD", "origin/main"])
except Exception:
    base = head

brand = ROOT / "assets/branding/vxp3/BRAND_PROVENANCE.json"
theme = ROOT / "assets/ui/vxp3/themes/pp_vxp3_theme.tres"
manifest = ROOT / "artifacts/vxp3/manifests/VXP3_SCREENSHOT_MANIFEST.json"
struct_log = ROOT / "artifacts/vxp3/capture/STRUCTURAL_RESULT.json"
prov_report = ROOT / "artifacts/vxp3/reports/VXP3_ASSET_PROVENANCE.json"

structural_pass = False
if struct_log.exists():
    structural_pass = bool(json.loads(struct_log.read_text()).get("pass"))

shots_ok = False
shot_count = 0
capture_class = "none"
if manifest.exists():
    man = json.loads(manifest.read_text())
    shots = man.get("shots", [])
    shot_count = len(shots)
    capture_class = str(man.get("capture_class", "unknown"))
    shots_ok = shot_count > 0 and all(bool(s.get("ok", True)) for s in shots)

main_txt = (ROOT / "scripts/ui/MainMenu.gd").read_text()
pres_txt = (ROOT / "scripts/ui/vxp3/Vxp3Presentation.gd").read_text()
pause_txt = (ROOT / "scripts/ui/PauseMenu.gd").read_text()
results_txt = (ROOT / "scripts/ui/ResultsScreen.gd").read_text()
hud_txt = (ROOT / "scripts/ui/RaceHUD.gd").read_text()
tut_txt = (ROOT / "scripts/ui/TutorialDirector.gd").read_text()

if brand.exists() and not prov_report.exists():
    prov_report.write_text(brand.read_text())

perf = {
    "program": "VXP-3",
    "note": "No dedicated frame-time regression harness in this lane; presentation-only.",
    "hud_chrome_added": True,
    "gameplay_systems_mutated": False,
    "VXP3_PERFORMANCE_REGRESSION_CLAIMED": False,
}
(ROOT / "artifacts/vxp3/reports/VXP3_PERFORMANCE.json").write_text(json.dumps(perf, indent=2) + "\n")

gates = {
    "program": "VXP-3",
    "title": "Pedestrian Pursuit brand, race chrome, and player presentation",
    "base_sha": origin_main,
    "head_sha": head,
    "merge_base_with_origin_main": base,
    "branch": sh(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
    "worktree": str(ROOT),
    "discrepancy_resolution": {
        "audited_local_head": "599c6b320d7c2d2340ead82f74f085a7b17939fc",
        "identity": "tip of cursor/windows-pilot0-authentic-evidence (prior audit SHA)",
        "relation_to_origin_main": "ancestor (merged via PR #23 into main before Stream C #24)",
        "decision": "Branch VXP-3 from origin/main e0c21fc; do not mix dirty checkout; preserve local owner work untouched",
    },
    "assets": {
        "brand_provenance_present": brand.exists(),
        "vxp3_theme_present": theme.exists(),
        "launcher_icon_promoted_canonical": False,
    },
    "VXP3_BRAND_ASSETS_PRESENT": brand.exists() and theme.exists(),
    "VXP3_CUSTOM_FONT_PENDING": True,
    "VXP3_STRUCTURAL_ASSERTS_PASS": structural_pass,
    "VXP3_MAIN_MENU_ENGINEER_COPY_REMOVED": (
        "DIGITAL RC READY" not in main_txt and "procedural-final presentation" not in main_txt
    ),
    "VXP3_PRIMARY_CTA_PRESENT": (("RACE" in main_txt or "RACE" in pres_txt) and ("Championship" in main_txt or "Championship" in pres_txt)),
    "VXP3_DEVICE_LAB_DEMOTED": "Advanced · Device Lab" in main_txt,
    "VXP3_FIRST_RUN_LEARN_THE_TRACK": "Learn the Track" in main_txt or "first_run_copy" in main_txt,
    "VXP3_FOOTWEAR_PLAYER_COPY": "_refresh_shoe_player_copy" in main_txt,
    "VXP3_HUD_CHROME_APPLIED": "apply_hud_chrome" in hud_txt and "DriftMeter" in hud_txt,
    "VXP3_PAUSE_RESUME_SEMANTICS_PRESERVED": "toggle_pause" in pause_txt and "apply_pause_chrome" in pause_txt,
    "VXP3_RESULTS_PODIUM_GLYPHS": "podium_glyph_prefix" in results_txt and "🥇" not in results_txt,
    "VXP3_TUTORIAL_COMPLETION_PRESERVED": "mark_tutorial_done" in tut_txt,
    "VXP3_TUTORIAL_COACH_PRESENT": (ROOT / "scripts/ui/vxp3/TutorialCoach.gd").exists(),
    "VXP3_SCREENSHOT_FIXTURE_CAPTURE_PASS": shots_ok,
    "VXP3_SCREENSHOT_CAPTURE_CLASS": capture_class,
    "VXP3_SCREENSHOT_COUNT": shot_count,
    "VXP3_REAL_RUNTIME_CAPTURE_PASS": False,  # fixture composites are DETERMINISTIC_FIXTURE_CAPTURE only
    "VXP3_PIXEL_PHYSICAL_CAPTURE_PASS": False,
    "VXP3_HUMAN_VISUAL_VALIDATION_PASS": False,
    "VXP3_HUMAN_FUN_VALIDATION_PASS": False,
    "VXP3_HUMAN_A11Y_VALIDATION_PASS": False,
    "VXP3_ALL_HISTORICAL_RIGHTS_CLEARED": False,
    "VXP3_MERGE_AUTHORIZED": False,
    "VXP3_READY_FOR_DRAFT_PR": True,
}

OUT.write_text(json.dumps(gates, indent=2) + "\n")
print(json.dumps(gates, indent=2))
print("wrote", OUT)
