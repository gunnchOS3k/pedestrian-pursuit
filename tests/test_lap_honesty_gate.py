"""Gate 1 / independent-client race evidence must reject disagreeing finished laps."""

from __future__ import annotations

import unittest


def independent_clients_raced(produced: dict) -> tuple[bool, str]:
    """Mirrors tools/game_session_two_client.mjs publish lap honesty checks."""
    laps = produced.get("lapsCompleted") or {}
    host_laps = int(laps.get("host") or 0)
    guest_laps = int(laps.get("guest") or 0)
    expected = int(produced.get("expectedLaps") or 0)
    laps_equal = host_laps == guest_laps and produced.get("lapsEqual", True) is not False
    laps_complete = (
        host_laps == expected and guest_laps == expected
        if expected > 0
        else (host_laps > 0 and guest_laps > 0 and laps_equal)
    )
    both_humans = produced.get("hostFinished") is True and produced.get("guestFinished") is True
    ok = (
        produced.get("bothFinished") is True
        and both_humans
        and laps_equal
        and laps_complete
        and produced.get("courseAiIsGuest") is False
        and produced.get("guestSeat") == "Player2Racer"
        and produced.get("guestControl") == "guest-process"
        and produced.get("hostControl") == "host-process"
    )
    reason = ""
    if not ok:
        if not laps_equal:
            reason = f"lap counts disagree host={host_laps} guest={guest_laps} expected={expected}"
        elif not laps_complete:
            reason = f"finished laps incomplete host={host_laps} guest={guest_laps} expected={expected}"
        else:
            reason = str(produced.get("failReason") or "independent race evidence incomplete")
    return ok, reason


BASE = {
    "bothFinished": True,
    "hostFinished": True,
    "guestFinished": True,
    "expectedLaps": 3,
    "lapsEqual": True,
    "lapsCompleted": {"host": 3, "guest": 3},
    "courseAiIsGuest": False,
    "guestSeat": "Player2Racer",
    "guestControl": "guest-process",
    "hostControl": "host-process",
}


class LapHonestyGateTest(unittest.TestCase):
    def test_equal_finished_laps_pass(self) -> None:
        ok, reason = independent_clients_raced(BASE)
        self.assertTrue(ok, reason)

    def test_host_two_guest_three_is_false_green(self) -> None:
        produced = dict(BASE)
        produced["lapsCompleted"] = {"host": 2, "guest": 3}
        produced["lapsEqual"] = False
        produced["bothFinished"] = True  # previously false-green if only >=1 required
        ok, reason = independent_clients_raced(produced)
        self.assertFalse(ok)
        self.assertIn("disagree", reason)

    def test_results_with_unequal_but_both_ge_one_fail(self) -> None:
        produced = dict(BASE)
        produced["lapsCompleted"] = {"host": 1, "guest": 2}
        produced["lapsEqual"] = False
        ok, reason = independent_clients_raced(produced)
        self.assertFalse(ok)
        self.assertIn("disagree", reason)

    def test_incomplete_equal_laps_fail(self) -> None:
        produced = dict(BASE)
        produced["lapsCompleted"] = {"host": 2, "guest": 2}
        ok, reason = independent_clients_raced(produced)
        self.assertFalse(ok)
        self.assertIn("incomplete", reason)

    def test_missing_human_finished_flags_fail(self) -> None:
        produced = dict(BASE)
        produced["guestFinished"] = False
        ok, _reason = independent_clients_raced(produced)
        self.assertFalse(ok)


if __name__ == "__main__":
    unittest.main()
