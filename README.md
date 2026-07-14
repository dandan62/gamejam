# Deep Abiss

A 2-human + 1-CPU, hot-seat, push-your-luck score-attack board game built in **Godot 4.6.2 / GDScript**.

Players take turns rolling dice and diving deeper into a branching underground map to grab treasure,
then choose when to turn back before their HP or Light runs out. Treasure only counts toward your
score once you carry it back to the surface — die or run out of light on the way and you lose
whatever you're still holding.

The whole game is **data-driven**: maps, treasures, events and relics all live as individual
files under `data/`, so new content can be added or tuned without touching any code.

## Requirements & running　💻

- Godot **4.6.2** (`config/features` in `project.godot` pins `4.6` + Forward Plus; rendering method is
  set to `gl_compatibility`).
- Open `project.godot` in the editor and run it — `Main.tscn` is the main scene, and it's basically a
  bare `Control` node with `scenes/Main.gd` attached. The entire UI (board, HUD, dice, popups) is built
  procedurally in `_ready()`, not laid out in the `.tscn`.
- No build step, no external dependencies.

## Project layout📚

```
deep_abiss/
  project.godot
  data/                        # all game content — see "Authoring content" below
    maps/*.txt                 # map layouts (text format, see below)
    treasures/tierN/*.tres
    events/tierN/*.tres
    relics/tierN/*.tres
  scenes/
    Main.gd                    # root: builds the whole UI tree, wires TurnManager signals. Splits the screen into a map area and a status area at a 6:4 width ratio. Also owns fixed overlays pinned to the map viewport (siblings positioned at fixed coords outside the ScrollContainer, so they don't move when the board scrolls): turn_countdown_label (round-limit warning), and a top-right right_overlay column holding map_legend (tile-type legend) directly above movement_panel (a square panel captioned "残り移動回数" with the remaining move count in 120pt bold purple text)
    Board.gd                   # draws the map graph + tokens, handles tile clicks (CANVAS_SIZE = 560x1900)
    ui/
      HUD.gd                   # per-player HP (heart gauge)/Light (battery gauge)/Bag (Weight and Bag are unified: one empty square slot per point of weight capacity, filled with the actual item icon as things are picked up) on the left, Score as a large bold number pinned to the right edge (same big-text feel as the remaining-move-count display); active player's panel glows in their token color. Each gauge's own frame (not the whole panel) turns red once that stat hits its danger threshold (HP 1 / Light 1) or yellow at its warning threshold (HP 2 / Light <= 3), and the whole panel darkens once eliminated. Remaining moves aren't shown here -- see Main.gd's movement_panel
      HeartGauge.gd, BatteryGauge.gd  # HP as ❤/♡ glyphs; Light as a row of individual battery icons (one per point, filled left-to-right)
      DiceUI.gd, Dice3D.gd     # roll button + 3D dice visual. Once the toss settles (Dice3D.roll_finished), the movement math is revealed step by step ("die roll" -> "+ Bag" -> "= Move") then cleared down to just the final movement value, instead of dumping the whole equation instantly
      ActionPanel.gd           # pick up / ignore / discard prompt; description text wraps (AUTOWRAP_WORD) instead of stretching the panel wider
      EventPopup.gd            # 2-choice event prompt; description text wraps (AUTOWRAP_WORD) instead of stretching the panel wider
      GameOverScreen.gd        # final ranking
      MapLegend.gd             # tile-type legend overlaid at the map's top-right; names always shown, descriptions pull down
  scripts/
    autoload/
      GameManager.gd           # singleton: player list, turn order, round number, map/spawner refs
      DataLoader.gd            # singleton: loads everything under data/ into lookup caches
    core/
      TurnManager.gd           # the turn state machine (see below)
      DiceRoller.gd            # 2d6 roll
      TierSelector.gd          # depth -> tier band lookup
      TreasureSpawner.gd       # rolls treasure/relic contents once per game, per tile
      StatIcons.gd             # label+icon strings for HP/Light/Score/etc buff display
      TileIcons.gd             # color/label/description per tile type, shared by Board + MapLegend
    map/
      MapGraph.gd              # runtime adjacency (forward/backward) built from a MapDefinition
      MapTextLoader.gd         # parses data/maps/*.txt into a MapDefinition
    data_models/                # plain Resource (class_name) definitions, one per content type
      MapDefinition.gd, MapNodeDef.gd
      TreasureData.gd, EventData.gd, RelicData.gd
      EffectData.gd, BuffData.gd
    entities/
      PlayerState.gd           # HP/Light/weight/carried treasure/status for one player
      CPUAI.gd                 # heuristic bot: direction choice, tile actions, event choice
```

