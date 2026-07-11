from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_content import validate_project  # noqa: E402


class CupContentTests(unittest.TestCase):
    def test_all_course_content_is_valid(self) -> None:
        self.assertEqual(validate_project(ROOT), [])

    def test_cup_order_is_intentional(self) -> None:
        cup = json.loads((ROOT / "data/cups/sole_surge_cup.json").read_text(encoding="utf-8"))
        self.assertEqual(
            cup["track_ids"],
            [
                "verdant_cascade_circuit",
                "cloverwind_ranch",
                "prism_apex",
                "emberkeep_gauntlet",
            ],
        )

    def test_shipped_course_identity_is_original(self) -> None:
        protected_names = ("mario", "yoshi", "moo moo", "rainbow road", "bowser", "nintendo")
        for path in (ROOT / "data").glob("**/*.json"):
            content = path.read_text(encoding="utf-8").lower()
            for protected_name in protected_names:
                self.assertNotIn(protected_name, content, f"{protected_name!r} found in {path}")


if __name__ == "__main__":
    unittest.main()
