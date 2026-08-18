# Sequence — item (current)

```mermaid
sequenceDiagram
  participant Box as ItemBox
  participant IM as ItemManager
  participant P as PlayerController
  participant HUD as RaceHUD
  participant Rival as Other racer
  Box->>IM: grant_random_item
  IM->>HUD: item_changed
  P->>IM: use_held_item
  alt turbo_toes
    IM->>P: BoostSystem.apply_external_boost
  else lace_trap
    IM->>Rival: item_warning then spawn trap
  else sole_shield
    IM->>P: shield bubble
  end
```

`scripts/items/ItemManager.gd`, `ItemBox.gd`, `TurboToes.gd`, `LaceTrap.gd`, `SoleShield.gd`.
