# Race Experience Audit V3

Baseline: live PR #34 `1413997a2146b5cf2401839a3cbd7257b809ea5b`.
This is the pre-implementation journey audit. Running is not the same as feeling complete.

Classifications: `CLEAR` · `FUNCTIONAL_BUT_FLAT` · `CONFUSING` · `MISSING` · `BROKEN`

## Journey

| Moment | Class | Why |
|---|---|---|
| Main menu | CLEAR | Modes, a11y, Comfort / Dynamic / Reduced Motion picker. |
| Course selection | FUNCTIONAL_BUT_FLAT | Names and palette only. No landmark memory or route rhythm preview. |
| Runner selection | CLEAR | AA guests and authored runner profiles. |
| Countdown | CONFUSING | Two tick sources, HUD intro overlap, `GO!` vs `GO`. |
| GO | FUNCTIONAL_BUT_FLAT | Movement stays locked until `enable_movement`. GO is not a clear event. |
| First 10 seconds | FUNCTIONAL_BUT_FLAT | Chase FOV works. HUD dumps footwear, GPS, drift sparks, speed telemetry. |
| First turn | FUNCTIONAL_BUT_FLAT | Camera anticipates. Player has no next-turn or shortcut cue. |
| Opponent interaction | FUNCTIONAL_BUT_FLAT | Place pulse only. Nearby / draft target / pass-from-behind stay weak. |
| Shortcut decision | FUNCTIONAL_BUT_FLAT | Physical 8/8 rules hold. Telegraph is late color/text, not SEE→CHOOSE→EXECUTE. |
| Drafting | CONFUSING | Cone math exists. Enter / build / active / leave are silent. |
| Boost | FUNCTIONAL_BUT_FLAT | Meter + FOV pulse. Not a bounded event with presentation start/stop proof. |
| Lap / checkpoint | FUNCTIONAL_BUT_FLAT | Lap counter only. No confirmation, final-lap, or finish approach. |
| Final stretch | MISSING | Last lap does not change the world or HUD. |
| Finish | FUNCTIONAL_BUT_FLAT | Overlay + results. Short celebration already. Weak drama. |
| Results / retry | FUNCTIONAL_BUT_FLAT | Retry / next / return exist. No real-event highlights. No invented ranks. |

## Inherited truths to keep

Camera direction and smoothness from #34 stay. Do not restore randf shake, unsmoothed `look_at`, rail/deck SpringArm pops, cadence vibration, or boost-hold vibration.

Shortcut physical / lap rules from #33 stay 8/8.

## V3 intent

Make start, speed, draft, boost, opponents, shortcuts, course identity, and finish readable without substituting constant shake for game feel.
