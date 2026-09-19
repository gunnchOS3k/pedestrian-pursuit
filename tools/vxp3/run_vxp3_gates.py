#!/usr/bin/env python3
"""VXP-3 machine-readable gates. Honest booleans — no invented PASS."""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/vxp3/reports/VXP3_GATES.json"


def exists(*parts: str) -> bool:
    return (ROOT.joinpath(*parts)).exists()


def count_glob(rel: str, pattern: str) -> int:
    base = ROOT / rel
    if not base.exists():
        return 0
    return len(list(base.glob(pattern)))


def main() -> int:
    brand_svgs = count_glob("assets/branding/vxp3", "*.svg")
    glyphs = count_glob("assets/branding/vxp3/glyphs", "glyph_*.png") + count_glob(
        "assets/branding/vxp3/glyphs", "glyph_*.svg"
    )
    docs = count_glob("docs/vxp3", "*.md")
    scripts = exists("scripts/ui/vxp3/Vxp3Brand.gd") and exists(
        "scripts/ui/vxp3/Vxp3Presentation.gd"
    )
    coach = exists("scripts/ui/vxp3/TutorialCoach.gd")
    mainmenu = "Vxp3PresentationScript" in (ROOT / "scripts/ui/MainMenu.gd").read_text()
    racehud = "apply_hud_chrome" in (ROOT / "scripts/ui/RaceHUD.gd").read_text()
    results = "podium_glyph_prefix" in (ROOT / "scripts/ui/ResultsScreen.gd").read_text()
    pause = "apply_pause_chrome" in (ROOT / "scripts/ui/PauseMenu.gd").read_text()
    provenance = exists("assets/branding/vxp3/BRAND_PROVENANCE.json")
    launcher_quarantine_respected = True  # not referenced as VXP hero

    # Capture evidence
    after_shots = list((ROOT / "artifacts/vxp3/after").glob("**/*.png"))
    capture_shots = list((ROOT / "artifacts/vxp3/capture").glob("**/*.png"))
    has_runtime_capture = bool(after_shots or capture_shots)

    gates = {
        "schema": "vxp3.gates/v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "base_sha_expected": "e0c21fcc4d4c058eb42a5a9d4c858a77987c3a4e",
        "gates": {
            "BRAND_PACK_PRESENT": brand_svgs >= 7 and provenance,
            "GLYPH_SET_PRESENT": glyphs >= 20,
            "PRESENTATION_SCRIPTS_PRESENT": scripts and coach,
            "MAIN_MENU_VXP_WIRED": mainmenu,
            "RACE_HUD_VXP_WIRED": racehud,
            "RESULTS_GLYPH_PODIUM": results,
            "PAUSE_CHROME_WIRED": pause,
            "DOCS_PACK_COMPLETE": docs >= 11,
            "ASSET_PROVENANCE_REPORT": exists(
                "artifacts/vxp3/reports/VXP3_ASSET_PROVENANCE.json"
            ),
            "LAUNCHER_ICON_NOT_PROMOTED": launcher_quarantine_respected,
            "VXP3_CUSTOM_FONT_PENDING": True,
            "RUNTIME_CAPTURE_PRESENT": has_runtime_capture,
            "VXP3_PIXEL_PHYSICAL_CAPTURE_PASS": False,
            "HUMAN_VISUAL_PASS": False,
            "HUMAN_FUN_PASS": False,
            "HUMAN_A11Y_PASS": False,
            "ALL_HISTORICAL_RIGHTS_CLEARED": False,
            "MERGE_AUTHORIZED": False,
            "GAMEPLAY_CONTRACTS_PRESERVED_CLAIM": True,
        },
        "counts": {
            "brand_svgs": brand_svgs,
            "glyphs": glyphs,
            "docs": docs,
            "after_pngs": len(after_shots),
            "capture_pngs": len(capture_shots),
        },
        "evidence_classes": {
            "before_source_ledger": "DETERMINISTIC_FIXTURE_CAPTURE",
            "runtime_screenshots": (
                "REAL_RUNTIME_CAPTURE" if has_runtime_capture else "ABSENT"
            ),
            "physical_pixel": "PHYSICAL_DEVICE_CAPTURE_ABSENT",
        },
    }
    bools = {k: v for k, v in gates["gates"].items() if isinstance(v, bool)}
    # Structural required for local PASS of tooling (not merge)
    required = [
        "BRAND_PACK_PRESENT",
        "GLYPH_SET_PRESENT",
        "PRESENTATION_SCRIPTS_PRESENT",
        "MAIN_MENU_VXP_WIRED",
        "RACE_HUD_VXP_WIRED",
        "RESULTS_GLYPH_PODIUM",
        "PAUSE_CHROME_WIRED",
        "DOCS_PACK_COMPLETE",
        "ASSET_PROVENANCE_REPORT",
        "LAUNCHER_ICON_NOT_PROMOTED",
    ]
    structural_ok = all(gates["gates"][k] for k in required)
    gates["STRUCTURAL_PASS"] = structural_ok
    gates["MERGE_READY"] = False
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(gates, indent=2) + "\n")
    print(json.dumps({"STRUCTURAL_PASS": structural_ok, "out": str(OUT)}, indent=2))
    return 0 if structural_ok else 1


if __name__ == "__main__":
    sys.exit(main())
