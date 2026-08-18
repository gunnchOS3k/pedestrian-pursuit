# Class — racer / course (current)

```mermaid
classDiagram
  class RacerData {
    +load_by_id(id)
    +all_launch_ids()
  }
  class TrackCatalog {
    +load_cup(id)
    +list_all_track_ids()
  }
  class CourseTrack {
    +build from JSON path_points
  }
  class PlayerController {
    +horizontal_speed
  }
  class RacerStateMachine {
    +State current_state
  }
  class AIRacerController {
    +follow path
  }
  PlayerController --> RacerStateMachine
  PlayerController --> RacerData
  CourseTrack --> TrackCatalog
  AIRacerController --> TrackCatalog
```

`scripts/data/RacerData.gd`, `TrackCatalog.gd`, `scripts/tracks/CourseTrack.gd`, `scripts/player/PlayerController.gd`, `RacerStateMachine.gd`, `scripts/ai/AIRacerController.gd`.
