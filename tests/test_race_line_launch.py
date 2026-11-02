"""Off-line bounce aim for the courses that never completed a lap.

The hop may change horizontal velocity. It does not move the racer onto a
gate, and checkpoint 4 is still required before a lap counts.
"""

from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from race_line_launch import (  # noqa: E402
    FAILED_LAUNCH_COURSES,
    LapGate,
    incoming_forward,
    lap_without_checkpoint,
    ordered_lap,
    redirect_horizontal,
    segment_forward,
)


def _dot(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1]


class RaceLineLaunchTests(unittest.TestCase):
    def test_failed_courses_redirect_an_off_segment_aim(self) -> None:
        course_track = (ROOT / "scripts/tracks/CourseTrack.gd").read_text(encoding="utf-8")
        bounce_pad = (ROOT / "scripts/tracks/BouncePad.gd").read_text(encoding="utf-8")
        self.assertIn('pad.set("launch_forward"', course_track)
        self.assertIn("launch_forward", bounce_pad)
        self.assertIn("0.9", bounce_pad)
        for track_id in FAILED_LAUNCH_COURSES:
            course = json.loads((ROOT / f"data/tracks/{track_id}.json").read_text(encoding="utf-8"))
            points = course["path_points"]
            self.assertGreaterEqual(len(course["checkpoint_points"]), 5, track_id)
            self.assertIn(4, range(len(course["checkpoint_points"])))
            pads = course["bounce_pads"]
            self.assertGreaterEqual(len(pads), 1, track_id)
            for pad in pads:
                index = int(pad["point_index"])
                line = segment_forward(points, index)
                facing = incoming_forward(points, index)
                self.assertLess(_dot(facing, line), 0.9, "%s pad %s" % (track_id, index))
                carried = 22.0
                velocity = (facing[0] * carried, facing[1] * carried)
                kick = float(pad["forward_boost"])
                result, redirected = redirect_horizontal(facing, velocity, line, kick)
                self.assertTrue(redirected, "%s pad %s" % (track_id, index))
                result_len = math.hypot(result[0], result[1])
                self.assertAlmostEqual(result[0] / result_len, line[0], places=5)
                self.assertAlmostEqual(result[1] / result_len, line[1], places=5)
                self.assertAlmostEqual(result_len, carried + kick, places=5)

    def test_checkpoint_four_is_still_required_before_a_lap(self) -> None:
        for track_id in FAILED_LAUNCH_COURSES:
            course = json.loads((ROOT / f"data/tracks/{track_id}.json").read_text(encoding="utf-8"))
            checkpoint_count = len(course["checkpoint_points"])
            skipped = lap_without_checkpoint(checkpoint_count, 4)
            self.assertEqual(skipped.lap, 0, track_id)
            self.assertEqual(skipped.next_checkpoint, 4, track_id)
            waiting = LapGate(checkpoint_count)
            for index in (1, 2, 3, 0):
                waiting.on_checkpoint(index)
            self.assertEqual(waiting.lap, 0, track_id)
            self.assertEqual(waiting.next_checkpoint, 4, track_id)
            finished = ordered_lap(checkpoint_count)
            self.assertEqual(finished.lap, 1, track_id)
            extra_line = LapGate(checkpoint_count)
            extra_line.on_checkpoint(0)
            self.assertEqual(extra_line.lap, 0, track_id)

    def test_aligned_hop_keeps_its_heading(self) -> None:
        line = (1.0, 0.0)
        velocity = (18.0, 0.0)
        result, redirected = redirect_horizontal(line, velocity, line, 4.5)
        self.assertFalse(redirected)
        self.assertAlmostEqual(result[0], 22.5, places=5)
        self.assertAlmostEqual(result[1], 0.0, places=5)


if __name__ == "__main__":
    unittest.main()
