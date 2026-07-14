extends PanelContainer
class_name HUD

## プレイヤーごとの1行は左右2カラム構成: 左にHP(❤/♡のハートゲージ)、ライト(電池型の
## バッテリーゲージ)、Bag行を積み、右端にScoreを移動回数表示(Main.gdのmovement_panel)と
## 同じ感覚の大きめ太字数字で表示する。BagはWeightと統合したステータスで、重量上限の
## 数だけ空の四角を並べ、アイテムを取得したらその分の四角に(既存の_build_treasure_icon/
## _build_relic_iconと全く同じ見た目の)アイテムアイコンを格納して埋める
## (weightが2以上のアイテムは、その分の四角を同じアイコンで連続して埋める)。
## Each player's row is a two-column layout: the left column stacks HP (a heart gauge, ❤/♡),
## Light (a battery-styled gauge), and the Bag row; the right edge shows Score as a large bold
## number, matching the feel of the remaining-move-count display (Main.gd's movement_panel).
## Bag unifies the old Weight stat: it lines up one empty square per point of weight capacity,
## and picking up an item fills that many squares with the item's icon (same look as
## _build_treasure_icon/_build_relic_icon -- items with weight >= 2 fill that many consecutive
## squares with their own icon). Remaining move count isn't shown here at all -- it's on the
## map (Main.gd's movement_panel).

## Board.player_colorsと同じ配色。プレイヤー順(インデックス)で対応させ、駒の色と
## アクティブ枠の色が一致するようにする。
## Same palette as Board.player_colors. Matched by player index so the token color and the
## active-turn highlight color line up.
const PLAYER_COLORS := [Color(0.2, 0.75, 0.35), Color(0.25, 0.55, 0.95), Color(0.95, 0.55, 0.15)]

var _vbox: VBoxContainer
var _panels: Array = []             # Array[PanelContainer]
var _active_player_id: int = -1
var _status_labels: Array = []      # Array[Label]
var _hp_gauges: Array = []          # Array[HeartGauge]
var _light_gauges: Array = []       # Array[BatteryGauge]
var _score_labels: Array = []       # Array[Label]
var _bag_rows: Array = []           # Array[HBoxContainer]


func setup(players: Array) -> void:
	_vbox = VBoxContainer.new()
	add_child(_vbox)
	_panels.clear()
	_status_labels.clear()
	_hp_gauges.clear()
	_light_gauges.clear()
	_score_labels.clear()
	_bag_rows.clear()

	for _p in players:
		var panel := PanelContainer.new()
		_panels.append(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		_vbox.add_child(panel)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)

		var status_label := Label.new()
		col.add_child(status_label)
		_status_labels.append(status_label)

		var hp_row := HBoxContainer.new()
		col.add_child(hp_row)
		var hp_tag := Label.new()
		hp_tag.text = StatIcons.tag("HP", StatIcons.HP)
		hp_tag.custom_minimum_size = Vector2(70, 0)
		hp_row.add_child(hp_tag)
		var hp_gauge := HeartGauge.new()
		hp_row.add_child(hp_gauge)
		_hp_gauges.append(hp_gauge)

		var light_row := HBoxContainer.new()
		col.add_child(light_row)
		var light_tag := Label.new()
		light_tag.text = StatIcons.tag("Light", StatIcons.LIGHT)
		light_tag.custom_minimum_size = Vector2(70, 0)
		light_row.add_child(light_tag)
		var light_gauge := BatteryGauge.new()
		light_row.add_child(light_gauge)
		_light_gauges.append(light_gauge)

		var bag_row := HBoxContainer.new()
		col.add_child(bag_row)
		var bag_tag := Label.new()
		bag_tag.text = StatIcons.tag("Bag", StatIcons.TREASURE_COUNT)
		bag_tag.custom_minimum_size = Vector2(70, 0)
		bag_row.add_child(bag_tag)
		var bag_slots := HBoxContainer.new()
		bag_row.add_child(bag_slots)
		_bag_rows.append(bag_slots)

		## Scoreはステータス行の右端に、移動回数表示(Main.gdのmovement_panel)と同じ感覚の
		## 大きめの太字で表示する(HP/Light/Bagの数値行とは別枠で目立たせる)。
		## Score sits at the right edge of the status row, in large bold text matching the feel
		## of the remaining-move-count display (Main.gd's movement_panel) -- set apart from the
		## HP/Light/Bag rows so it stands out.
		var score_col := VBoxContainer.new()
		score_col.custom_minimum_size = Vector2(120, 0)
		row.add_child(score_col)

		var score_tag := Label.new()
		score_tag.text = StatIcons.tag("Score", StatIcons.SCORE)
		score_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_col.add_child(score_tag)

		var score_label := Label.new()
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_font := SystemFont.new()
		score_font.font_weight = 700
		score_label.add_theme_font_override("font", score_font)
		score_label.add_theme_font_size_override("font_size", 48)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		score_label.add_theme_color_override("font_outline_color", Color.BLACK)
		score_label.add_theme_constant_override("outline_size", 4)
		score_col.add_child(score_label)
		_score_labels.append(score_label)

	refresh(players)


