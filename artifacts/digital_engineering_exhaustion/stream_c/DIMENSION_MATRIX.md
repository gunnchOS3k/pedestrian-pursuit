# Dimension matrix

| Dimension | Status | Evidence | Blocker |
|---|---|---|---|
| build | PASS | godot import |  |
| launch | PASS | tools/run_godot_headless.sh |  |
| save_load | PARTIAL | profile/achievement persistence tests | HUMAN_VALIDATION_REQUIRED |
| menus | PASS | tests/TestRunner.gd |  |
| input | PARTIAL | mobile_input / unit tests | HUMAN_VALIDATION_REQUIRED |
| pause_resume | PARTIAL | race scene pause paths | HUMAN_VALIDATION_REQUIRED |
| crash_recovery | PARTIAL | mini_soak | HUMAN_VALIDATION_REQUIRED |
| persistence | PARTIAL | profile/achievement persistence tests | HUMAN_VALIDATION_REQUIRED |
| frame_pacing | BLOCKED | PHYSICAL_FPS pending | PHYSICAL_HARDWARE_REQUIRED |
| leaks | BLOCKED | needs profiler soak | PHYSICAL_HARDWARE_REQUIRED |
| loading | PASS | tools/run_godot_headless.sh |  |
| asset_validation | PASS | tools/validate_content.py |  |
| resolution | PARTIAL | export presets | HUMAN_VALIDATION_REQUIRED |
| audio | PARTIAL | assets/audio present | HUMAN_VALIDATION_REQUIRED |
| a11y | HUMAN_VALIDATION_REQUIRED | a11y automation incomplete | HUMAN_VALIDATION_REQUIRED |
| local_multiplayer | PARTIAL | local race modes | HUMAN_VALIDATION_REQUIRED |
| networking | NOT_APPLICABLE | no production netplay claim on main digital RC |  |
| offline | PASS | local Godot offline |  |
| install_update | PARTIAL | rc packaging scripts | HUMAN_VALIDATION_REQUIRED |
| android | BLOCKED | no adb device | PHYSICAL_HARDWARE_REQUIRED |
