#!/usr/bin/env python3
"""Pedestrian PartyLink LAN join host (V1 same-room/LAN — no public relay claim)."""

from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from .party_room import PartyRoom, RaceDirectorView, simulate_host_race, start_grid_slots

CONTROLLER_HTML = """<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>PP PartyLink Controller</title>
<style>
body{margin:0;font-family:system-ui;background:#0b1220;color:#f4f7ff;padding:1rem}
button{min-height:3rem;margin:.25rem;padding:.7rem 1rem;border-radius:12px;border:0;background:#5eead4;color:#042f2e;font-weight:700}
input,select{width:100%;padding:.65rem;margin:.3rem 0;border-radius:10px;border:1px solid #334155;background:#0f172a;color:#fff}
.pad{display:grid;grid-template-columns:repeat(3,1fr);gap:.4rem}
.pad button{background:#1e293b;color:#fff}
</style></head><body>
<h1>Party Race Controller</h1>
<p id="status">Not connected</p>
<label>Room code<input id="code" value="__CODE__"/></label>
<label>Name<input id="name" value="Racer"/></label>
<label>Role<select id="role"><option>PLAYER</option><option>SPECTATOR</option></select></label>
<button id="join">Join</button>
<div id="play" style="display:none">
<button id="ready">Ready</button>
<div class="pad">
<button data-a="steerLeft">Steer L</button><button data-a="steerRight">Steer R</button>
<button data-a="accel">Accel</button><button data-a="brake">Brake</button>
<button data-a="boost">Boost</button><button data-a="trick">Trick</button>
</div>
<label><input type="checkbox" id="auto"/> Auto-accel</label>
<button id="recon">Reconnect</button>
</div>
<script>
let session=null,seq=0;
const S=document.getElementById('status');
async function api(p,b){const r=await fetch(p,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(b)});return r.json()}
document.getElementById('join').onclick=async()=>{
  const code=document.getElementById('code').value.trim().toUpperCase();
  const display_name=document.getElementById('name').value||'Racer';
  const role=document.getElementById('role').value;
  const out=await api('/join',{display_name,role,code});
  if(!out.ok){S.textContent='Fail '+out.reason;return}
  session=out; localStorage.setItem('pp.partylink.resume',JSON.stringify({code,token:out.participant.token}));
  S.textContent=role+' seat '+(out.participant.seat_index??'—'); document.getElementById('play').style.display='block';
};
document.getElementById('ready').onclick=async()=>{
  if(!session)return;
  await api('/ready',{participant_id:session.participant.id,token:session.participant.token,ready:true});
  S.textContent='READY';
};
document.getElementById('recon').onclick=async()=>{
  const raw=localStorage.getItem('pp.partylink.resume'); if(!raw)return;
  const s=JSON.parse(raw); const out=await api('/reconnect',s);
  if(out.ok){session=out;S.textContent='Reconnected';}
};
document.querySelectorAll('.pad button').forEach(btn=>{
  btn.onpointerdown=()=>{ if(!session||session.participant.role==='SPECTATOR')return; seq++;
    api('/input',{participant_id:session.participant.id,token:session.participant.token,
      seat_index:session.participant.seat_index,sequence:seq,semantic:{[btn.dataset.a]:true}});
  };
});
document.getElementById('auto').onchange=e=>{ if(!session)return; seq++;
  api('/input',{participant_id:session.participant.id,token:session.participant.token,
    seat_index:session.participant.seat_index,sequence:seq,semantic:{auto_accel:e.target.checked}});
};
</script></body></html>
"""


class LanPartyState:
    def __init__(self, owner_name: str = "Host", max_players: int = 8):
        self.room = PartyRoom.create(owner_name, max_players=max_players)
        self.director = RaceDirectorView()
        self.sim: dict[str, Any] | None = None
        self.lock = threading.Lock()


