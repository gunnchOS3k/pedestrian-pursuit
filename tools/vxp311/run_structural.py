#!/usr/bin/env python3
"""VXP-3.1.1 structural checks (HC setting, capture gating, docs, tools)."""
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


def main() -> int:
    a11y = (ROOT / "scripts/core/AccessibilitySettings.gd").read_text()
    check("var high_contrast" in a11y, "AccessibilitySettings.high_contrast exists")
    check("func set_high_contrast" in a11y, "set_high_contrast setter exists")
    check('get_value("a11y", "high_contrast", false)' in a11y, "legacy missing-key defaults false")
    check('set_value("a11y", "high_contrast", high_contrast)' in a11y, "high_contrast persisted")

    brand = (ROOT / "scripts/ui/vxp3/Vxp3Brand.gd").read_text()
    check("AccessibilitySettings.high_contrast" in brand, "brand reads dedicated HC flag")
    check("COLOR_HC_BG" in brand and 'Color("141820")' in brand, "designed HC palette (not pure black)")
    check("COLOR_HC_ACCENT" in brand, "HC accent token present")

    menu = (ROOT / "scripts/ui/MainMenu.gd").read_text()
    check("A11yHighContrast" in menu, "MainMenu high-contrast toggle")
    check("set_high_contrast" in menu, "MainMenu wires HC setter")

    results = (ROOT / "scripts/ui/ResultsScreen.gd").read_text()
    check("ensure_podium_glyphs" in results, "podium glyphs wired")
    presentation = (ROOT / "scripts/ui/vxp3/Vxp3Presentation.gd").read_text()
    check("PodiumRow" in presentation, "PodiumRow presentation present")
    check((ROOT / "assets/branding/vxp3/glyphs/glyph_podium_1.png").exists(), "glyph_podium_1.png present")

    driver = (ROOT / "tools/vxp311/visual_surface_driver.gd").read_text()
    check("--vxp311-capture" in driver, "capture driver flag-gated")
    check("extends SceneTree" in driver, "capture driver is SceneTree script")
    check("subviewport_exact_size" in driver or "SubViewport" in driver, "exact-size viewport capture")
    check("local2p_race_hud" in driver, "local2p surfaces in driver")
    check("a11y_high_contrast_main_menu" in driver, "HC surfaces in driver")
    project = (ROOT / "project.godot").read_text()
    check("visual_surface_driver" not in project, "capture driver not production autoload")

    # Do not mutate historical VXP31 gate artifacts from this lane.
    check((ROOT / "artifacts/vxp31/reports/VXP31_GATES.json").exists(), "historical VXP31 gates untouched presence")

    for tool in (
        "tools/vxp311/run_runtime_capture.sh",
        "tools/vxp311/validate_capture_manifest.py",
        "tools/vxp311/emit_vxp311_gates.py",
        "tools/vxp311/visual_surface_driver.gd",
        "tools/vxp311/run_structural.py",
    ):
        check((ROOT / tool).exists(), f"tool present: {tool}")

    docs = [
        "docs/vxp311/README.md",
        "docs/vxp311/VXP311_EVIDENCE_CORRECTION.md",
        "docs/vxp311/VXP311_VIEWPORT_VALIDATION.md",
        "docs/vxp311/VXP311_LOCAL_MP_RUNTIME_REVIEW.md",
        "docs/vxp311/VXP311_HIGH_CONTRAST.md",
        "docs/vxp311/VXP311_ACCESSIBILITY_REGRESSION.md",
        "docs/vxp311/VXP311_BEFORE_AFTER.md",
        "docs/vxp311/VXP311_HUMAN_REVIEW_HANDOFF.md",
    ]
    for d in docs:
        check((ROOT / d).exists(), f"doc present: {d}")

    out = {"pass": ok, "errors": errors}
    out_path = ROOT / "artifacts/vxp311/reports/VXP311_STRUCTURAL_RESULT.json"
    if out_path.exists():
        prev = json.loads(out_path.read_text())
        for k in (
            "headless_smoke_pass",
            "production_gate_pass",
            "stream_c_pass",
            "vxp3_structural_pass",
            "vxp31_structural_pass",
        ):
            if k in prev:
                out[k] = prev[k]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
