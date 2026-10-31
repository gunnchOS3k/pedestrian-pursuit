"""A finished cup race keeps its standing and resumes at the saved race."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from cup_resume import plan_saved_cup  # noqa: E402


def _function_body(source: str, header: str) -> str:
    start = source.find(header)
    if start < 0:
        return ""
    next_fn = source.find("\nfunc ", start + len(header))
    if next_fn < 0:
        return source[start:]
    return source[start:next_fn]


class CupResumeTests(unittest.TestCase):
    def test_recorded_finish_keeps_standing_and_skips_race_one(self) -> None:
        plan = plan_saved_cup(
            round_index=0,
            result_count=1,
            track_count=4,
            standings={"You": 10, "Runner": 7},
            resume_index=1,
            cup_id="sole_surge_cup",
        )
        self.assertTrue(plan["resumable"])
        self.assertEqual(plan["round_index"], 1)
        self.assertEqual(plan["course_number"], 2)
        self.assertEqual(plan["standing"], {"You": 10, "Runner": 7})
        self.assertFalse(plan["finished"])

    def test_unfinished_round_resumes_that_same_race(self) -> None:
        plan = plan_saved_cup(
            round_index=2,
            result_count=2,
            track_count=4,
            standings={"You": 20},
            resume_index=2,
            cup_id="sole_surge_cup",
        )
        self.assertTrue(plan["resumable"])
        self.assertEqual(plan["round_index"], 2)
        self.assertEqual(plan["standing"]["You"], 20)

    def test_stored_resume_index_is_not_reset_to_race_one(self) -> None:
        plan = plan_saved_cup(
            round_index=0,
            result_count=0,
            track_count=4,
            standings={"You": 17},
            resume_index=2,
            cup_id="stride_circuit_cup",
        )
        self.assertEqual(plan["round_index"], 2)
        self.assertEqual(plan["standing"]["You"], 17)

    def test_finished_cup_keeps_the_standing_and_does_not_resume(self) -> None:
        plan = plan_saved_cup(
            round_index=3,
            result_count=4,
            track_count=4,
            standings={"You": 40},
            resume_index=4,
            completed=True,
            cup_id="sole_surge_cup",
        )
        self.assertFalse(plan["resumable"])
        self.assertTrue(plan["finished"])
        self.assertEqual(plan["standing"]["You"], 40)

    def test_results_menu_saves_and_start_continues_the_saved_cup(self) -> None:
        results = (ROOT / "scripts/ui/ResultsScreen.gd").read_text(encoding="utf-8")
        menu_fn = _function_body(results, "func _on_menu")
        self.assertNotIn("clear_cup", menu_fn)
        self.assertIn("save_cup_progress", menu_fn)

        menu = (ROOT / "scripts/ui/MainMenu.gd").read_text(encoding="utf-8")
        start = _function_body(menu, "func _on_start_cup")
        self.assertLess(start.find("resume_saved_cup"), start.find("GameManager.start_cup"))
        self.assertIn("cup_id", start)

        gm = (ROOT / "scripts/core/GameManager.gd").read_text(encoding="utf-8")
        save = _function_body(gm, "func save_cup_progress")
        self.assertIn('"resume_index"', save)
        self.assertIn("_snapshot_standings", save)
        resume = _function_body(gm, "func resume_saved_cup")
        self.assertIn("round_index", resume)
        self.assertNotIn("cup_round_index = 0", resume)
        describe = _function_body(gm, "func describe_saved_cup")
        self.assertIn("resume_index", describe)
