#!/usr/bin/env python3
"""Validate championship catalog: 8 cups × 4 = 32 raceable courses, shoes, items, device roles."""

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
CHAMPIONSHIP_TRACK_TARGET = 32
CHAMPIONSHIP_CUP_TARGET = 8
KNOWN_CUPS = (
    "sole_surge_cup",
    "stride_circuit_cup",
    "metro_motion_cup",
    "kinetic_coast_cup",
    "neon_night_cup",
    "skyline_relay_cup",
    "archive_relay_cup",
    "world_wonder_grand_prix",
)
LAUNCH_TRACKS = (
    "verdant_cascade_circuit",
    "cloverwind_ranch",
    "prism_apex",
    "emberkeep_gauntlet",
    "tideglass_harbor",
    "neon_switchyard",
    "cloudstep_ridge",
    "mirage_mesa",
)
RACEABLE_ART = (
    "LAUNCH_PROCEDURAL_FINAL",
    "CHAMPIONSHIP_PROCEDURAL_RACEABLE",
)
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
    if len(KNOWN_CUPS) != CHAMPIONSHIP_CUP_TARGET:
        errors.append(f"championship needs {CHAMPIONSHIP_CUP_TARGET} cups, got {len(KNOWN_CUPS)}")
    if len(unique_tracks) != CHAMPIONSHIP_TRACK_TARGET:
        errors.append(
            f"championship catalog has {len(unique_tracks)} unique cup tracks; need {CHAMPIONSHIP_TRACK_TARGET}"
        )
    if len(unique_tracks) < LAUNCH_TRACK_TARGET:
        errors.append(
            f"launch catalog has {len(unique_tracks)} unique cup tracks; need ≥{LAUNCH_TRACK_TARGET}"
        )
    for launch_id in LAUNCH_TRACKS:
        if launch_id not in unique_tracks:
            errors.append(f"missing preserved launch track {launch_id}")

    for shoe_id in EXPECTED_SHOES:
        shoe_path = root / f"data/shoes/{shoe_id}.json"
        shoe = _read_json(shoe_path, errors)
        if shoe and shoe.get("id") != shoe_id:
            errors.append(f"{shoe_path}: id mismatch")
        if shoe:
            if "material_family" not in shoe:
                errors.append(f"{shoe_path}: missing material_family")
            affinities = shoe.get("surface_affinities")
            if not isinstance(affinities, dict) or len(affinities) < 6:
                errors.append(f"{shoe_path}: surface_affinities must cover launch surfaces")

    errors.extend(_validate_vehicle_registry(root))
    errors.extend(_validate_art_acceptance(root))
    errors.extend(_validate_wardrobe(root))

    expected_runners = (
        "dash_reed",
        "nova_quill",
        "sierra_flux",
        "mira_lane",
        "bolt_harbor",
        "zig_riven",
        "solen_pike",
        "kai_volt",
    )
    for runner_id in expected_runners:
        runner_path = root / f"data/racers/{runner_id}.json"
        runner = _read_json(runner_path, errors)
        if not runner:
            continue
        if runner.get("id") != runner_id:
            errors.append(f"{runner_path}: id mismatch")
        for key in ("top_speed", "acceleration", "handling", "drift_control"):
            if key not in runner:
                errors.append(f"{runner_path}: missing gameplay stat {key}")

    art_inv = root / "data/art/LAUNCH_ART_INVENTORY.json"
    art = _read_json(art_inv, errors)
    if art and art.get("status") != "LAUNCH_PROCEDURAL_FINAL":
        errors.append(f"{art_inv}: status must be LAUNCH_PROCEDURAL_FINAL for digital RC")
    if art and len(art.get("tracks", [])) < 8:
        errors.append(f"{art_inv}: need ≥8 launch inventory tracks")
    provenance = root / "data/art/provenance.json"
    prov = _read_json(provenance, errors)
    if prov and int(prov.get("counts", {}).get("racers", 0)) < 8:
        errors.append(f"{provenance}: racer art count < 8")
    audio_manifest = root / "gate1/evidence/visual_qa/audio_bank_manifest.json"
    audio = _read_json(audio_manifest, errors)
    if audio and int(audio.get("count", 0)) < 20:
        errors.append(f"{audio_manifest}: procedural audio bank incomplete")
    for sheet in (
        "racers_contact_sheet.png",
        "footwear_contact_sheet.png",
        "items_contact_sheet.png",
        "tracks_contact_sheet.png",
        "ui_contact_sheet.png",
        "vfx_contact_sheet.png",
    ):
        if not (root / "gate1/evidence/visual_qa" / sheet).exists():
            errors.append(f"missing visual QA contact sheet: {sheet}")
    for profile_id in ("keyboard_default", "gamepad_default", "touch_assist", "local_mp_split"):
        if not (root / f"data/input_profiles/{profile_id}.json").exists():
            errors.append(f"missing input profile {profile_id}")
    # Cups 1–2 launch eight remain LAUNCH_PROCEDURAL_FINAL; championship tracks are raceable procedural.
    for track_id in LAUNCH_TRACKS:
        track_path = root / f"data/tracks/{track_id}.json"
        track = _read_json(track_path, errors)
        if track and track.get("art_status") == "REQUIRES_ART_PRODUCTION":
            errors.append(f"{track_path}: launch art_status must not remain REQUIRES_ART_PRODUCTION")
        if track and track.get("art_status") != "LAUNCH_PROCEDURAL_FINAL":
            errors.append(f"{track_path}: expected LAUNCH_PROCEDURAL_FINAL")
    for track_id in unique_tracks:
        track_path = root / f"data/tracks/{track_id}.json"
        track = _read_json(track_path, errors)
        if not track:
            continue
        if track.get("art_status") not in RACEABLE_ART:
            errors.append(f"{track_path}: art_status must be raceable procedural ({track.get('art_status')})")
        if track.get("art_status") == "REQUIRES_ART_PRODUCTION":
            errors.append(f"{track_path}: greybox REQUIRES_ART_PRODUCTION not allowed in championship")
        if bool(track.get("human_track_art_approved", False)):
            errors.append(f"{track_path}: human track art must stay unapproved")
    track_art_path = root / "data/art/track_art_acceptance.json"
    track_art = _read_json(track_art_path, errors)
    if track_art:
        if track_art.get("HUMAN_FUN_APPROVAL") or track_art.get("HUMAN_COURSE_APPROVAL"):
            errors.append(f"{track_art_path}: human approvals must stay false")
        if track_art.get("RC2_READY") or track_art.get("V1_0_0_RELEASE_AUTHORIZED"):
            errors.append(f"{track_art_path}: RC2/V1 must stay false")
        if len(track_art.get("tracks", [])) != CHAMPIONSHIP_TRACK_TARGET:
            errors.append(f"{track_art_path}: need {CHAMPIONSHIP_TRACK_TARGET} track art entries")

    grammar = root / "data/mechanics/foot_racing_grammar.json"
    gram = _read_json(grammar, errors)
    if gram and len(gram.get("mechanics", [])) < 10:
        errors.append(f"{grammar}: need full foot-racing grammar (≥10 mechanics)")

    challenges = root / "data/challenges/launch_challenges.json"
    ch = _read_json(challenges, errors)
    if ch and len(ch.get("challenges", [])) < 5:
        errors.append(f"{challenges}: need launch challenge set")

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


