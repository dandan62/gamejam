extends PanelContainer
class_name DiceUI

## ターン開始時に、見える範囲とライト消費量を決めるオプション(1〜3)を選ばせ、続けて
## 1D6を振らせるUI。移動力自体はダイス＋バックパックの空きで決まり、オプションの影響は
## 受けない。オプションが決めるのは見える範囲(フォグ・オブ・ウォー)とターン終了時の
## ライト消費量だけ。
## UI that has the player pick an option (1-3, which sets the visible range and end-of-turn
## Light cost) at the start of a turn, then rolls 1d6. Movement itself is decided purely by
## the die + empty backpack space and isn't affected by the option -- the option only controls
## the visible range (fog of war) and the Light spent at end of turn.

signal option_chosen(option: int)

var result_label: Label
var dice3d: Dice3D
var option_buttons: Array = []  # Array[Button]


func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	dice3d = Dice3D.new()
	vbox.add_child(dice3d)
	vbox.add_child(_build_tile_legend())
	result_label = Label.new()
	result_label.text = "Choose your Light spend, then roll"
	vbox.add_child(result_label)

	for i in range(3):
		var option := i + 1
		var btn := Button.new()
		btn.text = "%d: %s (%s)" % [
			option,
			StatIcons.tag("Light", StatIcons.LIGHT, StatIcons.signed(-option)),
			StatIcons.tag("Vision", StatIcons.VISION, str(option)),
		]
		btn.pressed.connect(func(): option_chosen.emit(option))
		vbox.add_child(btn)
		option_buttons.append(btn)


## 各マス種別の色と役割を一覧にした凡例。ダイスの下、盤面を見なくてもマスの意味が
## わかるように表示する。
## A legend listing each tile type's color and role. Shown below the dice so tile meanings
## are readable without having to cross-reference the board.
func _build_tile_legend() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	for tile_type in TileIcons.ALL_TYPES:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = TileIcons.color_for(tile_type)
		grid.add_child(swatch)

		var label := Label.new()
		label.text = "%s - %s" % [TileIcons.label_for(tile_type), TileIcons.description_for(tile_type)]
		grid.add_child(label)
	return grid


func show_result(option: int, die: int, backpack_space: int, movement: int) -> void:
	result_label.text = "%s | %s + %s = %s" % [
		StatIcons.tag("Light", StatIcons.LIGHT, StatIcons.signed(-option)),
		StatIcons.tag("Roll", StatIcons.DICE, str(die)),
		StatIcons.tag("Bag", StatIcons.TREASURE_COUNT, str(backpack_space)),
		StatIcons.tag("Move", StatIcons.MOVE, str(movement)),
	]
	dice3d.roll(die)


func set_enabled(enabled: bool) -> void:
	for btn in option_buttons:
		btn.disabled = not enabled
