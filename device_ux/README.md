## Device UX roles — pedestrian-pursuit (G2-C6 product depth)

Gate 2 G2-C6 SOFTWARE runtime profiles.

Canonical matrix (field-kit):
`gate2/nonphysical/G2_C6_device_game_ux/profiles/device_game_ux_matrix.yaml`

Runtime catalog: `profiles/device_roles.json`
Godot autoload: `DeviceRoleRuntime` (`scripts/core/DeviceRoleRuntime.gd`)

Also wired:
- `AccessibilitySettings` — reduce motion, larger UI, auto-accelerate, colorblind HUD
- `TelemetryBus` — race_start / checkpoint / item_use / finish(+perf) / restart

Roles: `student_14_5`, `handheld_hybrid`, `ds_xl_coder`, `edge_io_rings`

Constraints:
- No copyrighted music or protected anime IP assets
- No third-party platform-mascot asset copies
- GPS/maps are **simulated only** (`SIMULATED` or `none`) — never live device GPS
- PHYSICAL_EXECUTION_FREEZE: no third-party platform-mascot asset copies
- `handheld_hybrid` enables soft racing-line assist for touch play