def make_handler(state: LanPartyState):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args) -> None:  # noqa: A003
            return

        def _json(self, code: int, body: Any) -> None:
            raw = json.dumps(body).encode("utf-8")
            self.send_response(code)
            self.send_header("content-type", "application/json")
            self.send_header("access-control-allow-origin", "*")
            self.send_header("content-length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def _html(self, html: str) -> None:
            raw = html.encode("utf-8")
            self.send_response(200)
            self.send_header("content-type", "text/html; charset=utf-8")
            self.send_header("access-control-allow-origin", "*")
            self.send_header("content-length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_OPTIONS(self) -> None:  # noqa: N802
            self.send_response(204)
            self.send_header("access-control-allow-origin", "*")
            self.send_header("access-control-allow-methods", "GET,POST,OPTIONS")
            self.send_header("access-control-allow-headers", "content-type")
            self.end_headers()

        def do_GET(self) -> None:  # noqa: N802
            path = urlparse(self.path).path
            if path in ("/", "/controller"):
                html = CONTROLLER_HTML.replace("__CODE__", state.room.code)
                self._html(html)
                return
            if path == "/room":
                self._json(200, {"code": state.room.code, "phase": state.room.phase, "seats": [
                    {"seat": s.seat_index, "state": s.state, "name": s.display_name} for s in state.room.seats
                ], "spectators": len(state.room.spectators), "public_relay": False})
                return
            if path == "/health":
                self._json(200, {"ok": True, "public_relay": False, "code": state.room.code, "transport": "LAN"})
                return
            if path == "/state":
                self._json(200, {"phase": state.room.phase, "sim": state.sim, "director": {
                    "mode": state.director.mode, "standings": state.director.standings
                }})
                return
            self._json(404, {"ok": False, "reason": "not_found"})

        def do_POST(self) -> None:  # noqa: N802
            length = int(self.headers.get("content-length", "0"))
            body = json.loads(self.rfile.read(length) or b"{}")
            path = urlparse(self.path).path
            with state.lock:
                if path == "/join":
                    if body.get("code") and str(body["code"]).upper() != state.room.code:
                        self._json(400, {"ok": False, "reason": "bad_code"})
                        return
                    out = state.room.join(body.get("display_name", "Racer"), body.get("role", "PLAYER"), body.get("resume_token"))
                    if out.get("ok"):
                        p = out["participant"]
                        out = {
                            "ok": True,
                            "participant": {
                                "id": p.id,
                                "token": p.token,
                                "seat_index": p.seat_index,
                                "role": p.role,
                                "display_name": p.display_name,
                            },
                        }
                    self._json(200 if out.get("ok") else 400, out)
                    return
                if path == "/reconnect":
                    out = state.room.join("rejoin", "PLAYER", resume_token=body.get("token"))
                    if out.get("ok"):
                        p = out["participant"]
                        out = {"ok": True, "participant": {"id": p.id, "token": p.token, "seat_index": p.seat_index, "role": p.role}}
                    self._json(200 if out.get("ok") else 400, out)
                    return
                if path == "/ready":
                    self._json(200, state.room.set_ready(body["participant_id"], body["token"], bool(body.get("ready", True))))
                    return
                if path == "/start":
                    owner = next(x for x in state.room.participants if x.id == state.room.owner_id)
                    start = state.room.start(body.get("owner_token", owner.token))
                    if start.get("ok"):
                        n = sum(1 for s in state.room.seats if s.participant_id)
                        state.sim = simulate_host_race(n if n in (2, 4, 6, 8) else 8)
                        state.director.update(
                            [{"seat": i, "name": f"R{i+1}", "lap": 1, "progress": 0.1 * (i + 1)} for i in range(n)],
                            total_laps=3,
                        )
                        start["racer_entity_count"] = n
                        start["start_grid_slots"] = len(start_grid_slots(n))
                    self._json(200 if start.get("ok") else 400, start)
                    return
                if path == "/input":
                    ack = state.room.submit_input(
                        body["participant_id"],
                        body["token"],
                        int(body["seat_index"]),
                        int(body["sequence"]),
                        body.get("semantic") or {},
                    )
                    self._json(200, ack)
                    return
                if path == "/rematch":
                    owner = next(x for x in state.room.participants if x.id == state.room.owner_id)
                    for seat in state.room.seats:
                        if seat.participant_id:
                            seat.state = "CONNECTED"
                    state.room.phase = "lobby"
                    state.sim = None
                    self._json(200, {"ok": True})
                    return
            self._json(404, {"ok": False, "reason": "not_found"})

    return Handler


def start_lan_host(host: str = "0.0.0.0", port: int = 0, max_players: int = 8) -> tuple[ThreadingHTTPServer, LanPartyState]:
    state = LanPartyState(max_players=max_players)
    server = ThreadingHTTPServer((host, port), make_handler(state))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, state


if __name__ == "__main__":
    srv, st = start_lan_host(port=8791)
    addr = srv.server_address
    print(json.dumps({
        "url": f"http://127.0.0.1:{addr[1]}",
        "controller": f"http://127.0.0.1:{addr[1]}/controller",
        "code": st.room.code,
        "public_relay": False,
    }, indent=2))
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        srv.shutdown()
