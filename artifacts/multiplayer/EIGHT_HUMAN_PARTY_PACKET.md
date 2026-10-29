# Eight-human PartyLink packet (prepare-only)

**Status:** `PHYSICAL_EIGHT_HUMAN_PARTY = false` — packet prepared, not executed.

## Seat honesty (digital)

| Field | Value |
| --- | --- |
| Human seats | 2–8 (clamped) |
| Field size | 8 |
| CPU fill | remaining seats |
| Bots count as humans | **false** |
| BeatLink sibling contract | **2 humans** (host+guest) |
| Independent 2-client race | proven (Gate1 / local headless) |
| Physical 8-human party | **not claimed** |

Contract source: `scripts/net/OnlineArchitecture.gd` + `tests/PartyLinkCapacityTest.gd`.

## Required human session (owner / QA — not agent-fabricated)

1. Eight real players (or devices) join one PartyLink room.
2. Confirm seat map: `human_seats == 8`, `cpu_seats == 0`, no bot mislabeled as human.
3. Complete one full race; capture lobby screenshot + finish standings + session log.
4. Store under `artifacts/multiplayer/human_8p/` privately; do not invent participants.

## Explicit non-claims

- Not a MoltenVK/Metal pass.
- Not HUMAN_FUN / HUMAN_COURSE / RC2 / V1 authorization.
- Not BeatLink 8-member — BeatLink sibling stays 2.
