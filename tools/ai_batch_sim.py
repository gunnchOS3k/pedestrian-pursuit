#!/usr/bin/env python3
"""Batch AI route-planning sim harness (no physics cheats).

Estimates lap times from path curvature + AI tier look-ahead / braking profiles.
Does not invent speed above tier caps — useful for Alpha balance smoke.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TIERS = {
    "rookie": {"look_ahead": 7.0, "speed": 14.5, "brake_curvature": 0.02},
    "standard": {"look_ahead": 10.0, "speed": 16.5, "brake_curvature": 0.028},
    "ace": {"look_ahead": 14.0, "speed": 18.0, "brake_curvature": 0.034},
}


def _dist(a: list[float], b: list[float]) -> float:
    return math.sqrt(sum((float(a[i]) - float(b[i])) ** 2 for i in range(3)))


def _curvature(route: list[list[float]], index: int) -> float:
    a = route[index]
    b = route[(index + 1) % len(route)]
    c = route[(index + 2) % len(route)]
    v1 = (float(b[0]) - float(a[0]), float(b[2]) - float(a[2]))
    v2 = (float(c[0]) - float(b[0]), float(c[2]) - float(b[2]))
    n1 = math.hypot(*v1)
    n2 = math.hypot(*v2)
    if n1 < 1e-6 or n2 < 1e-6:
        return 0.0
    cross = (v1[0] / n1) * (v2[1] / n2) - (v1[1] / n1) * (v2[0] / n2)
    return abs(cross)


def simulate_lap(track: dict, tier_name: str) -> dict:
    tier = TIERS[tier_name]
    route = track["path_points"]
    lap_count = int(track.get("lap_count", 3))
    total_time = 0.0
    segments = []
    for i in range(len(route)):
        length = _dist(route[i], route[(i + 1) % len(route)])
        curv = _curvature(route, i)
        speed = tier["speed"]
        if curv > tier["brake_curvature"]:
            speed *= max(0.55, 1.0 - curv * 4.0)
        # Look-ahead tiers recover earlier after bends (planning, not cheat speed).
        recovery = min(1.0, tier["look_ahead"] / 14.0)
        speed *= 0.9 + 0.1 * recovery
        dt = length / max(speed, 1.0)
        total_time += dt
        segments.append({"i": i, "length": round(length, 2), "curv": round(curv, 4), "dt": round(dt, 3)})
    race_time = total_time * lap_count
    return {
        "track_id": track["id"],
        "tier": tier_name,
        "lap_sec": round(total_time, 2),
        "race_sec": round(race_time, 2),
        "segments": len(segments),
        "max_curvature": round(max(s["curv"] for s in segments), 4),
    }


def main() -> int:
    cups = ["sole_surge_cup", "stride_circuit_cup"]
    results = []
    for cup_id in cups:
        cup = json.loads((ROOT / f"data/cups/{cup_id}.json").read_text(encoding="utf-8"))
        for track_id in cup["track_ids"]:
            track = json.loads((ROOT / f"data/tracks/{track_id}.json").read_text(encoding="utf-8"))
            for tier in TIERS:
                results.append(simulate_lap(track, tier))

    # Sanity: ace should never be slower than rookie on same course.
    by_track: dict[str, dict[str, float]] = {}
    for row in results:
        by_track.setdefault(row["track_id"], {})[row["tier"]] = row["race_sec"]
    failures = []
    for track_id, times in by_track.items():
        if times["ace"] > times["rookie"] + 0.05:
            failures.append(f"{track_id}: ace slower than rookie ({times['ace']} > {times['rookie']})")
        if times["standard"] > times["rookie"] + 0.05:
            failures.append(
                f"{track_id}: standard slower than rookie ({times['standard']} > {times['rookie']})"
            )

    out = ROOT / "gate1/evidence/out/wave_e_ai_batch_sim.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "wave_e_ai_batch_sim/v1",
        "physics_cheats": False,
        "note": "Curvature + look-ahead planning model only; not a Godot physics replay.",
        "results": results,
        "failures": failures,
    }
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if failures:
        print("AI batch sim failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"AI batch sim OK for {len(by_track)} tracks × {len(TIERS)} tiers → {out}")
    for track_id, times in sorted(by_track.items()):
        print(
            f"  {track_id}: rookie={times['rookie']:.1f}s  "
            f"standard={times['standard']:.1f}s  ace={times['ace']:.1f}s"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
