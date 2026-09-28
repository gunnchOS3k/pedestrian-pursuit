# Pedestrian Pursuit — PartyLink Product Flow (8P V2)

## Decision
2–8 human racers. AI fillers optional only when host explicitly selects them.
Spectators never consume a player seat.

## Authority
Race host owns physics, position, laps, shortcuts, collisions, finish, results.
Controllers send semantic input only (touch steer / accel / brake / boost / trick / a11y auto-accel).

## Race Director View
Lead-pack framing, close battles, finish-line camera, optional overhead/map insert,
standings 1–8, gaps, lap/final-lap, results.

## V1 network
Same-room/LAN. `PARTYLINK_PUBLIC_RELAY_PASS=false` until hosted relay is deployed.

## Productization closure (V1 end-to-end)

- UI: Main Menu → Party Race (2–8 LAN) → Lobby / Race Director → RaceScene
- Controller: `python3 -m scripts.net.partylink.lan_host` → `/controller`
- RaceScene spawns N human racers on StartGrid8 when `GameManager.is_party_race()`
- E2E: `tests/partylink/test_partylink_productization_e2e.py` (2/4/6/8)
- Gates: `artifacts/partylink/PARTYLINK_PRODUCTIZATION_GATE_STATUS.json`
- Human taste / public relay remain false
