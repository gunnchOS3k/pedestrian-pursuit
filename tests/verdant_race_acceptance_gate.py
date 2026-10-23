#!/usr/bin/env python3
"""Fail unless a Verdant observer log shows a real lap.

Exit 0 from Godot is not acceptance. The gate passes only when the log
records all of:
  RACE_ENTERED=true
  CHECKPOINT_CROSSED=true
  LAP_COMPLETED=true
  RESULTS_PATH=true
and does not record COURSE_ACCEPTED=true or a RACE_SCENE_FAIL line.
Missing keys are absent, not true.
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
    if len(argv) != 2:
        print("usage: verdant_race_acceptance_gate.py OBSERVER_LOG", file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.is_file():
        fields = parse_observer_log("")
        print(format_report(fields, "observer log absent: %s" % path), end="")
        return 1
    fields = parse_observer_log(path.read_text(encoding="utf-8", errors="replace"))
    failure = acceptance_failure(fields)
    print(format_report(fields, failure), end="")
    return 0 if failure is None else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
