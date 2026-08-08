#!/usr/bin/env python3
"""Validate launch catalog: ≥2 cups, 8 unique courses, shoes, items, device roles."""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path
from typing import Any

SAFE_ID = re.compile(r"^[a-z0-9_]+$")
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
CUP_TRACK_COUNT = 4
LAUNCH_TRACK_TARGET = 8
KNOWN_CUPS = ("sole_surge_cup", "stride_circuit_cup")
FEATURE_COLLECTIONS = ("speed_lanes", "terrain_zones", "bounce_pads")
INDEX_COLLECTIONS = ("item_boxes", "boost_pickups", "rail_segments")
EXPECTED_SHOES = ("starter_soles", "speed_sneakers", "grip_soles", "bounce_boots")
EXPECTED_ITEMS = (
    "turbo_toes",
    "lace_trap",
    "sole_shield",
    "pulse_horn",
    "magnet_lace",
    "bounce_bubble",
)


def _read_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path}: top-level JSON value must be an object")
        return {}
    return value


def _distance(a: list[float], b: list[float]) -> float:
    return math.sqrt(sum((float(left) - float(right)) ** 2 for left, right in zip(a, b)))


def _orientation(a: list[float], b: list[float], c: list[float]) -> float:
    return (float(b[0]) - float(a[0])) * (float(c[2]) - float(a[2])) - (
        float(b[2]) - float(a[2])
    ) * (float(c[0]) - float(a[0]))


def _segments_cross(a: list[float], b: list[float], c: list[float], d: list[float]) -> bool:
    return _orientation(a, b, c) * _orientation(a, b, d) < 0 and _orientation(c, d, a) * _orientation(c, d, b) < 0


def _validate_track(path: Path, track: dict[str, Any], errors: list[str]) -> None:
    if track.get("schema_version") != 1:
        errors.append(f"{path}: unsupported schema_version")
    if not isinstance(track.get("lap_count"), int) or not 1 <= track["lap_count"] <= 9:
        errors.append(f"{path}: lap_count must be an integer from 1 through 9")
    lane_width = track.get("lane_width")
    if not isinstance(lane_width, (int, float)) or not 8 <= lane_width <= 24:
        errors.append(f"{path}: lane_width must be between 8 and 24")
    for color_key in ("track_color", "accent_color", "sky_color", "backdrop_color"):
        if not isinstance(track.get(color_key), str) or not HEX_COLOR.fullmatch(track[color_key]):
            errors.append(f"{path}: {color_key} must be a #RRGGBB color")

    route = track.get("path_points")
    if not isinstance(route, list) or len(route) < 6:
        errors.append(f"{path}: path_points must contain at least six entries")
        return
    if any(not isinstance(point, list) or len(point) != 3 for point in route):
        errors.append(f"{path}: every path point must contain three coordinates")
        return
    for index, point in enumerate(route):
        following = route[(index + 1) % len(route)]
        if _distance(point, following) < float(lane_width):
            errors.append(f"{path}: route segment {index} is shorter than lane_width")
    for left_index in range(len(route)):
        for right_index in range(left_index + 1, len(route)):
            if right_index == (left_index + 1) % len(route) or left_index == (right_index + 1) % len(route):
                continue
            if _segments_cross(
                route[left_index],
                route[(left_index + 1) % len(route)],
                route[right_index],
                route[(right_index + 1) % len(route)],
            ):
                errors.append(f"{path}: route segments {left_index} and {right_index} cross")

    checkpoints = track.get("checkpoint_points")
    if not isinstance(checkpoints, list) or len(checkpoints) < 4:
        errors.append(f"{path}: checkpoint_points must have at least four entries")
    elif checkpoints[0] != 0 or checkpoints != sorted(set(checkpoints)):
        errors.append(f"{path}: checkpoint_points must start at zero and strictly increase")
    else:
        for index in checkpoints:
            if not isinstance(index, int) or not 0 <= index < len(route):
                errors.append(f"{path}: checkpoint index {index!r} is out of range")

    for collection_name in FEATURE_COLLECTIONS:
        collection = track.get(collection_name, [])
        if not isinstance(collection, list):
            errors.append(f"{path}: {collection_name} must be a list")
            continue
        for feature in collection:
            if not isinstance(feature, dict) or not isinstance(feature.get("point_index"), int):
                errors.append(f"{path}: malformed {collection_name} entry")
            elif not 0 <= feature["point_index"] < len(route):
                errors.append(f"{path}: {collection_name} index is out of range")
    for collection_name in INDEX_COLLECTIONS:
        collection = track.get(collection_name, [])
        if collection_name == "rail_segments" and collection == []:
            continue
        if not isinstance(collection, list) or any(
            not isinstance(index, int) or not 0 <= index < len(route) for index in collection
        ):
            if collection_name == "rail_segments" and not isinstance(collection, list):
                errors.append(f"{path}: {collection_name} must be a list")
            elif collection_name != "rail_segments":
                errors.append(f"{path}: {collection_name} must contain valid route indices")
            elif any(not isinstance(index, int) or not 0 <= index < len(route) for index in collection):
                errors.append(f"{path}: {collection_name} must contain valid route indices")

    for shortcut in track.get("shortcut_routes", []):
        if not isinstance(shortcut, dict):
            errors.append(f"{path}: shortcut_routes entries must be objects")
            continue
        for key in ("entry_point_index", "exit_point_index"):
            idx = shortcut.get(key)
            if not isinstance(idx, int) or not 0 <= idx < len(route):
                errors.append(f"{path}: shortcut {key} out of range")