## Rules / core loop　🔁

Defaults: `HP = 3`, `Light = 5`, weight capacity `= 5`. All three can be modified by buffs.

A turn (`TurnManager.gd`) goes:

1. **Roll** — 1d6 + empty backpack space (weight capacity minus carried weight, **capped at 5**) + any
   `MOVE` buff bonus = movement points for this turn.
2. **Step** — move one tile at a time until movement points run out or there's nowhere left to go.
   At **every single tile**, the game offers both the forward (deeper) and backward (toward the
   surface) neighbors as candidates together — direction is **not** locked in for the whole turn, it's
   re-chosen at each step, and it's **never auto-picked even when there's only one candidate**: a
   human always clicks the highlighted node on the board (forward = white glow, backward = blue glow),
   CPU always decides explicitly via `CPUAI.choose_path()`.
3. **Resolve the tile** you land on:
   - `EMPTY` — ignore, or discard one carried treasure.
   - `TREASURE` — pick up (only if it fits under your weight capacity) or ignore. Picking up applies
     the treasure's HP damage and any `WHILE_HELD`/`PERMANENT` buffs immediately.
   - `EVENT` — a 2-choice prompt; each choice applies an `EffectData`.
   - `BRIDGE` — whoever crosses it chooses to destroy it or leave it. Destroying it makes that tile
     impassable for **everyone** (including yourself) for the rest of the game — it's simply excluded
     from `MapGraph.get_forward_ids`/`get_backward_ids` from then on. Leaving it intact means the next
     player to cross gets the same choice again.
   - `RELIC` — behaves like a scoreless treasure: pick up (only if it fits under your weight capacity)
     or ignore. Picking up grants its buffs permanently on the spot and puts it in `carried_relics`,
     which occupies weight capacity forever — unlike `carried_treasures`, it's never cleared, not on
     banking at a return, not on elimination.
   - Already-claimed `TREASURE`/`RELIC` tiles behave like `EMPTY`.
4. **Return** — if a backward step lands you on the start node, your carried treasures' values are
   banked into `banked_score`, Light refills to max, and your status becomes `RETURNED`. This is
   **not retirement** — see below.
5. **End of turn** — unless this was the turn you just returned on, Light drops by 1 (reduced by any
   `LIGHT` buff). If HP or Light is now `<= 0`, you lose everything currently carried (unbanked) and
   become `ELIMINATED`.

