#!/usr/bin/env python3
"""Fail unless every launch course log shows a real finished race.

Exit 0 from Godot is not acceptance. A course passes only when its own
block records RACE_ENTERED, CHECKPOINT_CROSSED, LAP_COMPLETED, and
RESULTS_PATH as true. COURSE_ACCEPTED=true and RACE_SCENE_FAIL fail that
course. A later course cannot turn an earlier failure into a pass.
"""

from __future__ import annotations

import sys
from pathlib import Path


OBSERVED_KEYS = (
    "RACE_ENTERED",
    "LAP_COMPLETED",
    "CHECKPOINT_CROSSED",
    "RESULTS_PATH",
    "COURSE_ACCEPTED",
    "DEVICE_RUN",
)

REQUIRED_TRUE = (
    "RACE_ENTERED",
    "CHECKPOINT_CROSSED",
    "LAP_COMPLETED",
    "RESULTS_PATH",
)

# Verdant first, then the other seven launch courses. Order is the observer order.
LAUNCH_COURSE_IDS = (
    "verdant_cascade_circuit",
    "cloverwind_ranch",
    "prism_apex",
    "emberkeep_gauntlet",
    "tideglass_harbor",
    "neon_switchyard",
    "cloudstep_ridge",
    "mirage_mesa",
)

# Cup 3 Metro Motion — first cups 3–8 full-race observer expansion.
CUP3_COURSE_IDS = (
    "sneaker_city_sprintway",
    "metro_pulse_loop",
    "crosswalk_canyon",
    "transit_spiral",
)

# Cup 4 Kinetic Coast.
CUP4_COURSE_IDS = (
    "saltline_boardwalk",
    "cliffside_draft",
    "tidal_bridge_run",
    "seaglass_switchback",
)

# Cup 5 Neon Night.
CUP5_COURSE_IDS = (
    "lantern_corridor",
    "mirror_boulevard",
    "afterglow_overpass",
    "signal_storm_yard",
)

# Cup 6 Skyline Relay.
CUP6_COURSE_IDS = (
    "rooftop_ribbon",
    "skybridge_sprint",
    "antenna_ascent",
    "cloud_deck_circuit",
)

# Cup 7 Archive Relay.
CUP7_COURSE_IDS = (
    "marble_foyer_loop",
    "stack_corridor",
    "gallery_grand_oval",
    "vault_gate_gauntlet",
)

# Cup 8 World Wonder Grand Prix.
CUP8_COURSE_IDS = (
    "cascade_colossus",
    "aurora_amphitheater",
    "origami_orchard",
    "horizon_crown_finale",
)

CUPS4_8_COURSE_IDS = (
    CUP4_COURSE_IDS
    + CUP5_COURSE_IDS
    + CUP6_COURSE_IDS
    + CUP7_COURSE_IDS
    + CUP8_COURSE_IDS
)

CUPS3_8_COURSE_IDS = CUP3_COURSE_IDS + CUPS4_8_COURSE_IDS

SUITE_COURSES = {
    "launch": LAUNCH_COURSE_IDS,
    "cup3": CUP3_COURSE_IDS,
    "cup4": CUP4_COURSE_IDS,
    "cup5": CUP5_COURSE_IDS,
    "cup6": CUP6_COURSE_IDS,
    "cup7": CUP7_COURSE_IDS,
    "cup8": CUP8_COURSE_IDS,
    "cups4-8": CUPS4_8_COURSE_IDS,
    "cups3-8": CUPS3_8_COURSE_IDS,
    "cups1-3": LAUNCH_COURSE_IDS + CUP3_COURSE_IDS,
}


def parse_observer_log(text: str) -> dict[str, str | None]:
    """Last assignment wins. Absent keys stay None. Do not invent values."""
    found: dict[str, str | None] = {key: None for key in OBSERVED_KEYS}
    found["RACE_SCENE_FAIL"] = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("RACE_SCENE_FAIL"):
            reason = line[len("RACE_SCENE_FAIL") :].strip()
            found["RACE_SCENE_FAIL"] = reason if reason else "present"
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in found:
            found[key] = value.strip()
    return found


def acceptance_failure(fields: dict[str, str | None]) -> str | None:
    """Return a failure reason, or None when the three observations are real."""
    if fields.get("RACE_SCENE_FAIL"):
        return "RACE_SCENE_FAIL %s" % fields["RACE_SCENE_FAIL"]
    if fields.get("COURSE_ACCEPTED") == "true":
        return "COURSE_ACCEPTED=true is not a runtime lap"
    missing = [key for key in REQUIRED_TRUE if fields.get(key) is None]
    if missing:
        return "absent " + ",".join(missing)
    false_keys = [key for key in REQUIRED_TRUE if fields.get(key) != "true"]
    if false_keys:
        return "not true " + ",".join(
            "%s=%s" % (key, fields.get(key)) for key in false_keys
        )
    return None


