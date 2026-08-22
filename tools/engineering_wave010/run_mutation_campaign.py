#!/usr/bin/env python3
"""Wave010 mutation campaign — disposable dirs only. Never commits mutants.

Kill only if: clean parse+test PASS, mutation applied, mutated parse PASS,
mutated test FAIL with behavioral assertions. Else INVALID_MUTATION.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/engineering_wave010/MUTATION_RESULT.json"

MUTATIONS = [
    (
        "accel_disabled",
        "scripts/player/MovementStats.gd",
        'acceleration = float(racer.get("acceleration", 18.0)) * float(shoe.get("acceleration_modifier", 1.0))',
        "acceleration = 0.01",
    ),
    (
        "drift_stationary_farm",
        "scripts/player/DriftSystem.gd",
        "min_speed_to_drift: float = 3.5",
        "min_speed_to_drift: float = 0.0",
    ),
    (
        "boost_cap_removed",
        "scripts/player/BoostSystem.gd",
        "max_boost: float = 100.0",
        "max_boost: float = 100000.0",
    ),
    (
        "item_weight_extreme",
        "scripts/race/FairComebackPolicy.gd",
        "COMPETITIVE_MAX_OFFENSE_WEIGHT := 1.15",
        "COMPETITIVE_MAX_OFFENSE_WEIGHT := 8.0",
    ),
    (
        "checkpoint_bypass",
        "scripts/race/LapManager.gd",
        "if index != state.next_checkpoint:\n\t\treturn",
        "if false:\n\t\treturn",
    ),
    (
        "racer_stats_flat",
        "scripts/player/MovementStats.gd",
        'top_speed = float(racer.get("top_speed", 22.0)) * float(shoe.get("top_speed_modifier", 1.0))\n\tacceleration = float(racer.get("acceleration", 18.0)) * float(shoe.get("acceleration_modifier", 1.0))\n\thandling = float(racer.get("handling", 12.0)) * float(shoe.get("handling_modifier", 1.0))\n\tdrift_control = float(racer.get("drift_control", 10.0)) * float(shoe.get("drift_modifier", 1.0))',
        'top_speed = 22.0\n\tacceleration = 18.0\n\thandling = 12.0\n\tdrift_control = 10.0',
    ),
    (
        "hidden_comeback_speed",
        "scripts/race/FairComebackPolicy.gd",
        "static func competitive_speed_assist(_place: int, _field_size: int) -> float:\n\t## Forbidden: always 1.0 (no place-based speed).\n\treturn 1.0",
        "static func competitive_speed_assist(_place: int, _field_size: int) -> float:\n\treturn 1.0 + float(max(0, _place - 1)) * 0.12",
    ),
	(
        "mastery_boost_flat",
        "scripts/player/BoostSystem.gd",
        "max_active_multiplier: float = 1.65",
        "max_active_multiplier: float = 1.0",
    ),
    (
        "drift_release_flat",
        "scripts/player/DriftSystem.gd",
        "boost_multipliers: Array[float] = [1.16, 1.24, 1.34, 1.45]",
        "boost_multipliers: Array[float] = [1.0, 1.0, 1.0, 1.0]",
    ),
    (
        "manual_boost_mult_disabled",
        "scripts/player/BoostSystem.gd",
        "boost_speed_multiplier: float = 1.48",
        "boost_speed_multiplier: float = 1.0",
    ),
    (
        "ghost_update_load_broken",
        "scripts/race/GhostRecorder.gd",
        'func load_samples(track_id: String) -> Array:\n\tvar path := GHOST_PATH % track_id\n\tif not FileAccess.file_exists(path):\n\t\treturn []',
        'func load_samples(track_id: String) -> Array:\n\treturn []\n\tvar path := GHOST_PATH % track_id\n\tif not FileAccess.file_exists(path):\n\t\treturn []',
    ),
]


def resolve_godot() -> str:
    env = os.environ.get("GODOT_BIN")
    if env and Path(env).exists():
        return env
    for c in (
        "/Applications/Godot.app/Contents/MacOS/Godot",
        "/opt/homebrew/bin/godot",
    ):
        if Path(c).exists():
            return c
    return shutil.which("godot") or ""


def copy_tree(dst: Path) -> None:
    for name in ("scripts", "tests", "data", "scenes", "device_ux", "release", "project.godot", "icon.svg", "icon.png"):
        src = ROOT / name
        if not src.exists():
            continue
        target = dst / name
        if src.is_dir():
            shutil.copytree(src, target, ignore=shutil.ignore_patterns("*.uid"))
        else:
            shutil.copy2(src, target)
    godot_cache = ROOT / ".godot"
    if godot_cache.exists():
        shutil.copytree(
            godot_cache,
            dst / ".godot",
            ignore=shutil.ignore_patterns("imported", "editor", "shader_cache"),
        )
    (dst / "artifacts/engineering_wave010").mkdir(parents=True, exist_ok=True)


def run_component(godot: str, work: Path) -> tuple[int, str]:
    proc = subprocess.run(
        [
            godot,
            "--headless",
            "--path",
            str(work),
            "--script",
            "res://tests/engineering_wave010/Wave010RuntimeTest.gd",
        ],
        cwd=work,
        capture_output=True,
        text=True,
        timeout=240,
    )
    log = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, log


def parse_ok(log: str) -> bool:
    bad = ("Parse Error", "Compilation failed", "SCRIPT ERROR: Parse Error")
    return not any(b in log for b in bad)


def behavioral_fail(log: str, code: int) -> bool:
    """Mutated test must FAIL with behavioral assertions — not merely crash/parse."""
    if not parse_ok(log):
        return False
    if "Wave010RuntimeTest FAIL" in log or "FAIL:" in log:
        return True
    # Exit non-zero with PASS token absent also counts if assertions printed failures.
    if code != 0 and "Wave010RuntimeTest PASS" not in log and "WAVE010_COMPONENT_RUNTIME_PASS" not in log:
        # Prefer explicit FAIL markers; without them treat as invalid.
        return "FAIL:" in log
    return False


def run_one(godot: str, work: Path, mid: str, rel: str, old: str, new: str, clean_ok: bool) -> dict:
    if not clean_ok:
        return {
            "id": mid,
            "killed": False,
            "invalid": True,
            "reason": "INVALID_MUTATION:clean_baseline_not_pass",
        }
    target = work / rel
    text = target.read_text()
    if old not in text:
        return {
            "id": mid,
            "killed": False,
            "invalid": True,
            "reason": "INVALID_MUTATION:pattern_not_found",
        }
    target.write_text(text.replace(old, new, 1))
    if old in target.read_text() and new not in target.read_text():
        return {
            "id": mid,
            "killed": False,
            "invalid": True,
            "reason": "INVALID_MUTATION:mutation_not_applied",
        }
    # Mutated parse probe via import + component run.
    subprocess.run(
        [godot, "--headless", "--path", str(work), "--import"],
        cwd=work,
        capture_output=True,
        text=True,
        timeout=120,
    )
    code, log = run_component(godot, work)
    if not parse_ok(log):
        return {
            "id": mid,
            "killed": False,
            "invalid": True,
            "reason": "INVALID_MUTATION:mutated_parse_failed",
            "exit": code,
            "log_tail": "\n".join(log.splitlines()[-40:]),
        }
    if "Wave010RuntimeTest PASS" in log and "WAVE010_COMPONENT_RUNTIME_PASS" in log and code == 0:
        return {
            "id": mid,
            "killed": False,
            "invalid": False,
            "reason": "survived",
            "exit": code,
            "log_tail": "\n".join(log.splitlines()[-30:]),
        }
    if behavioral_fail(log, code):
        return {
            "id": mid,
            "killed": True,
            "invalid": False,
            "behavioral": True,
            "reason": "behavioral_kill",
            "exit": code,
            "log_tail": "\n".join(log.splitlines()[-30:]),
        }
    return {
        "id": mid,
        "killed": False,
        "invalid": True,
        "reason": "INVALID_MUTATION:no_behavioral_assertion_failure",
        "exit": code,
        "log_tail": "\n".join(log.splitlines()[-40:]),
    }


def main() -> int:
    godot = resolve_godot()
    if not godot:
        print("Godot not found", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="pp-wave010-mut-") as tmp:
        clean = Path(tmp) / "clean"
        clean.mkdir()
        copy_tree(clean)
        subprocess.run(
            [godot, "--headless", "--path", str(clean), "--import"],
            cwd=clean,
            capture_output=True,
            text=True,
            timeout=120,
        )
        clean_code, clean_log = run_component(godot, clean)
        clean_ok = (
            parse_ok(clean_log)
            and clean_code == 0
            and "Wave010RuntimeTest PASS" in clean_log
        )
        results = []
        for mid, rel, old, new in MUTATIONS:
            work = Path(tmp) / mid
            work.mkdir()
            copy_tree(work)
            results.append(run_one(godot, work, mid, rel, old, new, clean_ok))

    attempted = len(results)
    invalid = sum(1 for r in results if r.get("invalid"))
    behavioral_killed = sum(1 for r in results if r.get("killed") and r.get("behavioral"))
    killed = sum(1 for r in results if r.get("killed"))
    payload = {
        "schema": "gunnchos.engineering_wave010.mutation.v1",
        "clean_baseline_pass": clean_ok,
        "WAVE010_MUTATIONS_ATTEMPTED": attempted,
        "WAVE010_MUTATIONS_KILLED": killed,
        "WAVE010_BEHAVIORAL_KILLED": behavioral_killed,
        "WAVE010_INVALID_MUTATIONS": invalid,
        "MUTATED_FILES_COMMITTED": False,
        "results": results,
        "pass": (
            clean_ok
            and invalid == 0
            and behavioral_killed >= 11
            and behavioral_killed == attempted
        ),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps(payload, indent=2))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