## 現在手番のプレイヤーの枠を、そのプレイヤーの色(Board.player_colorsと同じ配色)で
## 光らせる。誰のターンか一目でわかるようにするため。
## Lights up the current turn's player panel with that player's color (same palette as
## Board.player_colors), so it's obvious at a glance whose turn it is.
func set_active_player(player_id: int) -> void:
	_active_player_id = player_id


func _update_panel_styles(players: Array) -> void:
	for i in range(players.size()):
		var p: PlayerState = players[i]
		if p.id == _active_player_id:
			var sb := StyleBoxFlat.new()
			var color: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
			sb.bg_color = Color(color.r, color.g, color.b, 0.18)
			sb.border_color = color
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(6)
			_panels[i].add_theme_stylebox_override("panel", sb)
		else:
			_panels[i].remove_theme_stylebox_override("panel")


func refresh(players: Array) -> void:
	var status_text := {
		PlayerState.Status.ACTIVE: "Diving",
		PlayerState.Status.RETURNED: "Returned",
		PlayerState.Status.ELIMINATED: "Eliminated",
	}
	for i in range(players.size()):
		var p: PlayerState = players[i]
		_status_labels[i].text = "%s [%s]" % [p.display_name, status_text[p.status]]
		_hp_gauges[i].set_value(p.hp, p.max_hp)
		_light_gauges[i].set_value(p.light, p.max_light)
		_score_labels[i].text = str(p.banked_score)

		_refresh_bag_row(_bag_rows[i], p)

	_update_panel_styles(players)


## 重量上限の数だけ四角スロットを並べる。所持アイテムは順番にスロットを埋めていき
## (weightが2以上なら同じアイコンでその分のスロットを連続して埋める)、余ったスロットは
## 空の四角のまま表示する。
## Lines up one square slot per point of weight capacity. Carried items fill slots in order
## (an item with weight >= 2 fills that many consecutive slots with its own icon); any
## leftover slots stay empty squares.
func _refresh_bag_row(row: HBoxContainer, player: PlayerState) -> void:
	for child in row.get_children():
		child.queue_free()

	var capacity := player.get_weight_capacity()
	var slots_used := 0

	for entry in player.carried_treasures:
		var data: TreasureData = entry["data"]
		var value := int(entry["value"])
		for _w in range(data.weight):
			if slots_used >= capacity:
				break
			row.add_child(_build_treasure_icon(data, value))
			slots_used += 1

	for relic in player.carried_relics:
		var data: RelicData = relic
		for _w in range(data.weight):
			if slots_used >= capacity:
				break
			row.add_child(_build_relic_icon(data))
			slots_used += 1

	for _i in range(capacity - slots_used):
		row.add_child(_build_empty_slot())


func _build_empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = ICON_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.18, 0.6)
	sb.border_color = Color(0.4, 0.4, 0.45)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


const ICON_SIZE := Vector2(28, 28)


func _build_treasure_icon(data: TreasureData, value: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = ICON_SIZE
	box.tooltip_text = "%s (%s)" % [data.display_name, StatIcons.tag("Score", StatIcons.SCORE, str(value))]

	if data.icon != null:
		var tex := TextureRect.new()
		tex.texture = data.icon
		tex.custom_minimum_size = ICON_SIZE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		box.add_child(tex)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.4, 0.4, 0.45)
		bg.custom_minimum_size = ICON_SIZE
		box.add_child(bg)
		var lbl := Label.new()
		lbl.text = data.display_name.substr(0, 1)
		lbl.custom_minimum_size = ICON_SIZE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(lbl)

	return box


## 遺物はスコアが無いので、アイコンにも数値は出さず色(TileIcons.RELIC_COLOR)とツールチップだけで
## お宝と区別する。
## Relics carry no score, so the icon shows no number -- it's distinguished from treasure just by
## color (TileIcons.RELIC_COLOR) and its tooltip.
func _build_relic_icon(data: RelicData) -> Control:
	var box := Control.new()
	box.custom_minimum_size = ICON_SIZE
	box.tooltip_text = "%s - %s  %s" % [data.display_name, data.description, StatIcons.buffs_summary(data.buffs)]

	var bg := ColorRect.new()
	bg.color = TileIcons.RELIC_COLOR
	bg.custom_minimum_size = ICON_SIZE
	box.add_child(bg)
	var lbl := Label.new()
	lbl.text = data.display_name.substr(0, 1)
	lbl.custom_minimum_size = ICON_SIZE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lbl)

	return box