def _blank_block() -> dict[str, str | None]:
    fields: dict[str, str | None] = {key: None for key in OBSERVED_KEYS}
    fields["RACE_SCENE_FAIL"] = None
    fields["TRACK_ID"] = None
    fields["RACE_STATE"] = None
    fields["DRIVEN_MSEC"] = None
    fields["LAP_COUNT"] = None
    return fields


def parse_course_blocks(text: str) -> dict[str, dict[str, str | None]]:
    """Group COURSE_OBSERVE blocks by TRACK_ID. A later pass does not erase a fail."""
    blocks: dict[str, dict[str, str | None]] = {}
    current: dict[str, str | None] | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line == "COURSE_OBSERVE_BEGIN":
            current = _blank_block()
            continue
        if line == "COURSE_OBSERVE_END":
            if current is not None:
                _store_block(blocks, current)
            current = None
            continue
        if current is None:
            continue
        if line.startswith("RACE_SCENE_FAIL"):
            reason = line[len("RACE_SCENE_FAIL") :].strip()
            current["RACE_SCENE_FAIL"] = reason if reason else "present"
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in current or key in ("TRACK_ID", "RACE_STATE", "DRIVEN_MSEC", "LAP_COUNT"):
            current[key] = value.strip()
    if current is not None:
        _store_block(blocks, current)
    return blocks


def _store_block(
    blocks: dict[str, dict[str, str | None]],
    fields: dict[str, str | None],
) -> None:
    track_id = fields.get("TRACK_ID")
    if not track_id:
        return
    previous = blocks.get(track_id)
    if previous is None or acceptance_failure(previous) is None:
        if previous is not None and acceptance_failure(fields) is None:
            blocks[track_id] = previous
            return
        blocks[track_id] = fields
        return
    # Keep the recorded failure. A later pass must not replace it.


def evaluate_courses(
    text: str,
    course_ids: tuple[str, ...] | None = None,
) -> tuple[str, list[str]]:
    required = course_ids if course_ids is not None else LAUNCH_COURSE_IDS
    blocks = parse_course_blocks(text)
    failures: list[str] = []
    lines: list[str] = []
    for course_id in required:
        fields = blocks.get(course_id)
        if fields is None:
            failures.append(course_id)
            lines.append("COURSE_GATE %s=absent" % course_id)
            continue
        reason = acceptance_failure(fields)
        if reason:
            failures.append(course_id)
            lines.append("COURSE_GATE %s=fail %s" % (course_id, reason))
        else:
            lines.append("COURSE_GATE %s=pass" % course_id)
        for key in (
            "RACE_ENTERED",
            "CHECKPOINT_CROSSED",
            "LAP_COMPLETED",
            "RESULTS_PATH",
            "COURSE_ACCEPTED",
            "DEVICE_RUN",
            "RACE_STATE",
            "DRIVEN_MSEC",
            "LAP_COUNT",
        ):
            value = fields.get(key)
            lines.append("%s %s=%s" % (course_id, key, "absent" if value is None else value))
    header = ["RACE_ACCEPTANCE_GATE=%s" % ("fail" if failures else "pass")]
    if failures:
        header.append("RACE_ACCEPTANCE_FAIL " + ",".join(failures))
    else:
        header.append("RACE_ACCEPTANCE_FAIL none")
    return "\n".join(header + lines) + "\n", failures


def format_report(fields: dict[str, str | None], failure: str | None) -> str:
    lines = ["RACE_ACCEPTANCE_GATE=%s" % ("fail" if failure else "pass")]
    for key in (*OBSERVED_KEYS, "RACE_SCENE_FAIL"):
        value = fields.get(key)
        lines.append("%s=%s" % (key, "absent" if value is None else value))
    if failure:
        lines.append("RACE_ACCEPTANCE_FAIL %s" % failure)
    else:
        lines.append("RACE_ACCEPTANCE_FAIL none")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    suite_names = "|".join(sorted(SUITE_COURSES))
    if len(argv) not in (2, 3):
        print(
            "usage: verdant_race_acceptance_gate.py OBSERVER_LOG [%s]" % suite_names,
            file=sys.stderr,
        )
        return 2
    path = Path(argv[1])
    suite = argv[2] if len(argv) == 3 else "launch"
    if suite not in SUITE_COURSES:
        print(
            "usage: verdant_race_acceptance_gate.py OBSERVER_LOG [%s]" % suite_names,
            file=sys.stderr,
        )
        return 2
    required = SUITE_COURSES[suite]
    if not path.is_file():
        report, _failures = evaluate_courses("", required)
        print(report, end="")
        print("RACE_ACCEPTANCE_FAIL observer log absent: %s" % path)
        return 1
    report, failures = evaluate_courses(
        path.read_text(encoding="utf-8", errors="replace"),
        required,
    )
    print(report, end="")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
