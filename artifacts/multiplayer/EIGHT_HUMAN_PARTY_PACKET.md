# Eight-human PartyLink packet (prepare-only)

**Status:** `PHYSICAL_EIGHT_HUMAN_PARTY = false` — packet prepared, not executed.

## Honesty matrix (keep distinct)

| Layer | Meaning | Claimed here |
| --- | --- | --- |
| Independent 2-client | Gate1 host+guest race | Proven separately (PP-RTM-06) — not this packet |
| Allocated seats | Lobby capacity 2–8 | Digital contract yes |
| Connected humans | Real present players/devices | Must not invent; local field observe uses 1 |
| CPU fill | Non-connected field seats | Yes — bots ≠ humans |
| Physical 8-human PartyLink | Eight real bodies finish | **false / not executed** |
| Mac Metal / MoltenVK | Display-backed Metal | **false / not claimed** |

## Seat honesty (digital)

| Field | Value |
| --- | --- |
| Allocated human seats | 2–8 (clamped) |
| Field size | 8 |
| Connected humans | ≤ allocated; never invented |
| CPU fill | remaining seats |
| Bots count as humans | **false** |
| BeatLink sibling contract | **2 humans** (host+guest) |
| COURSE_ACCEPTED / HUMAN / RC2 / V1 | **false** |

Contract source: `scripts/net/OnlineArchitecture.gd` (`partylink_seat_map` + `partylink_runtime_roster`) + `tests/PartyLinkCapacityTest.gd` + `tests/EightRacerFieldObserve.gd`.

## Required human session (owner / QA — not agent-fabricated)

1. Eight real players (or devices) join one PartyLink room.
2. Confirm seat map: `connected_humans == 8`, `cpu_seats == 0`, no bot mislabeled as human.
3. Complete one full race; capture lobby screenshot + finish standings + session log.
4. Store under `artifacts/multiplayer/human_8p/` privately; do not invent participants.

## Explicit non-claims

- Not a MoltenVK/Metal pass.
- Not HUMAN_FUN / HUMAN_COURSE / RC2 / V1 authorization.
- Not BeatLink 8-member — BeatLink sibling stays 2.
- Eight CPU-filled actors ≠ eight humans.

## S6 digital independence note

- Independent two-process BeatLink sibling race restored via `contracts/beatlink_sibling_rooms` (BeatLink repo not edited): **2 digital clients**, not 8 humans.
- PartyLink field observe remains honest **1 connected human + 7 CPU** until additional independent clients are present.
- Bots ≠ humans. Physical 8-human PartyLink still **false / not executed**.

## S7 ownership advance

- Dual connected PartyLink observe (`tests/DualConnectedPartyLinkObserve.gd`): **2 humans + 6 CPU** on allocated-8 field.
- Still bots≠humans; BeatLink sibling max local extras = 2; physical 8p **false**.
- Independent two-process remains a separate GAME_SESSION_DIR artifact.