def _validate_vehicle_registry(root: Path) -> list[str]:
    """Kinetic Sole garage: exactly 50 playable IDs; tribute art may be procedural_final_for_garage."""
    errors: list[str] = []
    path = root / "data/vehicles/vehicle_registry.json"
    reg = _read_json(path, errors)
    if not reg:
        return errors
    vehicles = reg.get("vehicles")
    if not isinstance(vehicles, list):
        errors.append(f"{path}: vehicles must be a list")
        return errors
    if len(vehicles) != 50:
        errors.append(f"{path}: expected 50 vehicles, found {len(vehicles)}")
    ids: list[str] = []
    playable = 0
    stub = 0
    playable_art = {"native_v1", "procedural_final_for_garage"}
    required_fields = (
        "id",
        "display_name",
        "family_id",
        "movement_archetype",
        "playable",
        "art_status",
        "top_speed_modifier",
        "acceleration_modifier",
        "handling_modifier",
        "surface_affinities",
        "collision_contract",
    )
    for entry in vehicles:
        if not isinstance(entry, dict):
            errors.append(f"{path}: vehicle entry must be an object")
            continue
        for key in required_fields:
            if key not in entry:
                errors.append(f"{path}: vehicle missing {key}")
        vid = str(entry.get("id", ""))
        if not SAFE_ID.match(vid):
            errors.append(f"{path}: invalid vehicle id {vid!r}")
        ids.append(vid)
        if bool(entry.get("playable", False)):
            playable += 1
            art = str(entry.get("art_status", ""))
            if art not in playable_art:
                errors.append(f"{path}: playable {vid} art_status must be one of {sorted(playable_art)}")
            if art == "stub_not_final":
                errors.append(f"{path}: playable {vid} must not remain stub_not_final")
            shoe_path = root / f"data/shoes/{vid}.json"
            if not shoe_path.exists():
                errors.append(f"{path}: playable {vid} missing shoe JSON {shoe_path.name}")
        else:
            stub += 1
            if str(entry.get("art_status", "")) != "stub_not_final":
                errors.append(f"{path}: stub {vid} must flag art_status stub_not_final")
        affinities = entry.get("surface_affinities")
        if not isinstance(affinities, dict) or len(affinities) < 6:
            errors.append(f"{path}: {vid} surface_affinities incomplete")
        contract = str(entry.get("collision_contract", "")).lower()
        if "checkpoint" not in contract and "collision" not in contract:
            errors.append(f"{path}: {vid} collision_contract must mention grounded collision/checkpoints")
    if len(ids) != len(set(ids)):
        errors.append(f"{path}: duplicate vehicle ids")
    if playable != 50:
        errors.append(f"{path}: need exactly 50 playable Kinetic Sole vehicles, found {playable}")
    if stub != 0:
        errors.append(f"{path}: need 0 stubs, found {stub}")
    if stub + playable != len(vehicles):
        errors.append(f"{path}: playable/stub accounting mismatch")
    if int(reg.get("vehicle_count", -1)) != 50:
        errors.append(f"{path}: vehicle_count must be 50")
    if int(reg.get("playable_count", -1)) != 50:
        errors.append(f"{path}: playable_count must be 50")
    if int(reg.get("stub_count", -1)) != 0:
        errors.append(f"{path}: stub_count must be 0")
    street = [v for v in vehicles if isinstance(v, dict) and v.get("family_id") == "street_legends"]
    if len(street) != 8:
        errors.append(f"{path}: Street Legends family must have 8 vehicles")
    if not all(bool(v.get("playable")) for v in street):
        errors.append(f"{path}: all Street Legends must be playable")
    for family_id, label, expect in (
        ("roller_revolution", "Roller Revolution", 7),
        ("hover_couture", "Hover Couture / Spaceflight", 7),
        ("elemental_amphibious", "Elemental / Amphibious", 6),
        ("beautifully_ridiculous", "Beautifully Ridiculous", 6),
        ("gunnchos_crossover", "gunnchOS3k Crossover", 7),
        ("anime_aggressors", "Anime Aggressors Footwear (Pedestrian tribute)", 9),
    ):
        family = [v for v in vehicles if isinstance(v, dict) and v.get("family_id") == family_id]
        if len(family) != expect:
            errors.append(f"{path}: {label} family must have {expect} vehicles")
        if not all(bool(v.get("playable")) for v in family):
            errors.append(f"{path}: all {label} vehicles must be playable")
        fps: set[tuple] = set()
        for v in family:
            if family_id in (
                "hover_couture",
                "elemental_amphibious",
                "beautifully_ridiculous",
                "gunnchos_crossover",
                "anime_aggressors",
            ):
                contract = str(v.get("collision_contract", "")).lower()
                if "grounded" not in contract and "checkpoint" not in contract:
                    errors.append(f"{path}: {family_id} {v.get('id')} missing grounded collision contract")
            if family_id == "anime_aggressors":
                ## Garage-only procedural OR promoted native_v1 candidate — never commercial.
                art = str(v.get("art_status", ""))
                if art not in ("procedural_final_for_garage", "native_v1"):
                    errors.append(
                        f"{path}: tribute {v.get('id')} art_status must be procedural_final_for_garage or native_v1"
                    )
                if bool(v.get("human_commercial_art_approved", False)):
                    errors.append(f"{path}: tribute {v.get('id')} commercial art must stay false")
                arch = str(v.get("movement_archetype", ""))
                if not arch.startswith("tribute_"):
                    errors.append(f"{path}: tribute {v.get('id')} archetype must be tribute_* (got {arch})")
            fp = (
                float(v.get("top_speed_modifier", 0)),
                float(v.get("acceleration_modifier", 0)),
                float(v.get("handling_modifier", 0)),
                float(v.get("drift_modifier", 0)),
                float(v.get("jump_modifier", 0)),
                float(v.get("boost_modifier", 0)),
                float(v.get("stomp_modifier", 0)),
                str(v.get("material_family", "")),
            )
            if fp in fps:
                errors.append(f"{path}: duplicate {label} fingerprint for {v.get('id')}")
            fps.add(fp)
    modes: dict[str, int] = {}
    for v in vehicles:
        if not isinstance(v, dict):
            continue
        unlock = v.get("unlock") if isinstance(v.get("unlock"), dict) else {}
        mode = str(unlock.get("mode", "starter"))
        modes[mode] = modes.get(mode, 0) + 1
    if modes.get("starter", 0) >= 50:
        errors.append(f"{path}: unlock modes must not leave all 50 as starter")
    for need in ("cup", "challenge", "achievement", "crossover"):
        if modes.get(need, 0) < 1:
            errors.append(f"{path}: missing unlock mode {need}")
    return errors


