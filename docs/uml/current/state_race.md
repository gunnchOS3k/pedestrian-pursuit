# State machine — race (current)

```mermaid
stateDiagram-v2
  [*] --> WAITING
  WAITING --> COUNTDOWN: begin_countdown
  COUNTDOWN --> RACING: GO
  RACING --> FINISHED: last lap / all finished
  FINISHED --> [*]
```

Racer locomotion SM (separate): GROUNDED / AIR / SLIDE / DRIFT / STOMP in `RacerStateMachine.gd`. Race flow: `RaceManager.RaceState` in `scripts/race/RaceManager.gd`.
