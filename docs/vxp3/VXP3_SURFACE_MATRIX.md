# VXP-3 Surface Matrix

| Surface | Path | Presentation owner | Contract preserved |
|---------|------|--------------------|--------------------|
| Main menu | `scenes/main/MainMenu.tscn` + `MainMenu.gd` | `Vxp3Presentation.recomposite_main_menu` | Routes / pickers / resume truth |
| First-run | MainMenu prompt | Learn the Track / Race Now | Tutorial + single race entry |
| Runner select | MainMenu pickers | IDs unchanged | RunnerProfile IDs |
| Footwear select | ShoePicker + ShoeInfo | ShoeData fields | Modifiers untouched |
| Cup/course | CupPicker / CoursePicker | Resume if save exists | Cup progress cfg |
| Race HUD | `RaceHUD.gd` | Drift/boost/footwear chrome | Live meters |
| Countdown | RaceManager ticks + intro labels | course→line→3→2→1→GO | Timing unchanged |
| Pause | `PauseMenu.gd` | Resume CTA + Tutorial Guide | Pause semantics |
| Results | `ResultsScreen.gd` | Glyph podium | Cup/MP semantics |
| Achievement toast | `AchievementToast.gd` | VXP skin | Unlock wiring |
| Tutorial | `TutorialCoach` + `TutorialDirector` | Coach in race; guide in pause | `mark_tutorial_done` |
