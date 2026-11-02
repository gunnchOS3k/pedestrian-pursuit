"""Negative-path proof: Wave010 PASS markers cannot false-green failed runs."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.engineering_wave010.classify_wave010_run import classify_wave010_run  # noqa: E402


OBJECTDB = (
    "ERROR: 2 resources still in use at exit (run with --verbose for details).\n"
    "ObjectDB instances leaked at exit (run with --verbose for details).\n"
)


class Wave010RunClassifierTest(unittest.TestCase):
    def test_clean_e2e_pass_exit0(self) -> None:
        log = "Wave010RaceSceneE2E PASS\nCANONICAL_RACE_SCENE_EXECUTED=true\n"
        v = classify_wave010_run("wave010_racescene_e2e", 0, log)
        self.assertTrue(v.ok)
        self.assertEqual(v.kind, "PASS")

    def test_objectdb_after_clean_pass_is_legitimate_shutdown(self) -> None:
        log = "Wave010RaceSceneE2E PASS\n" + OBJECTDB
        v = classify_wave010_run("wave010_racescene_e2e", 1, log)
        self.assertTrue(v.ok, v.reason)
        self.assertEqual(v.kind, "PASS_OBJECTDB_SHUTDOWN")

    def test_pass_marker_does_not_override_script_error(self) -> None:
        log = (
            "Wave010RaceSceneE2E PASS\n"
            "SCRIPT ERROR: Invalid call. Nonexistent function.\n"
            + OBJECTDB
        )
        v = classify_wave010_run("wave010_racescene_e2e", 1, log)
        self.assertFalse(v.ok)
        self.assertEqual(v.kind, "FAIL")
        self.assertIn("does not override", v.reason)

    def test_pass_marker_does_not_override_explicit_fail(self) -> None:
        log = (
            "Wave010RaceSceneE2E PASS\n"
            "Wave010RaceSceneE2E FAIL count=1\n"
            "FAIL: no real lap increment observed\n"
        )
        v = classify_wave010_run("wave010_racescene_e2e", 1, log)
        self.assertFalse(v.ok)
        self.assertEqual(v.kind, "FAIL")

    def test_pass_marker_does_not_override_uncharacterized_nonzero(self) -> None:
        log = "Wave010RaceSceneE2E PASS\nsegfault-ish crash without ObjectDB lines\n"
        v = classify_wave010_run("wave010_racescene_e2e", 139, log)
        self.assertFalse(v.ok)
        self.assertIn("PASS marker does not override", v.reason)

    def test_malformed_exit0_without_pass_cannot_pass(self) -> None:
        log = "Godot Engine started\n(no suite marker)\n"
        v = classify_wave010_run("wave010_racescene_e2e", 0, log)
        self.assertFalse(v.ok)
        self.assertIn("malformed", v.reason)

    def test_mastery_script_error_with_pass_cannot_pass(self) -> None:
        log = "Wave010TimeTrialMasteryE2E PASS\nParse Error: Unexpected token\n"
        v = classify_wave010_run("wave010_time_trial_mastery", 0, log)
        self.assertFalse(v.ok)

    def test_runtime_fail_cannot_pass(self) -> None:
        log = "Wave010RuntimeTest FAIL count=2\nFAIL: drift failed\n"
        v = classify_wave010_run("wave010_component_runtime", 1, log)
        self.assertFalse(v.ok)

    def test_generic_import_nonzero_fails(self) -> None:
        v = classify_wave010_run("import", 1, "import noise\n")
        self.assertFalse(v.ok)

    def test_generic_import_clean_passes(self) -> None:
        v = classify_wave010_run("import", 0, "imported ok\n")
        self.assertTrue(v.ok)

    def test_historical_false_green_pass_beats_exit_rejected(self) -> None:
        """Regression: pre-fix run_wave010.sh treated any PASS as success."""
        # Simulated: PASS printed, then SCRIPT ERROR, nonzero exit, no ObjectDB.
        log = (
            "Wave010RuntimeTest PASS\n"
            "SCRIPT ERROR: Identifier not found: Boom\n"
        )
        v = classify_wave010_run("wave010_component_runtime", 1, log)
        self.assertFalse(v.ok)
        self.assertEqual(v.kind, "FAIL")


if __name__ == "__main__":
    unittest.main()
