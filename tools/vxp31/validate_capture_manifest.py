#!/usr/bin/env python3
"""Validate VXP-3.1 capture manifest for surface coverage (not file existence alone)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "artifacts/vxp31/manifests/VXP31_CAPTURE_RUN.json"
OUT = ROOT / "artifacts/vxp31/manifests/VXP31_REAL_RUNTIME_CAPTURE_MANIFEST.json"

REQUIRED = [
    "main_menu_default",
    "main_menu_focus_race",
    "runner_select",
    "footwear_select",
    "cup_select",
    "course_select",
    "resume_cup",
    "first_run_learn_the_track",
    "tutorial_sprint",
    "tutorial_drift",
    "tutorial_perfect_step",
    "tutorial_item",
    "tutorial_footwear",
    "race_countdown",
    "race_hud_normal",
    "race_position_lap_time",
    "race_drift_meter",
    "race_boost",
    "race_item_slot",
    "race_wrong_way",
    "race_minimap",
    "race_footwear_surface",
    "pause_menu",
    "pause_tutorial_guide",
    "results_finish",
    "results_podium",
    "cup_standings",
    "achievement_toast",
    "a11y_larger_ui",
    "a11y_colorblind",
    "a11y_reduce_motion",
    "viewport_1280x720",
    "viewport_1366x768",
    "viewport_1600x900",
    "viewport_pixel_landscape",
]


def main() -> int:
    if not RUN.exists():
        print("FAIL: missing capture run manifest", RUN)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(
            json.dumps(
                {
                    "schema": "vxp31.real_runtime_capture_manifest/v1",
                    "pass": False,
                    "error": "missing_run_manifest",
                    "evidence_class": "ABSENT",
                },
                indent=2,
            )
            + "\n"
        )
        return 1

    run = json.loads(RUN.read_text())
    shots = {str(s.get("id")): s for s in run.get("shots", []) if isinstance(s, dict)}
    surfaces = []
    missing = []
    for sid in REQUIRED:
        shot = shots.get(sid)
        png = ROOT / "artifacts/vxp31/capture" / f"{sid}.png"
        ok = (
            shot is not None
            and shot.get("evidence_class") == "REAL_RUNTIME_CAPTURE"
            and shot.get("status") in ("CAPTURED",)
            and png.exists()
            and png.stat().st_size > 2048
        )
        entry = {
            "id": sid,
            "pass": bool(ok),
            "evidence_class": (shot or {}).get("evidence_class", "ABSENT"),
            "path": str(png.relative_to(ROOT)) if png.exists() else None,
            "resolution": (shot or {}).get("resolution"),
        }
        surfaces.append(entry)
        if not ok:
            missing.append(sid)

    payload = {
        "schema": "vxp31.real_runtime_capture_manifest/v1",
        "lane": "VXP-3.1",
        "parent_pr": 25,
        "pass": len(missing) == 0,
        "required_count": len(REQUIRED),
        "covered_count": len(REQUIRED) - len(missing),
        "missing": missing,
        "surfaces": surfaces,
        "high_contrast_dedicated": "NOT_IMPLEMENTED",
        "VXP31_PIXEL_PHYSICAL_CAPTURE_PASS": False,
        "note": "Surface coverage requires REAL_RUNTIME_CAPTURE class + non-trivial PNG.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({"pass": payload["pass"], "covered": payload["covered_count"], "missing": missing}, indent=2))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
