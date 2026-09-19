#!/usr/bin/env python3
"""Structural asserts for VXP-3 presentation layer (no gameplay mutation checks)."""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ok = True
errors: list[str] = []


def check(cond: bool, msg: str) -> None:
    global ok
    if not cond:
        ok = False
        errors.append(msg)
        print("FAIL:", msg)
    else:
        print("PASS:", msg)


brand = ROOT / "assets/branding/vxp3"
required = [
    brand / "pedestrian-pursuit-wordmark.svg",
    brand / "pp-kinetic-mark.svg",
    brand / "pp-kinetic-mark-monochrome.svg",
    brand / "pp-speed-stripe.svg",
    brand / "pp-sole-track.svg",
    brand / "pp-focus-frame.svg",
    brand / "pp-course-divider.svg",
    brand / "BRAND_PROVENANCE.json",
    brand / "README.md",
]
for p in required:
    check(p.exists(), f"brand asset present: {p.relative_to(ROOT)}")

glyphs = list((brand / "glyphs").glob("glyph_*.svg"))
check(len(glyphs) >= 20, f"glyph count >= 20 (got {len(glyphs)})")

scripts = [
    ROOT / "scripts/ui/vxp3/Vxp3Brand.gd",
    ROOT / "scripts/ui/vxp3/Vxp3Presentation.gd",
    ROOT / "scripts/ui/vxp3/TutorialCoach.gd",
]
for p in scripts:
    check(p.exists(), f"script present: {p.relative_to(ROOT)}")

main = (ROOT / "scripts/ui/MainMenu.gd").read_text()
check("DIGITAL RC READY" not in main, "MainMenu removes DIGITAL RC READY engineer copy")
check("procedural-final presentation" not in main, "MainMenu removes procedural-final engineer copy")
check("Vxp3PresentationScript" in main, "MainMenu wires Vxp3Presentation")
check("Learn the Track" in main or "first_run_copy" in main, "first-run Learn the Track present")

pause = (ROOT / "scripts/ui/PauseMenu.gd").read_text()
check("toggle_pause" in pause, "PauseMenu preserves toggle_pause semantics")
check("apply_pause_chrome" in pause, "PauseMenu applies VXP3 chrome")

results = (ROOT / "scripts/ui/ResultsScreen.gd").read_text()
check("🥇" not in results and "🥈" not in results and "🥉" not in results, "ResultsScreen drops emoji medals")
check("podium_glyph_prefix" in results, "ResultsScreen uses VXP podium glyphs")

hud = (ROOT / "scripts/ui/RaceHUD.gd").read_text()
check("apply_hud_chrome" in hud, "RaceHUD applies VXP3 chrome")
check("DriftMeter" in hud, "RaceHUD includes drift meter chrome")

tut = (ROOT / "scripts/ui/TutorialDirector.gd").read_text()
check("mark_tutorial_done" in tut, "TutorialDirector preserves completion contract")
check("TutorialCoach" in tut, "TutorialDirector integrates TutorialCoach")

prov = json.loads((brand / "BRAND_PROVENANCE.json").read_text())
check(prov.get("design_direction_label") == "KINETIC SOLE", "provenance labels KINETIC SOLE")
check(prov.get("game_name") == "Pedestrian Pursuit", "product name unchanged")
check(prov.get("VXP3_ALL_HISTORICAL_RIGHTS_CLEARED") is False, "historical rights not falsely cleared")
check(prov.get("VXP3_CUSTOM_FONT_PENDING") is True, "custom font pending flagged")

# Do not promote launcher-icon
check(
    all("launcher-icon" not in a.get("path", "") for a in prov.get("assets", [])),
    "launcher-icon not listed as new canonical asset",
)

docs = [
    "docs/vxp3/README.md",
    "docs/vxp3/VXP3_BRAND_SYSTEM.md",
    "docs/vxp3/VXP3_PLAYER_PRESENTATION_CONSTITUTION.md",
    "docs/vxp3/VXP3_SURFACE_MATRIX.md",
    "docs/vxp3/VXP3_TUTORIAL_PRESENTATION.md",
    "docs/vxp3/VXP3_RACE_HUD_SPEC.md",
    "docs/vxp3/VXP3_ACCESSIBILITY.md",
    "docs/vxp3/VXP3_RIGHTS_PROVENANCE.md",
    "docs/vxp3/VXP3_BEFORE_AFTER.md",
    "docs/vxp3/VXP3_FUTURE_ART_MAP.md",
    "docs/vxp3/VXP3_HUMAN_VALIDATION_PACKET.md",
]
for d in docs:
    check((ROOT / d).exists(), f"doc present: {d}")

out = {
    "pass": ok,
    "errors": errors,
    "glyph_count": len(glyphs),
}
out_path = ROOT / "artifacts/vxp3/capture/STRUCTURAL_RESULT.json"
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(json.dumps(out, indent=2) + "\n")
print(json.dumps(out, indent=2))
sys.exit(0 if ok else 1)