def _validate_art_acceptance(root: Path) -> list[str]:
    errors: list[str] = []
    path = root / "data/art/vehicle_art_acceptance.json"
    doc = _read_json(path, errors)
    if not doc:
        return errors
    if doc.get("human_commercial_art_gate") is not False:
        errors.append(f"{path}: human_commercial_art_gate must be false")
    if doc.get("HUMAN_FUN_APPROVAL") is not False:
        errors.append(f"{path}: HUMAN_FUN_APPROVAL must remain false")
    if doc.get("HUMAN_COURSE_APPROVAL") is not False:
        errors.append(f"{path}: HUMAN_COURSE_APPROVAL must remain false")
    vehicles = doc.get("vehicles")
    if not isinstance(vehicles, list) or len(vehicles) != 50:
        errors.append(f"{path}: expected 50 art-acceptance entries")
        return errors
    pending = 0
    candidate = 0
    for entry in vehicles:
        if not isinstance(entry, dict):
            errors.append(f"{path}: entry must be object")
            continue
        if entry.get("runtime_status") != "playable_runtime":
            errors.append(f"{path}: {entry.get('id')} runtime_status must be playable_runtime")
        fas = str(entry.get("final_art_status", ""))
        if fas not in ("final_art_pending", "final_art_candidate"):
            errors.append(f"{path}: {entry.get('id')} invalid final_art_status {fas}")
        if entry.get("human_commercial_art_approved"):
            errors.append(f"{path}: {entry.get('id')} must not claim commercial art approval")
        if fas == "final_art_pending":
            pending += 1
        elif fas == "final_art_candidate":
            candidate += 1
    ## All 50 may be candidates; pending may be 0. Commercial approvals stay false.
    if candidate < 1:
        errors.append(f"{path}: need at least one final_art_candidate")
    if pending + candidate != 50:
        errors.append(f"{path}: pending+candidate must equal 50 (got {pending}+{candidate})")
    counts = doc.get("counts") if isinstance(doc.get("counts"), dict) else {}
    if int(counts.get("final_art_candidate", -1)) != candidate:
        errors.append(f"{path}: counts.final_art_candidate mismatch")
    if int(counts.get("final_art_pending", -1)) != pending:
        errors.append(f"{path}: counts.final_art_pending mismatch")
    return errors


