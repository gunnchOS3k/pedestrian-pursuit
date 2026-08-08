from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_content import validate_project  # noqa: E402


class WaveEAlphaContentTests(unittest.TestCase):
    def test_all_course_content_is_valid(self) -> None:
        self.assertEqual(validate_project(ROOT), [])

    def test_two_cups_eight_unique_tracks(self) -> None:
        cups = []
        track_ids: list[str] = []
        for cup_id in ("sole_surge_cup", "stride_circuit_cup"):
            cup = json.loads((ROOT / f"data/cups/{cup_id}.json").read_text(encoding="utf-8"))
            cups.append(cup)
            track_ids.extend(cup["track_ids"])
        self.assertEqual(len(cups), 2)
        self.assertEqual(len(set(track_ids)), 8)

    def test_cup_orders_are_intentional(self) -> None:
        sole = json.loads((ROOT / "data/cups/sole_surge_cup.json").read_text(encoding="utf-8"))
        stride = json.loads((ROOT / "data/cups/stride_circuit_cup.json").read_text(encoding="utf-8"))
        self.assertEqual(
            sole["track_ids"],
            [
                "verdant_cascade_circuit",
                "cloverwind_ranch",
                "prism_apex",
                "emberkeep_gauntlet",
            ],
        )
        self.assertEqual(
            stride["track_ids"],
            [
                "tideglass_harbor",
                "neon_switchyard",
                "cloudstep_ridge",
                "mirage_mesa",
            ],
        )

    def test_footwear_and_items_meet_alpha_floor(self) -> None:
        shoes = list((ROOT / "data/shoes").glob("*.json"))
        items = list((ROOT / "data/items").glob("*.json"))
        self.assertGreaterEqual(len(shoes), 4)
        self.assertGreaterEqual(len(items), 6)
        for path in items:
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertIn("counterplay", data)
            self.assertIn("warning_seconds", data)
        for path in shoes:
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertIn("material_family", data)
            self.assertGreaterEqual(len(data.get("surface_affinities", {})), 6)

    def test_runners_have_gameplay_stats(self) -> None:
        roster = json.loads((ROOT / "data/racers/runner_roster.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(roster["runners"]), 8)
        speeds = set()
        for runner in roster["runners"]:
            rid = runner["id"]
            path = ROOT / f"data/racers/{rid}.json"
            self.assertTrue(path.exists(), f"missing gameplay file for {rid}")
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertIn("top_speed", data)
            self.assertIn("acceleration", data)
            speeds.add(round(float(data["top_speed"]), 1))
        self.assertGreaterEqual(len(speeds), 4)

    def test_grammar_challenges_art_inventory(self) -> None:
        grammar = json.loads((ROOT / "data/mechanics/foot_racing_grammar.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(grammar["mechanics"]), 10)
        challenges = json.loads((ROOT / "data/challenges/launch_challenges.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(challenges["challenges"]), 5)
        art = json.loads((ROOT / "data/art/REQUIRES_ART_PRODUCTION_INVENTORY.json").read_text(encoding="utf-8"))
        self.assertEqual(art["status"], "REQUIRES_ART_PRODUCTION")
        self.assertEqual(len(art["tracks"]), 8)

    def test_runners_meet_alpha_floor(self) -> None:
        roster = json.loads((ROOT / "data/racers/runner_roster.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(roster["runners"]), 8)

    def test_greybox_tracks_mark_art_production(self) -> None:
        for track_id in (
            "tideglass_harbor",
            "neon_switchyard",
            "cloudstep_ridge",
            "mirage_mesa",
            "verdant_cascade_circuit",
            "cloverwind_ranch",
            "prism_apex",
            "emberkeep_gauntlet",
        ):
            track = json.loads((ROOT / f"data/tracks/{track_id}.json").read_text(encoding="utf-8"))
            self.assertEqual(track.get("art_status"), "REQUIRES_ART_PRODUCTION")
            self.assertTrue(track.get("has_shortcut") or track.get("shortcut_routes"))
            self.assertGreaterEqual(len(track.get("rail_segments", [])), 1)

    def test_shipped_course_identity_is_original(self) -> None:
        protected_names = ("mario", "yoshi", "moo moo", "rainbow road", "bowser", "nintendo")
        for path in (ROOT / "data").glob("**/*.json"):
            content = path.read_text(encoding="utf-8").lower()
            for protected_name in protected_names:
                self.assertNotIn(protected_name, content, f"{protected_name!r} found in {path}")

    def test_ai_batch_sim_harness(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(ROOT / "tools/ai_batch_sim.py")],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)
        out = ROOT / "gate1/evidence/out/wave_e_ai_batch_sim.json"
        self.assertTrue(out.exists())
        payload = json.loads(out.read_text(encoding="utf-8"))
        self.assertFalse(payload.get("physics_cheats", True))
        self.assertEqual(len(payload.get("failures", [])), 0)


if __name__ == "__main__":
    unittest.main()
