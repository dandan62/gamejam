# Content templates

Copy-paste starting points for new treasures/relics/events. This folder is **not** scanned by
`DataLoader` (it only walks `data/treasures`, `data/events`, `data/relics`, `data/maps`), so these
templates never show up in-game by accident — always **copy** one into the right folder first.

## How to use

1. In the Godot editor's FileSystem dock, right-click the template you want and choose
   **Duplicate...**.
2. Move the duplicate into the matching folder, e.g. `data/relics/tier2/my_new_relic.tres`. The
   `tierN` folder name is just for humans; what actually matters is the `tier` field inside the
   file (keep them in sync by convention).
3. Open it and edit the fields in the **Inspector** (or hand-edit the `.tres` text directly — it's
   plain text).
4. Give it a unique, snake_case `id`.
5. Run the game -- no code changes needed.

(`.tres` files can't hold comments, so this README is the field reference instead.)

## `treasure_template.tres` → `TreasureData`

| Field | Meaning |
|---|---|
| `id` | Unique snake_case id. |
| `display_name` | Shown in the tile-action prompt and HUD. |
| `tier` | Which tier pool this is rolled from (see `TierSelector.pick_tier`). |
| `min_value` / `max_value` | Score is rolled once in this range when the tile is placed. |
| `hp_damage` | HP lost immediately on pickup. |
| `weight` | Backpack space it occupies. |
| `buffs` | Array of `BuffData` (see below). Leave `[]` for a plain treasure -- most treasures don't need any. |

## `relic_template.tres` → `RelicData`

Behaves like a scoreless treasure: occupies weight forever (never lost, not even on
elimination/return), and its buffs are granted permanently the instant it's picked up.

| Field | Meaning |
|---|---|
| `id` | Unique snake_case id. |
| `display_name` | Shown in the tile-action prompt and HUD tooltip. |
| `tier` | Which tier pool this is rolled from. |
| `description` | Shown in the tile-action prompt. |
| `weight` | Backpack space it occupies. |
| `buffs` | Array of `BuffData`. A relic with no buffs is pointless -- always include at least one. |

The template's one `BuffData` sub-resource has `stat = 0` (MOVE) and `amount = 1`. To add more
buffs, duplicate the `[sub_resource ... id="1"]` block with a new id (e.g. `id="2"`) and list both
in `buffs = [SubResource("1"), SubResource("2")]`.

## `event_template.tres` → `EventData`

A 2-choice prompt; each choice applies an `EffectData`.

| Field | Meaning |
|---|---|
| `id` | Unique snake_case id (only needed if you want to target it via `MapNodeDef.fixed_event_id`). |
| `tier` | Which tier pool this is rolled from. |
| `description` | The prompt text. |
| `choice_a_text` / `choice_b_text` | Button labels. |
| `choice_a_effect` / `choice_b_effect` | `EffectData` sub-resources (see below). |

### `EffectData` fields (used by both event choices)

All fields default to a no-op value, so only set what you actually want to change:

| Field | Default (no-op) | Effect |
|---|---|---|
| `description` | `""` | Flavor text shown after the choice is made. |
| `hp_delta` | `0` | HP change (can be negative). |
| `light_delta` | `0` | Light change, clamped to `[0, max_light]`. |
| `score_delta` | `0` | Added directly to `banked_score`. |
| `drop_treasure_count` | `0` | Forces dropping this many carried treasures. |
| `next_treasure_multiplier` | `1.0` | Multiplies the value of the *next* treasure picked up. |
| `apply_buff` | `null` | A `BuffData` sub-resource to grant permanently. |

## `BuffData` (used by treasure/relic `buffs` and `EffectData.apply_buff`)

`stat` and `duration` are stored as raw integers in `.tres` files (Godot doesn't write enum names
to text resources), so here's the mapping:

| `stat` value | Meaning |
|---|---|
| `0` | `MOVE` -- bonus to movement (dice roll + backpack space). |
| `1` | `WEIGHT` -- bonus to weight capacity. |
| `2` | `LIGHT` -- reduces end-of-turn Light consumption. |
| `3` | `MAX_HP` -- relic-only: instantly raises max HP (and current HP) by `amount`. |
| `4` | `MAX_LIGHT` -- relic-only: instantly raises max Light (and current Light) by `amount`. |

| `duration` value | Meaning |
|---|---|
| `0` | `PERMANENT` -- stays active forever once granted. |
| `1` | `WHILE_HELD` -- (treasure buffs only) active only while that treasure is still carried; lost if the treasure is dropped or banked. Relic buffs are always treated as `PERMANENT` regardless of this field. |

`amount` is a plain integer (positive or negative).
