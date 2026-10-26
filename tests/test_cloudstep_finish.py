"""Cloudstep Ridge reaches results only from an in-order finish."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from cloudstep_finish import CLOUDSTEP_TRACK_ID, CloudstepFinish, choose_respawn  # noqa: E402


def _function_body(source: str, header: str) -> str:
    start = source.find(header)
    if start < 0:
        return ""
    next_fn = source.find("\nfunc ", start + len(header))
    if next_fn < 0:
        return source[start:]
    return source[start:next_fn]


class CloudstepFinishTests(unittest.TestCase):
    def setUp(self) -> None:
        self.course = json.loads(
            (ROOT / f"data/tracks/{CLOUDSTEP_TRACK_ID}.json").read_text(encoding="utf-8")
        )
        self.checkpoint_count = len(self.course["checkpoint_points"])
        self.lap_count = int(self.course["lap_count"])

    def test_void_respawn_does_not_skip_ahead_or_open_results(self) -> None:
        player = (ROOT / "scripts/player/PlayerController.gd").read_text(encoding="utf-8")
        scene = (ROOT / "scripts/race/RaceScene.gd").read_text(encoding="utf-8")
        recover = _function_body(player, "func _recover_from_fall")
        physics = _function_body(scene, "func _physics_process")
        rescue = _function_body(scene, "func _rescue_fallen_onto_path")
        finish = _function_body(scene, "func _on_race_finished")
        self.assertNotIn("snap_to_path", recover)
        self.assertNotIn("snap_body_to_nearest_path", recover)
        self.assertNotIn("snap_body_to_nearest_path", physics)
        self.assertNotIn("snap_to_path", rescue)
        self.assertIn("_VoidRecovery.choose", recover)
        self.assertIn("show_results", finish)
        self.assertNotIn("show_results", recover)
        self.assertNotIn("show_results", rescue)

        start = (0.0, 0.0, 44.0)
        accepted = self.course["path_points"][4]
        nearest = self.course["path_points"][8]
        self.assertEqual(choose_respawn(False, accepted, start), start)
        self.assertEqual(choose_respawn(True, accepted, start), accepted)
        self.assertNotEqual(choose_respawn(True, accepted, start), nearest)

        race = CloudstepFinish(self.checkpoint_count, self.lap_count)
        for index in (1, 2, 3):
            self.assertTrue(race.cross(index))
        self.assertEqual(race.fall(), 3)
        self.assertFalse(race.cross(5))
        self.assertFalse(race.cross(0))
        self.assertEqual(race.gate.lap, 0)
        self.assertEqual(race.gate.next_checkpoint, 4)
        self.assertEqual(race.state, "racing")
        self.assertFalse(race.results_visible)

    def test_results_open_only_after_the_in_order_finish(self) -> None:
        race = CloudstepFinish(self.checkpoint_count, self.lap_count)
        order = list(range(1, self.checkpoint_count)) + [0]
        for _lap in range(self.lap_count - 1):
            for index in order:
                self.assertTrue(race.cross(index))
            self.assertFalse(race.results_visible)
            self.assertEqual(race.state, "racing")
        for index in order[:-1]:
            self.assertTrue(race.cross(index))
        self.assertFalse(race.results_visible)
        self.assertTrue(race.cross(0))
        self.assertEqual(race.gate.lap, self.lap_count)
        self.assertEqual(race.state, "finished")
        self.assertTrue(race.results_visible)
        forced = CloudstepFinish(self.checkpoint_count, self.lap_count)
        self.assertFalse(forced.results_visible)
        self.assertEqual(forced.state, "racing")


if __name__ == "__main__":
    unittest.main()