**Returning doesn't end a player's game.** A `RETURNED` player still gets turns in rotation; the moment
their next turn starts, their status flips back to `ACTIVE` and they dive again from the start node,
picking up where a fresh dive begins (full Light, whatever they'd already banked stays banked). Only
`ELIMINATED` players are skipped.

**Game over** happens when either:
- the round limit (`TurnManager.MAX_ROUNDS = 8`) is exceeded — anyone still `ACTIVE` (mid-dive) is
  force-eliminated (loses unreturned treasure) so the game can end cleanly, or
- every player has been `ELIMINATED`.

Since hitting the round limit ends the game abruptly, two warnings kick in as it approaches:
- `Board.gd` blinks the map's outer border red once 3 or fewer rounds remain
  (`Board.set_remaining_rounds`, called from `Main._refresh_all`).
- `Main.gd` overlays a fixed banner on top of the map reading "3 turns left" / "2 turns left" /
  "last turn" — shown only for the window between a turn starting and that player rolling the dice
  (`_update_turn_countdown`, set in `_on_turn_started`, cleared in `_on_movement_option_chosen`).

Final ranking is `banked_score` descending (`GameManager.get_ranking()`).

## Architecture notes　📒→📒

- **`GameManager`** (autoload) owns the player list, current turn index, round number, the `MapGraph`
  and the `TreasureSpawner`. It has no turn logic itself — `advance_to_next_player()` just rotates to
  the next non-`ELIMINATED` player, incrementing `round_number` once everyone's had a turn.
- **`DataLoader`** (autoload) recursively walks `data/treasures`, `data/events`, `data/relics` at
  startup, loading every `.tres` it finds into `*_by_tier` (and `*_by_id` for events/relics)
  dictionaries. It also loads `data/maps/*.txt` — **non-recursively**, so map files must sit directly
  in that folder, not in subfolders.
- **`TurnManager`** is a `Node` under `Main` and is the only place turn state lives (`State` enum:
  `IDLE, WAITING_ROLL, WAITING_STEP, WAITING_TILE_ACTION, WAITING_EVENT_CHOICE, GAME_OVER`). It emits
  signals for every observable event (`dice_rolled`, `movement_changed`, `path_choices_ready`,
  `player_moved`, `player_returned`, `tile_action_needed`, `event_choice_needed`, `player_eliminated`,
  `turn_ended`, `game_over`, ...) and `Main.gd` just listens and updates UI — it holds no game logic
  itself. On a human turn it waits for the UI to call back into `roll_dice()` / `choose_path()` /
  `choose_tile_action()` / `choose_event()`; on a CPU turn it calls those same functions itself right
  after entering each state.
- While a tile action prompt is up (`TREASURE`/`RELIC`/`RELIC pick-up? / BRIDGE`), `TurnManager` also
  pre-highlights the next step's candidate tiles (`_emit_skip_candidates`). Clicking one of those
  highlighted tiles directly — instead of pressing "Ignore"/"Leave It" in the `ActionPanel` — is
  treated as choosing "ignore" and then immediately continues onto that tile
  (`TurnManager.handle_board_click`). `EVENT` tiles have no ignore option, so nothing is
  pre-highlighted for them and a player must pick one of the two choices in the popup to proceed.
- **`Board`** lays tiles out to always fill its fixed `CANVAS_SIZE` (560×1900): lane/depth spacing is
  derived from the loaded map's own max lane count and max depth, so the tile grid stretches to fit
  that canvas regardless of the map. A background illustration authored at the same 560:1900 aspect
  ratio (or a multiple of it, e.g. 1120×3800) will always line up with the tiles, no matter which map
  is loaded.
- Fog of war (`Board._draw`): tiles within `vision_radius` hops of the current player are revealed,
  plus the start's entire depth-0 layer is always revealed regardless of vision range. Paths are drawn
  out from any revealed tile to wherever they lead (even into still-dark, unrevealed territory), not
  only between two already-revealed tiles. The background illustration is lit in two ways: a vertical
  gradient from `START_LIGHT_TOP_OFFSET` down to the start (`_draw_start_light_gradient`; the canvas
  top above the offset is always shown at full brightness, then it fades out around
  `BACKGROUND_REVEAL_OUTER_RADIUS` past the start), and a soft feathered circular patch per other
  individually-revealed tile
  (`_draw_reveal_patch`, drawn as textured polygons with per-vertex alpha so the edge is a smooth round
  falloff rather than a hard-edged square) — so an unrevealed lane at an already-explored depth (e.g.
  an unexplored branch) stays dark.
- **`MapGraph`** builds forward/backward adjacency from a `MapDefinition`'s flat node list (backward
  edges are derived automatically from everyone's `forward_connections`). It also tracks which
  `BRIDGE` tiles have been destroyed (`break_bridge`/`is_bridge_broken`) and filters them out of every
  `get_forward_ids`/`get_backward_ids` result, so a broken bridge is transparently unreachable from any
  neighboring tile for the rest of the game.
- **`TreasureSpawner`** rolls the actual contents of every `TREASURE`/`RELIC` tile exactly once at game
  start (tier is picked by `TierSelector.pick_tier(depth)`, then an item is picked at random from that
  tier's pool, and treasure value is rolled within the item's `min_value`/`max_value`). Once taken, a
  tile stays empty for the rest of the game.
- **`CPUAI`** is a stateless heuristic: it retreats if there's nowhere to go forward, if Light is low
  (`<= 2`) while carrying anything, or once it's carrying 3+ treasures; otherwise it advances toward
  whichever forward candidate looks best (`TREASURE` > `RELIC` > `EVENT` > `EMPTY` = `BRIDGE`). Tile
  actions are simple (take a relic or treasure only if it fits under weight capacity, always ignore empty tiles,
  score event choices by hp/light/score deltas, destroy a bridge behind it once it's carrying 2+
  treasures — to slow down anyone chasing the same route — and otherwise leave it standing).

## Authoring a map (`data/maps/*.txt`)　🌎

Parsed by `MapTextLoader.gd`. If the file's very first line starts with `#`, it's an **option
line** instead of a tile line — space-separated `key=value` tokens, consumed before any depth
parsing starts. Recognized keys:

| Option | Effect |
|---|---|
| `persist_tiles=true` | `TREASURE`/`RELIC` tiles on this map never become `EMPTY` after being picked up. Instead, the instant one is taken its contents are re-rolled from the same tier on the spot, so the tile stays pickable forever but with a **different item each time** rather than the same one repeating. Omit the option line entirely (or leave it `false`) for the original one-time-only behavior. |
| `background=file` | Uses `data/maps/file` as `Board`'s background illustration (no spaces in the filename). Author it at `Board.CANVAS_SIZE` (560×1900, or a multiple of that ratio) — tile spacing always stretches to fill that canvas (see `Board._compute_positions`), so it lines up regardless of the map. Only the Y-range of currently revealed tiles is drawn (plus `Board.BACKGROUND_BAND_PADDING`), so fog of war still hides unexplored depths — everywhere else stays solid black. Omit it for no background (the original solid black). |

e.g. a map starting with `#persist_tiles=true background=イラスト32.png` followed by the normal
tile/connector lines.

After the option line (if present), a map file alternates **tile lines** and **connector lines**,
starting and ending on a tile line, one depth per pair:

| Tile char | Meaning     |
|-----------|-------------|
| `S`       | Start (exactly one per map) |
| `n`       | Empty       |
| `t`       | Treasure    |
| `e`       | Event       |
| `h`       | Bridge      |
| `r`       | Relic       |
| `.`       | No tile in this lane at this depth |

Each character in a tile line is one lane; the lane count is allowed to change from depth to depth
(use `.` to leave gaps). A node's forward branching is meant to stay small (the data model's own
comment says "up to 5", though nothing in code actually enforces a cap).

