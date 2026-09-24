# Anime Aggressors Guest Runner Provenance

Label: `AA_CC0_CANDIDATE_DERIVATIVE`

These seven runners are **not** bespoke Pedestrian Pursuit human commissions.
They are adapted from Anime Aggressors PR #109 CC0 KayKit candidate models and
re-homed as an additive guest roster.

Product remains Pedestrian Pursuit / KINETIC SOLE: footwear is the machine.

## Source verification

| Field | Value |
|---|---|
| Source repo | `gunnchOS3k/anime-aggressors` |
| Candidate-art PR | [#109](https://github.com/gunnchOS3k/anime-aggressors/pull/109) |
| PR #109 head | `3447c91de66e9fa41c9d0de6c2558e5557564b7c` |
| Elemental presentation PR | [#110](https://github.com/gunnchOS3k/anime-aggressors/pull/110) |
| PR #110 head | `762c597f3677a110b8bddef9b79327a17369f8a6` |
| License | CC0 1.0 Universal |
| Copied V2–V9 experiment art | No |

## License matrix

| Guest runner | Source pack | Source character | License | AA adapted SHA-256 |
|---|---|---|---|---|
| Ember Vale | KayKit Character Pack Adventures 1.0 | Mage | CC0 1.0 Universal | `1da02b8882b06f3c88f97b5d4a595c89917203dfc02ff2d4055cd1cfde5db93e` |
| Rook Ironside | KayKit Character Pack Adventures 1.0 | Barbarian | CC0 1.0 Universal | `18d96e68de21152b44fabdd6294935d9964f1b16f8aca73b6a1db08f039c3b2e` |
| Juno Spark | KayKit Character Pack Adventures 1.0 | Rogue | CC0 1.0 Universal | `2f579f1a24c599007242e065079e5a5d280fed005731cde30ba663339a0e5067` |
| Kaia Windrow | KayKit Character Pack Adventures 1.0 | Rogue_Hooded | CC0 1.0 Universal | `af3d540a18dda9370c17c3b88a5e18adcc1783c02e419312e043a8675c52853b` |
| Nix Calder | KayKit Character Pack Skeletons 1.0 | Skeleton_Mage | CC0 1.0 Universal | `324556bb3ad563397d96a29825b43ff552de8468b604ae619f19461930054c0f` |
| Orion Vell | KayKit Character Pack Adventures 1.0 | Knight | CC0 1.0 Universal | `7e688084067236905db9604018a1ced240273cb1db7db274e14b4dece76997c3` |
| Vesper Nyx | KayKit Character Pack Skeletons 1.0 | Skeleton_Rogue | CC0 1.0 Universal | `706dedbe6d4c2d32831d131f4f33cbee3774740e9573fd03d405dd03effaf8b7` |

KayKit attribution (appreciated, not required under CC0): Kay Lousberg / www.kaylousberg.com

## Cross-repo adaptation

1. Confirm the exact adapted GLB on Anime Aggressors PR #109.
2. Confirm the recorded adapted hash.
3. Confirm CC0 provenance in `RIGHTS.json` / `PROVENANCE.json`.
4. Copy into `assets/models/guest_runners/<id>/<id>.glb`.
5. Hide combat props at runtime. Do not copy combat systems.

Machine-readable copy: `artifacts/guest_runners/GUEST_RUNNER_PROVENANCE.json`

## Animation honesty

Adapted GLBs keep KayKit locomotion plus unused combat-named clips.
Pedestrian Pursuit maps:

| PP state | Source clip | Approximation |
|---|---|---|
| idle | idle | No |
| walk | walk | No |
| run | run | No |
| jump | run | Yes — `launch` is Death and is not used |
| boost | run + sole VFX | Yes — `super`/`heavy` are attacks |
| stumble | hurt_heavy | No |
| recovery | walk | Yes |
| finish_victory | idle | Yes — no combat taunt |
| finish_defeat | hurt_heavy | Yes — Death unused |
| selection_pose | idle | Yes — combat idle unused |

Unused on purpose: `charged_idle`, `heavy`, `super`, `clash_lock`, `launch`.
