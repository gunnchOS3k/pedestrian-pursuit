# Animation Matrix — Pedestrian Pursuit

| Character | Idle | Walk/Run | Jump | Action (boost) | Hit/stumble | Recovery | Victory | Defeat | Selection |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Dash Reed | soft bounce | even cadence | athletic | forward lean | stutter | jog reset | arms up | hands on knees | mid-run smile |
| Nova Quill | micro-hops | explosive stride | punchy | snap lean | catch fall | re-accel | spike cheer | turn then recover | side sprint |
| Sierra Flux | stretch | precise short | tuck | wall-lean | roll absorb | short get-up | backflip flash | shrug-clap | vault freeze |
| Mira Lane | breath sway | smooth long | elegant | float lean | soft stagger | tempo rebuild | open arms | calm breath | tall profile |
| Bolt Harbor | plant resets | heavy plant | heavy clean | shoulder drive | rock absorb | drive out | fist chest | kneel→stand | uphill push |
| Zig Riven | shuffle dance | irregular bounce | trick flick | spin lean | comic spin | laugh jog | dance | faux fall salute | trick freeze |
| Solen Pike | heel-toe | low banked | flat hop | banked lean | foot box | line rejoin | salute | soft exhale | corner freeze |
| Kai Volt | charge pulse | assisted low-bounce | hover hop | kinetic flare | system stutter | assisted launch | ring expand | systems dim | charge stance |

Implementation note: first pass uses procedural bones in `RacerVisual.gd` gated by `RunnerProfile` cadence/lean/bounce scales; authored clips can replace later without changing profiles.