A **connector line** describes how one depth's lanes link to the next depth's lanes:
- **Blank line** → auto-connect: each lane connects to the same lane and its two neighbors (`lane-1,
  lane, lane+1`) at the next depth, whichever of those exist.
- **Non-blank line** → manual: space-separated `sourceLane:targetLane,targetLane,...` tokens, e.g.
  `0:0,1,2,3,4` connects lane 0 to lanes 0 through 4 at the next depth.

Excerpt from `data/maps/map_01.txt`:

```
S
0:0,1,2,3,4
nnenn
0:0, 1:1, 2:2, 3:3, 4:4
nntrt
0:0, 1:0, 2:0, 3:0, 4:0
nn.n.

tnnht

ehhtt
```

Reading this: depth 0 is a single `S` lane that manually fans out to all 5 lanes of depth 1
(`nnenn`); depth 1 connects straight across 1:1 to depth 2 (`nntrt`); depth 2 funnels all 5 lanes down
to a single lane 0 at depth 3 (`nn.n.`, which also has gaps at lanes 2 and 4); from depth 3 onward the
connector lines are blank, so depths 4+ (`tnnht`, `ehhtt`, ...) use auto-connect.

To add a new map, just drop a new `data/maps/whatever.txt` file — `DataLoader` picks up every `.txt`
in that folder automatically. `GameManager.start_new_game(map_name)` looks it up by file basename (no
extension). `Main.gd` handles picking a name for you: with only one map loaded it starts that one
immediately; with 2+ maps it shows a "Choose a Map" button list up front (`Main._show_map_select`)
and starts whichever one the player clicks (`Main._start_game`).

## Authoring content (`data/*/tierN/*.tres`)　💰　

Every content type is a plain Godot `Resource` script (`class_name` + `@export` fields), so new items
are just new `.tres` files created/edited from the Inspector — no code changes needed. The folder path
(`tier1`, `tier2`, ...) is purely for human organization; **what actually controls which pool an item
falls into is its own `tier` export field**, read by `DataLoader`. Keep the folder and the field in
sync by convention, but only the field matters at runtime.

