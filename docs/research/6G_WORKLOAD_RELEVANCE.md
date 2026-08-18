# 6G workload relevance — Pedestrian Pursuit

This product is a **game / interactive workload**, not a RAN research result.

The notes below describe **measurable latency, QoE, and traffic characteristics** a lab could observe if this client ran on an instrumented link. They are **not** a 6G dissertation contribution, not a beam-selection result, and not evidence for research questions in the telecom spine.


## What this client is

Local 3D arcade foot-racer (Godot 4.5, GL Compatibility) with cup, AI, items, and optional Android export. Online architecture scripts are stubs, not a live cellular stack.

## Measurable characteristics (lab, if instrumented)

| Quantity | Where it lives | Typical digital observation |
|---|---|---|
| Race tick / FPS | `scripts/core/PerfBudget.gd`, debug overlay | Desktop budget 60 FPS; Android mid-tier budget 30 FPS (not device-certified) |
| Checkpoint events | `scripts/core/TelemetryBus.gd` | Local JSONL, no PII |
| Item warning lead | `scripts/items/ItemManager.gd` | ~0.35 s lace-trap warning |
| Touch + assist | `scripts/ui/MobileControls.gd`, `GameManager.mobile_assist_steer` | Extra input path vs keyboard |
| Package | `com.gunnchos.pedestrianpursuit` | Distinct from other games |

QoE is “did I hit the checkpoint / item / recovery,” not RAN KPI.

## What this is not

- Not a 6G mobility or beam-management result
- Not Pixel 6a PASS while adb is unauthorized
- Device FPS certification remains `PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING`
