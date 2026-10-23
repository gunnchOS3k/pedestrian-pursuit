"""The Verdant acceptance gate fails closed unless a log proves a real lap."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

from verdant_race_acceptance_gate import (  # noqa: E402
    acceptance_failure,
    parse_observer_log,
)


EXTRACT = ROOT / "artifacts" / "ci" / "pr46_5acaac3_verdant_observer_extract.json"


class VerdantRaceAcceptanceGateTests(unittest.TestCase):
    def test_absent_fields_fail(self) -> None:
        fields = parse_observer_log("")
        self.assertIsNone(fields["LAP_COMPLETED"])
        self.assertIsNone(fields["CHECKPOINT_CROSSED"])
        self.assertIsNone(fields["RESULTS_PATH"])
        self.assertIsNotNone(acceptance_failure(fields))

    def test_false_observations_fail(self) -> None:
        text = "\n".join(
            [
                "RACE_ENTERED=true",
                "LAP_COMPLETED=false",
                "CHECKPOINT_CROSSED=false",
                "RESULTS_PATH=false",
                "COURSE_ACCEPTED=false",
                "DEVICE_RUN=false",
            ]
        )
        self.assertIn("not true", acceptance_failure(parse_observer_log(text)) or "")

    def test_owner_accepted_flag_is_not_a_lap(self) -> None:
        text = "\n".join(
            [
                "RACE_ENTERED=true",
                "LAP_COMPLETED=true",
                "CHECKPOINT_CROSSED=true",
                "RESULTS_PATH=true",
                "COURSE_ACCEPTED=true",
            ]
        )
        failure = acceptance_failure(parse_observer_log(text))
        self.assertIn("COURSE_ACCEPTED", failure or "")

    def test_scene_failure_is_not_a_lap(self) -> None:
        text = "\n".join(
            [
                "RACE_ENTERED=false",
                "LAP_COMPLETED=false",
                "CHECKPOINT_CROSSED=false",
                "RESULTS_PATH=false",
                "COURSE_ACCEPTED=false",
                "DEVICE_RUN=false",
                "RACE_SCENE_FAIL Verdant RaceScene did not reach countdown",
            ]
        )
        failure = acceptance_failure(parse_observer_log(text))
        self.assertIn("RACE_SCENE_FAIL", failure or "")

    def test_real_checkpoint_lap_and_results_pass(self) -> None:
        text = "\n".join(
            [
                "RACE_ENTERED=true",
                "LAP_COMPLETED=true",
                "CHECKPOINT_CROSSED=true",
                "RESULTS_PATH=true",
                "COURSE_ACCEPTED=false",
                "DEVICE_RUN=false",
            ]
        )
        self.assertIsNone(acceptance_failure(parse_observer_log(text)))

    def test_recorded_pr46_log_extract_is_not_a_lap(self) -> None:
        extract = json.loads(EXTRACT.read_text(encoding="utf-8"))
        self.assertEqual(extract["head_sha"], "5acaac344b15df5d10cc95943ca7df0e14056d8f")
        self.assertFalse(extract["genuine_lap_completed"])
        self.assertEqual(extract["job_conclusion"], "success")
        for key in (
            "RACE_ENTERED",
            "LAP_COMPLETED",
            "CHECKPOINT_CROSSED",
            "RESULTS_PATH",
            "COURSE_ACCEPTED",
            "DEVICE_RUN",
            "RACE_SCENE_FAIL",
        ):
            self.assertFalse(extract["fields"][key]["present"], key)
            self.assertIsNone(extract["fields"][key]["value"], key)
        for course in extract["courses"]:
            self.assertEqual(course["status"], "not_accepted")

    def test_cli_fails_when_log_missing(self) -> None:
        script = ROOT / "tests" / "verdant_race_acceptance_gate.py"
        completed = subprocess.run(
            [sys.executable, str(script), str(ROOT / "tmp" / "missing-verdant-observe.log")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 1)
        self.assertIn("RACE_ACCEPTANCE_GATE=fail", completed.stdout)
        self.assertIn("LAP_COMPLETED=absent", completed.stdout)


if __name__ == "__main__":
    unittest.main()
