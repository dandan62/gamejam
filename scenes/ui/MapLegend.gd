extends PanelContainer
class_name MapLegend

## マップの右上に重ねて表示する、マス種別の色分け凡例。
## 普段は各マスの色とマス名だけを一覧表示し、ヘッダーをクリックすると各マスの役割説明が
## プルダウンのように開閉する。
## Tile-color legend overlaid at the map's top-right corner. Normally lists just each tile
## type's swatch + name; clicking the header toggles a pulldown that reveals each type's
## description.

const PANEL_WIDTH := 260.0

var _description_labels: Array = []  # Array[Label]
var _expanded: bool = false
var _toggle_btn: Button


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_toggle_btn = Button.new()
	_set_toggle_text()
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	vbox.add_child(_toggle_btn)

	for tile_type in TileIcons.ALL_TYPES:
		var entry := VBoxContainer.new()
		vbox.add_child(entry)

		var row := HBoxContainer.new()
		entry.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = TileIcons.color_for(tile_type)
		row.add_child(swatch)

		var name_label := Label.new()
		name_label.text = TileIcons.label_for(tile_type)
		row.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = TileIcons.description_for(tile_type)
		desc_label.custom_minimum_size = Vector2(PANEL_WIDTH - 32.0, 0)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.modulate = Color(1, 1, 1, 0.8)
		desc_label.visible = _expanded
		entry.add_child(desc_label)

		_description_labels.append(desc_label)


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_set_toggle_text()
	for label in _description_labels:
		label.visible = _expanded


func _set_toggle_text() -> void:
	_toggle_btn.text = "Legend %s" % ("▴" if _expanded else "▾")