def _validate_wardrobe(root: Path) -> list[str]:
    errors: list[str] = []
    path = root / "data/wardrobe/wardrobe_catalog.json"
    doc = _read_json(path, errors)
    if not doc:
        return errors
    slots = doc.get("slots")
    if not isinstance(slots, list) or "footwear_vehicle" not in slots or "top" not in slots:
        errors.append(f"{path}: wardrobe slots incomplete")
    garments = doc.get("garments")
    if not isinstance(garments, list) or len(garments) < 20:
        errors.append(f"{path}: need multi-family integrated garments")
        return errors
    integrated = [g for g in garments if isinstance(g, dict) and g.get("art_status") == "integrated_mesh_v1"]
    pending = [g for g in garments if isinstance(g, dict) and g.get("art_status") == "catalog_art_pending"]
    if len(integrated) < 40:
        errors.append(f"{path}: need ≥40 integrated_mesh_v1 garments across families")
    ## Honest pending may be zero once Crosswind Kiln + Archive Loom are integrated.
    if pending:
        for g in pending:
            if not bool(g.get("cosmetic_only", True)):
                errors.append(f"{path}: pending garment {g.get('id')} must stay cosmetic_only")
    families = {
        str(f.get("id"))
        for f in doc.get("families", [])
        if isinstance(f, dict)
    }
    for need in (
        "metro_pulse",
        "harbor_linen",
        "neon_trackside",
        "quiet_plaza",
        "midnight_atelier",
        "myth_circuit",
        "orbit_signal",
        "crosswind_kiln",
        "archive_loom",
    ):
        if need not in families:
            errors.append(f"{path}: missing wardrobe family {need}")
    fam_status = {
        str(f.get("id")): str(f.get("art_status", ""))
        for f in doc.get("families", [])
        if isinstance(f, dict)
    }
    for need in ("crosswind_kiln", "archive_loom"):
        if fam_status.get(need) != "integrated_mesh_v1":
            errors.append(f"{path}: {need} must be integrated_mesh_v1")
    presets = doc.get("presets")
    if not isinstance(presets, list) or len(presets) < 5:
        errors.append(f"{path}: need ≥5 complete outfit presets")
    if not isinstance(presets, list) or not any(
        isinstance(p, dict) and p.get("id") == "metro_pulse_default" for p in presets
    ):
        errors.append(f"{path}: metro_pulse_default preset required")
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
        "Validated championship catalog: 8 cups, 32 unique courses, "
        "4 legacy footwear + 50-vehicle Kinetic Sole garage, 6 items, 8 runners w/ stats, "
        "grammar, challenges, art inventory."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
