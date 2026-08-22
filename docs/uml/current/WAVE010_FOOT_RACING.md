# Wave010 UML — foot-racing mastery deepenings (current)

```mermaid
flowchart TB
  subgraph input [Input]
    IM[InputManager]
    MC[MobileControls]
  end
  subgraph vehicle [Racer IS vehicle]
    PC[PlayerController]
    MS[MovementStats]
    SM[RacerStateMachine]
    DS[DriftSystem]
    BS[BoostSystem]
    TS[TrickSystem]
    SS[StompSystem]
    RS[RailGrindSystem]
    DR[DraftingSystem]
    SA[SpecialAbilitySystem]
  end
  subgraph race [Race]
    RSc[RaceScene]
    RM[RaceManager]
    LM[LapManager]
    CT[CourseTrack]
    SC[ShortcutCorridor]
    TZ[TerrainZone]
    IMGR[ItemManager]
    FCP[FairComebackPolicy]
  end
  subgraph ai [AI]
    AIC[AIRacerController]
    APF[AIPathFollower]
  end
  IM --> PC
  MC --> IM
  PC --> MS
  PC --> SM
  PC --> DS
  PC --> BS
  PC --> TS
  PC --> SS
  PC --> RS
  PC --> DR
  PC --> SA
  PC --> IMGR
  IMGR --> FCP
  RSc --> CT
  CT --> SC
  CT --> TZ
  RSc --> RM
  RM --> LM
  AIC --> PC
  AIC --> APF
  APF --> CT
```

Notes:
- No Wave010 duplicate controllers.
- ShortcutCorridor is geometry/risk, not checkpoint bypass.
- FairComebackPolicy weights items; never place-based speed in competitive mode.
