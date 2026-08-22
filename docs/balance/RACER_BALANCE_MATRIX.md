# Racer Balance Matrix — Wave010 (digital)

Digital balance only. Does **not** claim HUMAN_PLAYTEST or esports fairness.

| Racer | Class | Strengths | Weaknesses | Favored mechanics | Risk | Counterplay |
|-------|-------|-----------|------------|-------------------|------|-------------|
| Dash Reed | all_terrain | Balanced stats, clean_lines hold | No peak niche | Lines, drafting, mid-pack | Low | Pressure corners; deny draft |
| Nova Quill | sprinter | Top speed, launch_burst | Weak handling/drift | Straights, perfect start | High if corner-heavy | Force technical sections |
| Sierra Flux | parkour | Wall_read, air routes | Mid speed | Wall kick, rails, bounce | Medium | Deny rails; ground race |
| Mira Lane | endurance | Tempo hold, drift control | Soft accel | Long races, coast mastery | Low | Burst early; item disrupt |
| Bolt Harbor | uphill | Shoulder_drive, slow resist | Low top speed | Contested packs, soft ground | Medium | Keep open asphalt |
| Zig Riven | trick | Style→boost, air game | Average ground grip | Jump/trick chains | High | Keep grounded; stomp disrupt |
| Solen Pike | cornering | Apex drift, handling king | Soft straight speed | Drift spark economy | Medium | Stretch straights |
| Kai Volt | kinetic | Kinetic flare boost chain | Average elsewhere | Boost chaining windows | Medium | Force cooldown windows |

## Footwear interaction

Shoe surface affinities multiply terrain speed/accel/drift grip. No universal shoe; hard plates hate mud, soft soles hate ice tradeoffs — see `data/shoes/*.json`.

## Dominance guard (digital)

- Nova leads top_speed but loses handling to Solen.
- Solen leads drift/handling but not top_speed.
- Seeded CompetitiveAiEval + Wave010 comeback eval must not show forced finish orders.

`HUMAN_COMPETITIVE_BALANCE = false` until human playtest.
