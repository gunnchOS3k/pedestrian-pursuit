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
