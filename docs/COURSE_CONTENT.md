# Course content contract (Wave E Alpha)

Launch floor: **8 unique courses across 2 cups**. Greybox geometry is intentional Alpha depth; art is not final.

## Cups

1. **Sole Surge Cup** — Verdant Cascade → Cloverwind Ranch → Prism Apex → Emberkeep Gauntlet
2. **Stride Circuit Cup** — Tideglass Harbor → Neon Switchyard → Cloudstep Ridge → Mirage Mesa

## Art status

Every cup course sets `"art_status": "REQUIRES_ART_PRODUCTION"`. Do not treat greybox meshes, flat colors, or stub scenery as shipping art.

## Track schema

Validated by `TrackCatalog.gd` and `tools/validate_content.py`:

- identity: `schema_version`, `id`, `display_name`, `description`, `difficulty`, `theme`
- race rules: `lap_count`, `path_points`, `checkpoint_points`, `lane_width`
- presentation colors + optional `segment_colors`
- features: speed lanes, terrain zones, bounce pads, item boxes, boost pickups
- Alpha extras: `shortcut_routes`, `rail_segments`, `has_shortcut`, `art_status`

Route points form a closed circuit. Checkpoint indices begin at 0 and strictly increase. Feature indices reference route points.

## Shortcuts & rails

`shortcut_routes` document alternate lines for AI route preference and design notes. `rail_segments` feed the Alpha rail-grind attach points. Missing final mesh/rail art remains `REQUIRES_ART_PRODUCTION`.

## Originality rule

Original names, routes, landmarks, writing, and feature placement only. No third-party names, characters, logos, textures, music, models, or traced layouts. Automated tests reject a narrow protected-name list; human legal/art review is still required before release.
