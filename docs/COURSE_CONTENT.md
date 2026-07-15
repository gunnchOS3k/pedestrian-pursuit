# Sole Surge Cup Content Contract

The Sole Surge Cup is a data-defined four-round championship. `data/cups/sole_surge_cup.json` owns order and scoring; each referenced file in `data/tracks/` owns one course.

## Course progression

1. **Verdant Cascade Circuit** teaches broad racing lines and introduces runoff, boost lanes, and a gentle jump.
2. **Cloverwind Ranch** adds a tighter route, mud handling, and stronger elevation impulses.
3. **Prism Apex** removes continuous guard rails and rewards deliberate precision.
4. **Emberkeep Gauntlet** combines narrow turns, ash slowdown, two forge vents, and the busiest pickup plan.

## Track schema

Required fields are validated both by `TrackCatalog.gd` at runtime and `tools/validate_content.py` in automation:

- identity: `schema_version`, `id`, `display_name`, `description`, `difficulty`, `theme`;
- race rules: `lap_count`, `path_points`, `checkpoint_points`, `lane_width`;
- presentation: track, accent, sky, and backdrop colors;
- features: speed lanes, terrain zones, bounce pads, item boxes, and boost pickups.

Route points form a closed circuit automatically. Checkpoint indices must begin at route point zero, strictly increase, and remain in range. Gameplay feature indices reference route points, so a malformed edit is rejected before the race starts.

## Originality rule

New courses may use broad genre motifs such as waterfalls, ranches, luminous space routes, or volcanic fortresses, but must have an original name, route geometry, landmark arrangement, visual design, writing, and feature placement. Do not import third-party names, characters, logos, textures, music, models, course geometry, or traced layout data.

The automated content test rejects protected franchise terms in shipped JSON. That guard is intentionally narrow; human art, audio, layout, and legal review are still required before release.
