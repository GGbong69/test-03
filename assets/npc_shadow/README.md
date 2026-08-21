# Shadow Shopkeeper assets

Runtime PNGs are transparent, use the project's nearest-neighbour texture
filter, and are snapped to the same compact 16-colour family.

- `idle_master.png`: connected idle pose for a static shop screen.
- `rig_parts.png`: overview sheet of the five animation parts.
- `parts/torso.png`: torso.
- `parts/upper_left.png`, `parts/upper_right.png`: screen-left/right upper arms.
- `parts/fore_left.png`, `parts/fore_right.png`: screen-left/right forearms and hands.
- `sweep_forward.png`: straight player-facing arm for the reroll sweep.

The high-resolution and chroma-key generation sources live under `source/`
and are excluded from Godot imports. Run
`res://scripts/tools/prepare_npc_shadow.gd` with Godot to rebuild all runtime
PNGs after replacing a source image.
