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
    LAUNCH_COURSE_IDS,
    acceptance_failure,
    evaluate_courses,
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
        self.assertIn("COURSE_GATE verdant_cascade_circuit=absent", completed.stdout)

    def test_one_failed_course_fails_the_gate(self) -> None:
        report, failures = evaluate_courses(
            _all_courses(cloverwind_ranch={"RESULTS_PATH": "false", "RACE_STATE": "2"})
        )
        self.assertEqual(failures, ["cloverwind_ranch"])
        self.assertIn("RACE_ACCEPTANCE_GATE=fail", report)
        self.assertIn("COURSE_GATE verdant_cascade_circuit=pass", report)
        self.assertIn("COURSE_GATE cloverwind_ranch=fail", report)
        self.assertIn("COURSE_GATE mirage_mesa=pass", report)

    def test_later_pass_does_not_erase_an_earlier_fail(self) -> None:
        first = _course_block("prism_apex", RESULTS_PATH="false")
        second = _course_block("prism_apex", RESULTS_PATH="true")
        others = _all_courses()
        report, failures = evaluate_courses(first + "\n" + second + "\n" + others)
        self.assertIn("prism_apex", failures)
        self.assertIn("COURSE_GATE prism_apex=fail", report)
        self.assertNotIn("COURSE_GATE prism_apex=pass", report)

    def test_owner_accepted_course_does_not_pass(self) -> None:
        report, failures = evaluate_courses(
            _all_courses(emberkeep_gauntlet={"COURSE_ACCEPTED": "true"})
        )
        self.assertEqual(failures, ["emberkeep_gauntlet"])
        self.assertIn("COURSE_ACCEPTED", report)

    def test_all_eight_real_results_pass(self) -> None:
        report, failures = evaluate_courses(_all_courses())
        self.assertEqual(failures, [])
        self.assertIn("RACE_ACCEPTANCE_GATE=pass", report)
        for course_id in LAUNCH_COURSE_IDS:
            self.assertIn("COURSE_GATE %s=pass" % course_id, report)


def _course_block(track_id: str, **overrides: str) -> str:
    fields = {
        "RACE_ENTERED": "true",
        "CHECKPOINT_CROSSED": "true",
        "LAP_COMPLETED": "true",
        "RESULTS_PATH": "true",
        "COURSE_ACCEPTED": "false",
        "DEVICE_RUN": "false",
        "RACE_STATE": "3",
        "DRIVEN_MSEC": "87000",
        "LAP_COUNT": "3",
    }
    fields.update(overrides)
    lines = ["COURSE_OBSERVE_BEGIN", "TRACK_ID=%s" % track_id]
    for key, value in fields.items():
        lines.append("%s=%s" % (key, value))
    lines.append("COURSE_OBSERVE_END")
    return "\n".join(lines)


def _all_courses(**by_id: dict[str, str]) -> str:
    return "\n".join(_course_block(course_id, **by_id.get(course_id, {})) for course_id in LAUNCH_COURSE_IDS)


if __name__ == "__main__":
    unittest.main()
