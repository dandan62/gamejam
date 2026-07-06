extends PanelContainer
class_name HUD

## プレイヤーごとにHP/ライト/行動力(サイコロの出目)をセグメントゲージで表示し、
## 所持お宝をアイコン(未設定なら頭文字のプレースホルダー)で並べて見せるHUD。
## Per-player HUD showing HP/light/action-points (the dice roll) as segment gauges,
## plus a row of carried-treasure icons (a first-letter placeholder square when
## no icon texture is set yet).

var _vbox: VBoxContainer
var _status_labels: Array = []      # Array[Label]
var _hp_gauges: Array = []          # Array[SegmentGauge]
var _light_gauges: Array = []       # Array[SegmentGauge]
var _action_gauges: Array = []      # Array[SegmentGauge]
var _detail_labels: Array = []      # Array[Label]
var _treasure_rows: Array = []      # Array[HBoxContainer]

var _movement_by_player: Dictionary = {}  # player.id -> {"remaining": int, "total": int}


func setup(players: Array) -> void:
	_vbox = VBoxContainer.new()
	add_child(_vbox)
	_status_labels.clear()
	_hp_gauges.clear()
	_light_gauges.clear()
	_action_gauges.clear()
	_detail_labels.clear()
	_treasure_rows.clear()

	for _p in players:
		var panel := PanelContainer.new()
		var col := VBoxContainer.new()
		panel.add_child(col)
		_vbox.add_child(panel)

		var status_label := Label.new()
		col.add_child(status_label)
		_status_labels.append(status_label)

		var hp_row := HBoxContainer.new()
		col.add_child(hp_row)
		var hp_tag := Label.new()
		hp_tag.text = "HP"
		hp_tag.custom_minimum_size = Vector2(50, 0)
		hp_row.add_child(hp_tag)
		var hp_gauge := SegmentGauge.new()
		hp_gauge.filled_color = Color(0.85, 0.25, 0.25)
		hp_row.add_child(hp_gauge)
		_hp_gauges.append(hp_gauge)

		var light_row := HBoxContainer.new()
		col.add_child(light_row)
		var light_tag := Label.new()
		light_tag.text = "Light"
		light_tag.custom_minimum_size = Vector2(50, 0)
		light_row.add_child(light_tag)
		var light_gauge := SegmentGauge.new()
		light_gauge.filled_color = Color(0.3, 0.8, 0.4)
		light_row.add_child(light_gauge)
		_light_gauges.append(light_gauge)

		var action_row := HBoxContainer.new()
		col.add_child(action_row)
		var action_tag := Label.new()
		action_tag.text = "Action"
		action_tag.custom_minimum_size = Vector2(50, 0)
		action_row.add_child(action_tag)
		var action_gauge := SegmentGauge.new()
		action_gauge.filled_color = Color(0.55, 0.35, 0.9)
		action_row.add_child(action_gauge)
		_action_gauges.append(action_gauge)

		var detail_label := Label.new()
		col.add_child(detail_label)
		_detail_labels.append(detail_label)

		var treasure_row := HBoxContainer.new()
		col.add_child(treasure_row)
		_treasure_rows.append(treasure_row)

	refresh(players)


func set_movement(player: PlayerState, remaining: int, total: int) -> void:
	_movement_by_player[player.id] = {"remaining": remaining, "total": total}


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

		var mv: Dictionary = _movement_by_player.get(p.id, {"remaining": 0, "total": 0})
		_action_gauges[i].set_value(mv["remaining"], mv["total"])

		var weight_text := "%d/%d" % [p.get_total_weight(), p.get_weight_capacity()]
		_detail_labels[i].text = "Weight:%s  Treasures:%d  Score:%d" % [
			weight_text, p.carried_treasures.size(), p.banked_score
		]

		_refresh_treasure_row(_treasure_rows[i], p)


func _refresh_treasure_row(row: HBoxContainer, player: PlayerState) -> void:
	for child in row.get_children():
		child.queue_free()
	for entry in player.carried_treasures:
		var data: TreasureData = entry["data"]
		row.add_child(_build_treasure_icon(data, int(entry["value"])))


const ICON_SIZE := Vector2(28, 28)


func _build_treasure_icon(data: TreasureData, value: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = ICON_SIZE
	box.tooltip_text = "%s (Value %d)" % [data.display_name, value]

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
