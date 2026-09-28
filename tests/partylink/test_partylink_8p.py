#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "net"))

from partylink.capacity import CAPACITY_LADDER, MAX_PLAYER_SEATS, MAX_SPECTATOR_SEATS, MIN_PLAYER_SEATS
from partylink.party_room import PartyRoom, simulate_host_race, start_grid_slots


class PartyLinkCapacityTests(unittest.TestCase):
    def test_spectator_capacity_separate(self):
        self.assertEqual(MIN_PLAYER_SEATS, 2)
        self.assertEqual(MAX_PLAYER_SEATS, 8)
        self.assertGreater(MAX_SPECTATOR_SEATS, MAX_PLAYER_SEATS)
        room = PartyRoom.create("Host", max_players=8)
        for i in range(8):
            res = room.join(f"P{i}", "PLAYER")
            self.assertTrue(res["ok"], i)
        full = room.join("P9", "PLAYER")
        self.assertFalse(full["ok"])
        self.assertEqual(full["reason"], "player_seats_full")
        spec = room.join("Watcher", "SPECTATOR")
        self.assertTrue(spec["ok"])
        snap = room.capacity_snapshot()
        self.assertEqual(snap["player_seats_used"], 8)
        self.assertEqual(snap["spectator_seats_used"], 1)
        self.assertTrue(snap["spectator_separate"])

    def test_authz_rejects_spectator_and_wrong_seat(self):
        room = PartyRoom.create("Host", max_players=4)
        p0 = room.join("A", "PLAYER")
        p1 = room.join("B", "PLAYER")
        spec = room.join("S", "SPECTATOR")
        self.assertTrue(p0["ok"] and p1["ok"] and spec["ok"])
        room.set_ready(p0["participant"].id, p0["participant"].token, True)
        room.set_ready(p1["participant"].id, p1["participant"].token, True)
        owner = next(x for x in room.participants if x.id == room.owner_id)
        self.assertTrue(room.start(owner.token)["ok"])
        wrong = room.submit_input(
            p0["participant"].id,
            p0["participant"].token,
            p1["participant"].seat_index,
            1,
            {"steer": -0.2},
        )
        self.assertFalse(wrong["accepted"])
        self.assertEqual(wrong["reason"], "wrong_seat_input_rejected")
        bad = room.submit_input(spec["participant"].id, spec["participant"].token, 0, 1, {"steer": 1})
        self.assertFalse(bad["accepted"])
        self.assertEqual(bad["reason"], "spectator_input_rejected")
        forged = room.submit_input(
            p0["participant"].id,
            p0["participant"].token,
            p0["participant"].seat_index,
            1,
            {"lap_complete": True},
        )
        self.assertFalse(forged["accepted"])
        self.assertEqual(forged["reason"], "client_cannot_self_report")
        ok = room.submit_input(
            p0["participant"].id,
            p0["participant"].token,
            p0["participant"].seat_index,
            1,
            {"steer": 0.1, "accelerate": True},
        )
        self.assertTrue(ok["accepted"])

    def test_reconnect(self):
        room = PartyRoom.create("Host", max_players=2)
        p0 = room.join("A", "PLAYER")
        self.assertTrue(p0["ok"])
        room.disconnect(p0["participant"].id)
        self.assertEqual(room.seats[p0["participant"].seat_index].state, "DISCONNECTED_RECONNECTABLE")
        back = room.join("A", "PLAYER", resume_token=p0["participant"].token)
        self.assertTrue(back["ok"])
        self.assertEqual(room.seats[p0["participant"].seat_index].state, "CONNECTED")


class CapacityLadderTests(unittest.TestCase):
    def test_ladder_2_4_6_8(self):
        results = []
        for n in CAPACITY_LADDER:
            with self.subTest(n=n):
                grid = start_grid_slots(n)
                self.assertEqual(len(grid), n)
                metrics = simulate_host_race(n)
                self.assertTrue(metrics["pass"], metrics)
                self.assertTrue(metrics["race_director_hud_ok"])
                self.assertEqual(metrics["desync_count"], 0)
                results.append(metrics)
        out = ROOT / "artifacts" / "partylink" / "PARTYLINK_MULTI_CLIENT_MATRIX.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"generated": True, "tiers": results}, indent=2) + "\n")


if __name__ == "__main__":
    unittest.main()
