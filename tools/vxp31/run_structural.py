#!/usr/bin/env python3
"""VXP-3.1 structural checks (export refs, font license, capture gating, podium, engineer copy)."""
from __future__ import annotations

import hashlib
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


def main() -> int:
    export = (ROOT / "export_presets.cfg").read_text()
    project = (ROOT / "project.godot").read_text()
    check("assets/branding/vxp31/launcher_icon_192.png" in export, "export main_192 uses vxp31 launcher")
    check("assets/branding/vxp31/launcher_adaptive_foreground_432.png" in export, "export adaptive fg cleared")
    check("assets/branding/launcher-icon.png" not in export, "quarantined launcher-icon not in export")
    check("assets/branding/vxp31/launcher_icon_512.png" in project, "project icon cleared vxp31")
    check("assets/branding/vxp31/splash_1280x720.png" in project, "boot splash cleared vxp31")

    font = ROOT / "assets/fonts/vxp31/barlow_condensed"
    ofl = font / "OFL.txt"
    ttf = font / "BarlowCondensed-SemiBold.ttf"
    check(ofl.exists() and ttf.exists(), "Barlow Condensed + OFL present")
    if ofl.exists():
        check("SIL OPEN FONT LICENSE" in ofl.read_text().upper(), "OFL license text valid")

    driver = (ROOT / "tools/vxp31/visual_surface_driver.gd").read_text()
    check("--vxp31-capture" in driver, "capture driver flag-gated")
    check("extends SceneTree" in driver, "capture driver is SceneTree script (not production autoload)")
    # Ensure not wired as autoload
    check("visual_surface_driver" not in project, "capture driver not production autoload")

    results = (ROOT / "scripts/ui/ResultsScreen.gd").read_text()
    check("ensure_podium_glyphs" in results, "results uses podium glyph textures")
    check("🥇" not in results and "[1]" not in results, "no emoji / [1] podium placeholders in ResultsScreen")

    presentation = (ROOT / "scripts/ui/vxp3/Vxp3Presentation.gd").read_text()
    check('return "[1]"' not in presentation, "presentation drops [1] text podium placeholders")
    check("HudCluster" in presentation or "_recluster_hud" in presentation, "HUD reclustering present")

    coach = (ROOT / "scripts/ui/vxp3/TutorialCoach.gd").read_text()
    check("place_adaptive" in coach, "TutorialCoach adaptive placement")

    main_menu = (ROOT / "scripts/ui/MainMenu.gd").read_text()
    for token in ("DIGITAL RC READY", "procedural-final presentation", "PROCEDURAL_FINAL"):
        check(token not in main_menu, f"engineer copy absent: {token}")

    prog = (ROOT / "scripts/core/ProgressionSave.gd").read_text()
    check("enable_vxp31_sandbox" in prog, "ProgressionSave sandbox for capture")
    check("vxp31_sandbox" in prog, "sandbox path isolated from owner saves")

    uids = list((ROOT / "scripts/ui/vxp3").glob("*.uid"))
    check(len(uids) >= 3, f"vxp3 uid files present ({len(uids)})")

    for tool in (
        "tools/vxp31/run_runtime_capture.sh",
        "tools/vxp31/validate_capture_manifest.py",
        "tools/vxp31/emit_vxp31_gates.py",
        "tools/vxp31/visual_surface_driver.gd",
    ):
        check((ROOT / tool).exists(), f"tool present: {tool}")

    docs = [
        "docs/vxp31/README.md",
        "docs/vxp31/VXP31_RUNTIME_VISUAL_ACCEPTANCE.md",
        "docs/vxp31/VXP31_VISUAL_DEFECT_REPAIR.md",
        "docs/vxp31/VXP31_TYPOGRAPHY_CLOSURE.md",
        "docs/vxp31/VXP31_LAUNCHER_SPLASH_CLOSURE.md",
        "docs/vxp31/VXP31_ACCESSIBILITY_RUNTIME_REVIEW.md",
        "docs/vxp31/VXP31_RIGHTS_CLOSURE.md",
        "docs/vxp31/VXP31_BEFORE_AFTER.md",
        "docs/vxp31/VXP31_HUMAN_HANDOFF.md",
    ]
    for d in docs:
        check((ROOT / d).exists(), f"doc present: {d}")

    prov = ROOT / "assets/branding/vxp31/BRAND_PROVENANCE.json"
    check(prov.exists(), "vxp31 brand provenance present")

    out = {"pass": ok, "errors": errors}
    out_path = ROOT / "artifacts/vxp31/reports/VXP31_STRUCTURAL_RESULT.json"
    # Preserve test result flags if present
    if out_path.exists():
        prev = json.loads(out_path.read_text())
        for k in (
            "headless_smoke_pass",
            "production_gate_pass",
            "stream_c_pass",
            "vxp3_structural_pass",
        ):
            if k in prev:
                out[k] = prev[k]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
