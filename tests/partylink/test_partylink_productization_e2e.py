#!/usr/bin/env python3
"""Browser multi-client PartyLink E2E for Pedestrian (LAN host, no public relay)."""

from __future__ import annotations

import json
import sys
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "net"))

from partylink.lan_host import start_lan_host  # noqa: E402
from partylink.party_room import start_grid_slots  # noqa: E402


def _post(base: str, path: str, body: dict) -> dict:
    req = urllib.request.Request(
        base + path,
        data=json.dumps(body).encode("utf-8"),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as res:
        return json.loads(res.read().decode("utf-8"))


def _get(base: str, path: str) -> dict | str:
    with urllib.request.urlopen(base + path, timeout=5) as res:
        raw = res.read().decode("utf-8")
        if "application/json" in (res.headers.get("content-type") or ""):
            return json.loads(raw)
        return raw


def run_e2e(player_count: int) -> dict:
    server, state = start_lan_host(port=0, max_players=player_count)
    port = server.server_address[1]
    base = f"http://127.0.0.1:{port}"
    try:
        health = _get(base, "/health")
        assert health["ok"] and health["public_relay"] is False
        html = _get(base, "/controller")
        assert "Party Race Controller" in html
        code = state.room.code
        players = []
        for i in range(player_count):
            join = _post(base, "/join", {"code": code, "display_name": f"R{i+1}", "role": "PLAYER"})
            assert join["ok"], join
            p = join["participant"]
            players.append(p)
            _post(base, "/ready", {"participant_id": p["id"], "token": p["token"], "ready": True})
        seats = {p["seat_index"] for p in players}
        unique_seats = len(seats) == player_count
        early_spec = _post(base, "/join", {"code": code, "display_name": "Spec", "role": "SPECTATOR"})
        owner = next(x for x in state.room.participants if x.id == state.room.owner_id)
        start = _post(base, "/start", {"owner_token": owner.token})
        assert start["ok"], start
        racer_entities = int(start.get("racer_entity_count", 0))
        grid_ok = int(start.get("start_grid_slots", 0)) == player_count == len(start_grid_slots(player_count))

        ownership_ok = True
        for p in players:
            ok = _post(
                base,
                "/input",
                {
                    "participant_id": p["id"],
                    "token": p["token"],
                    "seat_index": p["seat_index"],
                    "sequence": 1,
                    "semantic": {"steer": 0.2, "accelerate": True},
                },
            )
            if not ok.get("accepted"):
                ownership_ok = False
            wrong = _post(
                base,
                "/input",
                {
                    "participant_id": p["id"],
                    "token": p["token"],
                    "seat_index": (p["seat_index"] + 1) % player_count,
                    "sequence": 2,
                    "semantic": {"boost": True},
                },
            )
            if wrong.get("accepted"):
                ownership_ok = False

        if early_spec.get("ok"):
            sp = early_spec["participant"]
            rejected = _post(
                base,
                "/input",
                {
                    "participant_id": sp["id"],
                    "token": sp["token"],
                    "seat_index": 0,
                    "sequence": 1,
                    "semantic": {"accelerate": True},
                },
            )
            if rejected.get("accepted"):
                ownership_ok = False

        # reconnect
        victim = players[0]
        state.room.disconnect(victim["id"])
        recon = _post(base, "/reconnect", {"code": code, "token": victim["token"]})
        late_spec = _post(base, "/join", {"code": code, "display_name": "Late", "role": "SPECTATOR"})
        rematch = _post(base, "/rematch", {"owner_token": owner.token})
        director_ok = state.director.hud_ok(player_count) or (state.sim and state.sim.get("race_director_hud_ok"))

        pass_ = (
            unique_seats
            and ownership_ok
            and start.get("ok")
            and racer_entities == player_count
            and grid_ok
            and recon.get("ok")
            and late_spec.get("ok")
            and rematch.get("ok")
            and early_spec.get("ok")
            and bool(director_ok)
        )
        return {
            "player_count": player_count,
            "unique_seats": unique_seats,
            "unique_input_ownership": ownership_ok,
            "start_ok": bool(start.get("ok")),
            "racer_entity_count": racer_entities,
            "start_grid_ok": grid_ok,
            "reconnect_ok": bool(recon.get("ok")),
            "late_spectator_ok": bool(late_spec.get("ok")),
            "rematch_ok": bool(rematch.get("ok")),
            "race_director_live_ok": bool(director_ok),
            "controller_html_ok": "Party Race Controller" in html,
            "pass": pass_,
            "room_code": code,
            "controller_url": f"{base}/controller",
        }
    finally:
        server.shutdown()


class PartyLinkProductizationE2E(unittest.TestCase):
    def test_2_4_6_8_e2e(self):
        results = []
        for n in (2, 4, 6, 8):
            with self.subTest(n=n):
                r = run_e2e(n)
                self.assertTrue(r["pass"], r)
                results.append(r)
        out = ROOT / "artifacts" / "partylink" / "PARTYLINK_BROWSER_E2E_MATRIX.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"generated": True, "results": results}, indent=2) + "\n")


if __name__ == "__main__":
    unittest.main()