def validate_project(root: Path) -> list[str]:
    errors: list[str] = []
    all_track_ids: list[str] = []

    for cup_id in KNOWN_CUPS:
        cup_path = root / f"data/cups/{cup_id}.json"
        cup = _read_json(cup_path, errors)
        if not cup:
            continue
        track_ids = cup.get("track_ids")
        if not isinstance(track_ids, list) or len(track_ids) != CUP_TRACK_COUNT:
            errors.append(f"{cup_path}: track_ids must contain exactly {CUP_TRACK_COUNT} entries")
            continue
        if len(set(track_ids)) != len(track_ids):
            errors.append(f"{cup_path}: track_ids must be unique")
        points = cup.get("points_by_position")
        if not isinstance(points, list) or not points or points != sorted(points, reverse=True):
            errors.append(f"{cup_path}: points_by_position must be a non-empty descending list")

        for expected_id in track_ids:
            if not isinstance(expected_id, str) or not SAFE_ID.fullmatch(expected_id):
                errors.append(f"{cup_path}: invalid track id {expected_id!r}")
                continue
            all_track_ids.append(expected_id)
            path = root / f"data/tracks/{expected_id}.json"
            track = _read_json(path, errors)
            if not track:
                continue
            if track.get("id") != expected_id:
                errors.append(f"{path}: id must match its cup reference")
            _validate_track(path, track, errors)

    unique_tracks = sorted(set(all_track_ids))
    if len(unique_tracks) < LAUNCH_TRACK_TARGET:
        errors.append(
            f"launch catalog has {len(unique_tracks)} unique cup tracks; need ≥{LAUNCH_TRACK_TARGET}"
        )

    for shoe_id in EXPECTED_SHOES:
        shoe_path = root / f"data/shoes/{shoe_id}.json"
        shoe = _read_json(shoe_path, errors)
        if shoe and shoe.get("id") != shoe_id:
            errors.append(f"{shoe_path}: id mismatch")

    for item_id in EXPECTED_ITEMS:
        item_path = root / f"data/items/{item_id}.json"
        item = _read_json(item_path, errors)
        if not item:
            continue
        if item.get("id") != item_id:
            errors.append(f"{item_path}: id mismatch")
        if "counterplay" not in item:
            errors.append(f"{item_path}: missing counterplay field")
        if "warning_seconds" not in item:
            errors.append(f"{item_path}: missing warning_seconds field")

    roster_path = root / "data/racers/runner_roster.json"
    roster = _read_json(roster_path, errors)
    runners = roster.get("runners", []) if roster else []
    if not isinstance(runners, list) or len(runners) < 8:
        errors.append(f"{roster_path}: need ≥8 runners for Alpha launch scope")

    errors.extend(_validate_device_roles(root))
    return errors


def _validate_device_roles(root: Path) -> list[str]:
    errors: list[str] = []
    catalog_path = root / "device_ux/profiles/device_roles.json"
    catalog = _read_json(catalog_path, errors)
    if not catalog:
        return errors
    expected_roles = ("student_14_5", "handheld_hybrid", "ds_xl_coder", "edge_io_rings")
    roles = catalog.get("roles")
    if not isinstance(roles, dict):
        errors.append(f"{catalog_path}: roles must be an object")
        return errors
    for role_id in expected_roles:
        if role_id not in roles:
            errors.append(f"{catalog_path}: missing role {role_id}")
            continue
        role = roles[role_id]
        if not isinstance(role, dict):
            errors.append(f"{catalog_path}: role {role_id} must be an object")
            continue
        gps = str(role.get("gps_mode", "")).upper()
        if gps not in {"SIMULATED", "NONE"}:
            errors.append(f"{catalog_path}: role {role_id} gps_mode must be SIMULATED or none")
        if not isinstance(role.get("input_default"), str) or not role["input_default"]:
            errors.append(f"{catalog_path}: role {role_id} needs input_default")
        map_id = role.get("map_profile")
        maps = catalog.get("map_profiles", {})
        if not isinstance(maps, dict) or map_id not in maps:
            errors.append(f"{catalog_path}: role {role_id} map_profile {map_id!r} missing")
    if catalog.get("game_id") != "pedestrian-pursuit":
        errors.append(f"{catalog_path}: game_id must be pedestrian-pursuit")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate_project(root)
    if errors:
        print("Content validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        "Validated Wave E Alpha catalog: 2 cups, 8 unique courses, "
        "4 footwear, 6 items w/ counterplay, 8 runners, 4 device roles."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
