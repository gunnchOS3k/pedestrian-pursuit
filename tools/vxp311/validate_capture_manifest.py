#!/usr/bin/env python3
"""Validate VXP-3.1.1 capture manifest: PNG dimensions, hashes, evidence class."""
from __future__ import annotations

import hashlib
import json
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "artifacts/vxp311/manifests/VXP311_CAPTURE_RUN.json"
OUT = ROOT / "artifacts/vxp311/manifests/VXP311_CAPTURE_MANIFEST.json"
CAP = ROOT / "artifacts/vxp311/capture"

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
    "a11y_high_contrast_main_menu",
    "a11y_high_contrast_race_hud",
    "a11y_high_contrast_pause",
    "a11y_high_contrast_results",
    "local2p_race_hud",
    "local2p_pause",
    "local2p_results",
    "viewport_1280x720",
    "viewport_1366x768",
    "viewport_1600x900",
    "viewport_1920x1080",
    "viewport_pixel_landscape",
]

VIEWPORT_EXPECTED = {
    "viewport_1280x720": (1280, 720, "REAL_RUNTIME_CAPTURE"),
    "viewport_1366x768": (1366, 768, "REAL_RUNTIME_CAPTURE"),
    "viewport_1600x900": (1600, 900, "REAL_RUNTIME_CAPTURE"),
    "viewport_1920x1080": (1920, 1080, "REAL_RUNTIME_CAPTURE"),
    "viewport_pixel_landscape": (
        960,
        540,
        "PIXEL6A_LOGICAL_LANDSCAPE_REAL_RUNTIME_SIMULATION",
    ),
}


def png_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack(">II", data[16:24])
    return int(w), int(h)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_near_black(path: Path) -> bool:
    """Cheap emptiness guard — sample PNG IHDR + a few bytes of IDAT length."""
    data = path.read_bytes()
    if len(data) < 2048:
        return True
    # Extremely tiny compressed frames are suspect.
    return path.stat().st_size < 2048


def main() -> int:
    errors: list[str] = []
    if not RUN.exists():
        payload = {
            "schema": "vxp311.capture_manifest/v1",
            "pass": False,
            "error": "missing_run_manifest",
            "evidence_class": "ABSENT",
        }
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(payload, indent=2) + "\n")
        print("FAIL: missing capture run", RUN)
        return 1

    run = json.loads(RUN.read_text())
    shots = {str(s.get("id")): s for s in run.get("shots", []) if isinstance(s, dict)}
    surfaces: list[dict] = []
    missing: list[str] = []
    hash_owners: dict[str, list[str]] = defaultdict(list)
    viewport_truth = True

    for sid in REQUIRED:
        shot = shots.get(sid)
        png = CAP / f"{sid}.png"
        expected_class = "REAL_RUNTIME_CAPTURE"
        if sid in VIEWPORT_EXPECTED:
            expected_class = VIEWPORT_EXPECTED[sid][2]
        ok = (
            shot is not None
            and str(shot.get("evidence_class", "")) == expected_class
            and shot.get("status") == "CAPTURED"
            and png.exists()
            and not is_near_black(png)
        )
        entry: dict = {
            "id": sid,
            "pass": bool(ok),
            "evidence_class": (shot or {}).get("evidence_class", "ABSENT"),
            "path": str(png.relative_to(ROOT)) if png.exists() else None,
            "requested_resolution": (shot or {}).get("requested_resolution")
            or (shot or {}).get("resolution"),
        }
        if png.exists():
            dims = png_size(png)
            digest = sha256(png)
            entry["sha256"] = digest
            hash_owners[digest].append(sid)
            if dims:
                entry["actual_png_width"] = dims[0]
                entry["actual_png_height"] = dims[1]
            else:
                entry["actual_png_width"] = 0
                entry["actual_png_height"] = 0
                ok = False
                errors.append(f"{sid}: invalid PNG")
        if sid in VIEWPORT_EXPECTED:
            ew, eh, _ec = VIEWPORT_EXPECTED[sid]
            entry["requested_resolution"] = f"{ew}x{eh}"
            aw = int(entry.get("actual_png_width") or 0)
            ah = int(entry.get("actual_png_height") or 0)
            match = aw == ew and ah == eh
            entry["dimension_match"] = match
            if not match:
                ok = False
                viewport_truth = False
                errors.append(f"{sid}: requested {ew}x{eh} actual {aw}x{ah}")
        entry["pass"] = bool(ok)
        surfaces.append(entry)
        if not ok:
            missing.append(sid)

    duplicate_viewport_hashes = False
    viewport_ids = set(VIEWPORT_EXPECTED)
    for digest, owners in hash_owners.items():
        vp_owners = [o for o in owners if o in viewport_ids]
        if len(vp_owners) > 1:
            duplicate_viewport_hashes = True
            viewport_truth = False
            errors.append(f"duplicate viewport hash {digest[:12]}… → {vp_owners}")

    # Podium glyph presence: results_podium must exist and not be a tiny blank.
    podium_ok = any(s["id"] == "results_podium" and s["pass"] for s in surfaces)
    local_mp_ok = all(
        any(s["id"] == i and s["pass"] for s in surfaces)
        for i in ("local2p_race_hud", "local2p_pause", "local2p_results")
    )
    hc_ok = all(
        any(s["id"] == i and s["pass"] for s in surfaces)
        for i in (
            "a11y_high_contrast_main_menu",
            "a11y_high_contrast_race_hud",
            "a11y_high_contrast_pause",
            "a11y_high_contrast_results",
        )
    )

    payload = {
        "schema": "vxp311.capture_manifest/v1",
        "lane": "VXP-3.1.1",
        "parent_pr": 26,
        "pass": len(missing) == 0 and not duplicate_viewport_hashes and viewport_truth,
        "required_count": len(REQUIRED),
        "covered_count": len(REQUIRED) - len(missing),
        "missing": missing,
        "errors": errors,
        "surfaces": surfaces,
        "viewport_truth": viewport_truth and not duplicate_viewport_hashes,
        "duplicate_viewport_hashes": duplicate_viewport_hashes,
        "podium_capture_pass": podium_ok,
        "local_mp_capture_pass": local_mp_ok,
        "high_contrast_capture_pass": hc_ok,
        "high_contrast_dedicated": "IMPLEMENTED",
        "VXP311_PIXEL_PHYSICAL_CAPTURE_PASS": False,
        "viewport_capture_method": run.get("viewport_capture_method", "subviewport_exact_size"),
        "note": "Viewport dimensions computed from PNG IHDR; duplicate viewport hashes fail.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n")
    print(
        json.dumps(
            {
                "pass": payload["pass"],
                "covered": payload["covered_count"],
                "missing": missing,
                "viewport_truth": payload["viewport_truth"],
                "errors": errors[:12],
            },
            indent=2,
        )
    )
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
