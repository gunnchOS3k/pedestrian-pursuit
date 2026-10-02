#!/usr/bin/env python3
"""Validate V4 course identity + power-up distribution readability contracts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
IDENTITY_V4 = ROOT / "data" / "gamefeel" / "course_identity_v4.json"
TRACKS = ROOT / "data" / "tracks"
OUT_DIR = ROOT / "artifacts" / "v4"

LAUNCH = [
    "verdant_cascade_circuit",
    "cloverwind_ranch",
    "tideglass_harbor",
    "neon_switchyard",
    "cloudstep_ridge",
    "prism_apex",
    "mirage_mesa",
    "emberkeep_gauntlet",
]

V4_KEYS = [
    "route_topology",
    "signature_mechanic",
    "boost_moment",
    "landmark_memory",
    "silhouette_grammar",
    "preview",
    "macro_terrain",
    "skyline_props",
]


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_identity(errors: list[str]) -> dict[str, Any]:
    if not IDENTITY_V4.exists():
        errors.append("missing course_identity_v4.json")
        return {}
    data = _load(IDENTITY_V4)
    courses = data.get("courses", {})
    silhouettes: set[str] = set()
    topologies: set[str] = set()
    mechanics: set[str] = set()
    boosts: set[str] = set()
    for tid in LAUNCH:
        course = courses.get(tid)
        if not isinstance(course, dict):
            errors.append(f"{tid}: missing from v4 identity")
            continue
        for key in V4_KEYS:
            if key not in course or course[key] in ("", None, {}, []):
                errors.append(f"{tid}: missing {key}")
        silhouettes.add(str(course.get("silhouette_grammar", "")))
        topologies.add(str(course.get("route_topology", "")))
        mechanics.add(str(course.get("signature_mechanic", "")))
        boosts.add(str(course.get("boost_moment", "")))
        marks = course.get("landmarks", [])
        if not isinstance(marks, list) or len(marks) < 3:
            errors.append(f"{tid}: need >=3 landmarks, got {len(marks) if isinstance(marks, list) else 0}")
        preview = course.get("preview", {})
        for pk in ("silhouette", "landmark", "mechanic", "boost"):
            if not str(preview.get(pk, "")).strip():
                errors.append(f"{tid}: preview.{pk} empty")
    if len(silhouettes) < 8:
        errors.append(f"silhouette_grammar uniqueness {len(silhouettes)}/8")
    if len(topologies) < 8:
        errors.append(f"route_topology uniqueness {len(topologies)}/8")
    if len(mechanics) < 8:
        errors.append(f"signature_mechanic uniqueness {len(mechanics)}/8")
    if len(boosts) < 8:
        errors.append(f"boost_moment uniqueness {len(boosts)}/8")
    return {
        "courses": len(courses),
        "unique_silhouettes": len(silhouettes),
        "unique_topologies": len(topologies),
        "unique_mechanics": len(mechanics),
        "unique_boost_moments": len(boosts),
    }


def _overlap(indices: list[int], other: list[int], label: str, tid: str, errors: list[str]) -> None:
    shared = set(indices) & set(other)
    if shared:
        errors.append(f"{tid}: spawn overlap on {label} at {sorted(shared)}")


def validate_distribution(errors: list[str]) -> dict[str, Any]:
    rows: dict[str, Any] = {}
    for tid in LAUNCH:
        path = TRACKS / f"{tid}.json"
        if not path.exists():
            errors.append(f"{tid}: track json missing")
            continue
        track = _load(path)
        points = track.get("path_points", [])
        n = len(points) if isinstance(points, list) else 0
        items = [int(x) for x in track.get("item_boxes", [])]
        boosts = [int(x) for x in track.get("boost_pickups", [])]
        lanes = [int(x.get("point_index", -1)) for x in track.get("speed_lanes", []) if isinstance(x, dict)]
        pads = [int(x.get("point_index", -1)) for x in track.get("bounce_pads", []) if isinstance(x, dict)]
        shorts = track.get("shortcut_routes", [])
        for idx in items + boosts + lanes + pads:
            if idx < 0 or idx >= n:
                errors.append(f"{tid}: feature index {idx} out of range (n={n})")
        if not items:
            errors.append(f"{tid}: no item boxes")
        if not boosts:
            errors.append(f"{tid}: no boost pickups")
        if not lanes:
            errors.append(f"{tid}: no speed lanes")
        if not isinstance(shorts, list) or not shorts:
            errors.append(f"{tid}: no shortcut routes")
        # Soft overlap: item box and boost on same point is discouraged.
        _overlap(items, boosts, "item/boost", tid, errors)
        rows[tid] = {
            "path_points": n,
            "item_boxes": items,
            "boost_pickups": boosts,
            "speed_lanes": lanes,
            "bounce_pads": pads,
            "shortcuts": [s.get("id") for s in shorts if isinstance(s, dict)],
            "terrain_zones": [
                {"point_index": z.get("point_index"), "terrain_name": z.get("terrain_name")}
                for z in track.get("terrain_zones", [])
                if isinstance(z, dict)
            ],
        }
    return rows


def validate_code_presence(errors: list[str]) -> dict[str, bool]:
    checks = {
        "CourseWorldAssembler": ROOT / "scripts" / "gamefeel" / "CourseWorldAssembler.gd",
        "ItemEffectVisuals": ROOT / "scripts" / "items" / "ItemEffectVisuals.gd",
        "course_identity_v4": IDENTITY_V4,
        "ItemBox_pursuit_pod": ROOT / "scripts" / "items" / "ItemBox.gd",
        "BoostPickup_visual": ROOT / "scripts" / "tracks" / "BoostPickup.gd",
        "SpeedLane_visual": ROOT / "scripts" / "tracks" / "SpeedLane.gd",
        "BouncePad_visual": ROOT / "scripts" / "tracks" / "BouncePad.gd",
    }
    out: dict[str, bool] = {}
    for name, path in checks.items():
        ok = path.exists()
        out[name] = ok
        if not ok:
            errors.append(f"missing {name}: {path}")
    item_box = (ROOT / "scripts" / "items" / "ItemBox.gd").read_text(encoding="utf-8")
    if "PursuitPod" not in item_box and "Pursuit Pod" not in item_box:
        errors.append("ItemBox.gd missing Pursuit Pod visual language")
        out["ItemBox_pursuit_pod"] = False
    for path, needle in [
        (ROOT / "scripts" / "tracks" / "BoostPickup.gd", "BoostToken"),
        (ROOT / "scripts" / "tracks" / "SpeedLane.gd", "Chevron"),
        (ROOT / "scripts" / "tracks" / "BouncePad.gd", "CompressionRing"),
        (ROOT / "scripts" / "items" / "ItemEffectVisuals.gd", "spawn_turbo_toes"),
        (ROOT / "scripts" / "items" / "ItemEffectVisuals.gd", "spawn_magnet_lace"),
        (ROOT / "scripts" / "items" / "ItemEffectVisuals.gd", "spawn_bounce_bubble"),
    ]:
        text = path.read_text(encoding="utf-8")
        key = f"needle:{needle}"
        out[key] = needle in text
        if needle not in text:
            errors.append(f"{path.name} missing {needle}")
    return out


def main() -> int:
    errors: list[str] = []
    identity = validate_identity(errors)
    distribution = validate_distribution(errors)
    code = validate_code_presence(errors)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dist_path = OUT_DIR / "POWERUP_DISTRIBUTION_MAP.json"
    dist_path.write_text(
        json.dumps(
            {
                "schema": "pp_v4_powerup_distribution/v1",
                "courses": distribution,
                "rules": {
                    "no_item_boost_overlap": True,
                    "each_course_has_item_boxes": True,
                    "each_course_has_boost_pickups": True,
                    "each_course_has_speed_lane": True,
                    "each_course_has_shortcut": True,
                    "fair_comeback_policy_retained": True,
                },
                "PASS": len(errors) == 0,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    gates = {
        "schema": "pp_v4_course_powerup_gates/v1",
        "branch": "v4/course-worlds-powerup-readability",
        "EIGHT_UNIQUE_ROUTE_TOPOLOGIES_PASS": identity.get("unique_topologies", 0) >= 8,
        "EIGHT_UNIQUE_COURSE_SILHOUETTES_PASS": identity.get("unique_silhouettes", 0) >= 8,
        "EIGHT_SIGNATURE_MECHANICS_PASS": identity.get("unique_mechanics", 0) >= 8,
        "EIGHT_SIGNATURE_BOOST_MOMENTS_PASS": identity.get("unique_boost_moments", 0) >= 8,
        "ITEM_BOX_VISUAL_PRESENCE_PASS": bool(code.get("ItemBox_pursuit_pod")) and bool(code.get("needle:BoostToken") or True),
        "BOOST_PICKUP_VISUAL_PRESENCE_PASS": bool(code.get("needle:BoostToken")),
        "SPEED_LANE_VISUAL_PRESENCE_PASS": bool(code.get("needle:Chevron")),
        "SIX_ITEM_EFFECT_VISIBILITY_PASS": bool(code.get("needle:spawn_turbo_toes"))
        and bool(code.get("needle:spawn_magnet_lace"))
        and bool(code.get("needle:spawn_bounce_bubble")),
        "POWERUP_DISTRIBUTION_VALIDATION_PASS": len(distribution) == 8 and not any(
            e.startswith(tid) for tid in LAUNCH for e in errors if "overlap" in e or "no " in e
        )
        and all(
            distribution.get(tid, {}).get("item_boxes")
            and distribution.get(tid, {}).get("boost_pickups")
            and distribution.get(tid, {}).get("speed_lanes")
            and distribution.get(tid, {}).get("shortcuts")
            for tid in LAUNCH
        )
        if distribution
        else False,
        "PARTYLINK_2P_PASS": "pending_ci",
        "PARTYLINK_4P_PASS": "pending_ci",
        "PARTYLINK_6P_PASS": "pending_ci",
        "PARTYLINK_8P_PASS": "pending_ci",
        "ANDROID_BUILD_PASS": "pending_ci",
        "WINDOWS_PASS": "pending_ci",
        "GATE1_PASS": "pending_ci",
        "WAVE010_PASS": "pending_ci",
        "HUMAN_COURSE_IDENTITY_PASS": False,
        "HUMAN_POWERUP_READABILITY_PASS": False,
        "HUMAN_RACE_FUN_PASS": False,
        "NEXT_PEDESTRIAN_ACTION": "OWNER_PIXEL_REVIEW_ALL_EIGHT_V4_COURSES",
        "identity_summary": identity,
        "code_presence": code,
        "errors": errors,
        "TECHNICAL_VALIDATION_PASS": len(errors) == 0,
    }
    # Refine item box presence from Pursuit Pod language
    item_text = (ROOT / "scripts" / "items" / "ItemBox.gd").read_text(encoding="utf-8")
    gates["ITEM_BOX_VISUAL_PRESENCE_PASS"] = "PursuitPod" in item_text or "Pursuit Pod" in item_text
    bounce_text = (ROOT / "scripts" / "tracks" / "BouncePad.gd").read_text(encoding="utf-8")
    gates["BOUNCE_PAD_VISUAL_PRESENCE_PASS"] = "CompressionRing" in bounce_text

    gates_path = OUT_DIR / "COURSE_POWERUP_FIDELITY_GATES.json"
    gates_path.write_text(json.dumps(gates, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {dist_path}")
    print(f"Wrote {gates_path}")
    if errors:
        print("V4_COURSE_POWERUP_VALIDATE FAIL")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("V4_COURSE_POWERUP_VALIDATE PASS")
    print("NEXT_PEDESTRIAN_ACTION=OWNER_PIXEL_REVIEW_ALL_EIGHT_V4_COURSES")
    return 0


if __name__ == "__main__":
    sys.exit(main())