Fastest way to add a new treasure/relic/event: copy a starting-point `.tres` from
**`data/_templates/`** (`treasure_template.tres`, `relic_template.tres`, `event_template.tres`) into
the right `data/<category>/tierN/` folder and edit it — see `data/_templates/README.md` for a full
field reference (including what `BuffData`'s `stat`/`duration` integers mean, since `.tres` files
can't hold comments). That folder is deliberately outside `data/treasures`/`data/events`/`data/relics`
so `DataLoader` never picks the templates up as real content.

| Resource | Fields | Notes |
|---|---|---|
| `TreasureData` | `id`, `display_name`, `tier`, `min_value`, `max_value`, `hp_damage`, `weight`, `icon` (Texture2D), `buffs: Array[BuffData]` | Value is rolled once per placement between `min_value`/`max_value`. `icon` is shown in the HUD's carried-treasure row; leave it unset and the HUD falls back to a colored square with the item's first letter. |
| `EventData` | `id`, `tier`, `description`, `choice_a_text`, `choice_a_effect`, `choice_b_text`, `choice_b_effect` | Sits on `EVENT` tiles; presents a 2-choice prompt. |
| `RelicData` | `id`, `display_name`, `tier`, `description`, `weight`, `buffs: Array[BuffData]` | Sits on `RELIC` tiles; behaves like a scoreless treasure — occupies weight capacity in `PlayerState.carried_relics` forever, and its buffs are granted permanently the instant it's picked up (never lost, even on elimination). |
| `EffectData` | `description`, `hp_delta`, `light_delta`, `score_delta`, `apply_buff` (BuffData), `drop_treasure_count`, `next_treasure_multiplier` | Generic effect payload used by events. A field left at its default (`0` / `1.0` / `null`) is a no-op — you only set the fields you actually want to change. |
| `BuffData` | `stat` (`MOVE` / `WEIGHT` / `LIGHT` / `MAX_HP` / `MAX_LIGHT`), `amount`, `duration` (`PERMANENT` / `WHILE_HELD`) | `WHILE_HELD` buffs from carried treasure only apply as long as you still hold that treasure; relic buffs are always granted `PERMANENT` regardless of the field's value. `MAX_HP`/`MAX_LIGHT` are relic-only: `PlayerState.add_relic_buffs` special-cases them to raise the cap (and current value) directly instead of stacking as a dynamic bonus. |

`BRIDGE` tiles have no data file of their own — the "destroy or leave it" choice and its consequences
are pure code, handled by `TurnManager._resolve_tile`/`choose_tile_action` and `MapGraph.break_bridge`.

Example `.tres` (an event, `data/events/tier1/hidden_draft.tres`):

```ini
[gd_resource type="Resource" script_class="EventData" format=3]

[ext_resource type="Script" path="res://scripts/data_models/EventData.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data_models/EffectData.gd" id="2"]

[sub_resource type="Resource" id="1"]
script = ExtResource("2")
description = "You took the shortcut, burning extra light, but found a bit of loot"
light_delta = -1
score_delta = 3

[sub_resource type="Resource" id="2"]
script = ExtResource("2")
description = "You chose the safe path"

[resource]
script = ExtResource("1")
description = "You find a narrow gap with cold air blowing through. Take the shortcut?"
choice_a_text = "Take the shortcut (Light-1, Score+3)"
choice_a_effect = SubResource("1")
choice_b_text = "Turn back to the safe path"
choice_b_effect = SubResource("2")
```

In practice, easier than hand-writing `.tres` files is: duplicate an existing file of the type you
want in the Godot editor, edit the fields in the Inspector, and place the copy under the right
`data/<category>/tierN/` folder.

### Tier selection (`TierSelector.gd`)

Treasure/event tiers aren't read from the map file — they're derived at runtime from tile **depth**
via `TierSelector.pick_tier(depth)`, a fixed depth-band mapping:

- depth 1–6 → tier 1
- depth 7–12 → tier 2
- depth 13–18 → tier 3
- depth 19–20 → tier 4

`RELIC` tiles use the same `pick_tier(depth)` call independently.

If a tier has no registered items at all, `DataLoader` falls back to whichever tier that *does* have
content and is numerically closest — so an empty tier folder won't hard-fail, it'll just borrow from a
neighboring tier.

### A couple of things that look wired up but aren't (yet)

- `MapNodeDef.fixed_event_id` **is** honored — set it to force a specific `EVENT` tile to always use
  that exact id instead of a random tier roll (falls back to random if the id isn't found).
  `fixed_relic_id`, however, is **not read anywhere** — `RELIC` tiles are always randomly rolled by
  tier via `TreasureSpawner`, regardless of this field.
- `MapNodeDef.tier` (the per-node field) is likewise **never read** — tier is always derived from the
  node's `depth` through `TierSelector`, not from this field.

Worth keeping in mind if you're tracing why setting either of those two fields doesn't seem to do
anything — it's not a bug in your map file, that wiring just doesn't exist yet.
