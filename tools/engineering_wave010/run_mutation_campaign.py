#!/usr/bin/env python3
"""Wave010 mutation campaign — disposable dirs only. Never commits mutants."""
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
        "max_active_multiplier: float = 1.55",
        "max_active_multiplier: float = 1.0",
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
    # Copy global class cache so class_name resolves without full editor import.
    godot_cache = ROOT / ".godot"
    if godot_cache.exists():
        shutil.copytree(
            godot_cache,
            dst / ".godot",
            ignore=shutil.ignore_patterns("imported", "editor", "shader_cache"),
        )
    (dst / "artifacts/engineering_wave010").mkdir(parents=True, exist_ok=True)


def run_one(godot: str, work: Path, mid: str, rel: str, old: str, new: str) -> dict:
    target = work / rel
    text = target.read_text()
    if old not in text:
        return {"id": mid, "killed": False, "reason": "pattern_not_found"}
    target.write_text(text.replace(old, new, 1))
    subprocess.run(
        [godot, "--headless", "--path", str(work), "--import"],
        cwd=work,
        capture_output=True,
        text=True,
        timeout=120,
    )
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
        timeout=180,
    )
    log = (proc.stdout or "") + (proc.stderr or "")
    script_boom = any(
        x in log
        for x in (
            "SCRIPT ERROR",
            "Parse Error",
            "Compilation failed",
            "Wave010RuntimeTest FAIL",
            "FAIL:",
        )
    )
    # Healthy run must print PASS token.
    passed_clean = "Wave010RuntimeTest PASS" in log and not script_boom
    killed = (not passed_clean) or proc.returncode != 0
    return {
        "id": mid,
        "killed": bool(killed),
        "exit": proc.returncode,
        "log_tail": "\n".join(log.splitlines()[-30:]),
    }


def main() -> int:
    godot = resolve_godot()
    if not godot:
        print("Godot not found", file=sys.stderr)
        return 2
    results = []
    with tempfile.TemporaryDirectory(prefix="pp-wave010-mut-") as tmp:
        for mid, rel, old, new in MUTATIONS:
            work = Path(tmp) / mid
            work.mkdir()
            copy_tree(work)
            results.append(run_one(godot, work, mid, rel, old, new))
    attempted = len(results)
    killed = sum(1 for r in results if r.get("killed"))
    payload = {
        "schema": "gunnchos.engineering_wave010.mutation.v1",
        "WAVE010_MUTATIONS_ATTEMPTED": attempted,
        "WAVE010_MUTATIONS_KILLED": killed,
        "MUTATED_FILES_COMMITTED": False,
        "results": results,
        "pass": killed >= 8 and killed == attempted,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps(payload, indent=2))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
