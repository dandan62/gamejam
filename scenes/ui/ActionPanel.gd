extends PanelContainer
class_name ActionPanel

signal action_chosen(action: String, extra: Dictionary)

var vbox: VBoxContainer


func _ready() -> void:
	vbox = VBoxContainer.new()
	add_child(vbox)
	hide()


func _clear() -> void:
	for child in vbox.get_children():
		child.queue_free()


func prompt(player: PlayerState, node: MapNodeDef, context: Dictionary) -> void:
	_clear()
	var info := Label.new()

	match context.get("kind"):
		"treasure":
			var data: TreasureData = context["data"]
			info.text = "Treasure: %s (Value %d / Weight %d / HP damage %d)" % [
				data.display_name, context["value"], data.weight, data.hp_damage
			]
			vbox.add_child(info)
			var pick_btn := Button.new()
			pick_btn.text = "Pick Up"
			pick_btn.disabled = not context.get("can_pick_up", false)
			pick_btn.pressed.connect(func(): action_chosen.emit("pick_up", {}))
			vbox.add_child(pick_btn)
			_add_ignore_button()
		"relic":
			var relic: RelicData = context["data"]
			info.text = "Relic: %s - %s" % [relic.display_name, relic.description]
			vbox.add_child(info)
			var pick_btn := Button.new()
			pick_btn.text = "Pick Up"
			pick_btn.pressed.connect(func(): action_chosen.emit("pick_up", {}))
			vbox.add_child(pick_btn)
			_add_ignore_button()
		"empty":
			info.text = "Nothing here"
			vbox.add_child(info)
			if context.get("can_discard", false):
				for i in range(player.carried_treasures.size()):
					var entry: Dictionary = player.carried_treasures[i]
					var t: TreasureData = entry["data"]
					var btn := Button.new()
					btn.text = "Discard %s" % t.display_name
					var idx := i
					btn.pressed.connect(func(): action_chosen.emit("discard", {"index": idx}))
					vbox.add_child(btn)
			_add_ignore_button()
	show()


func _add_ignore_button() -> void:
	var ignore_btn := Button.new()
	ignore_btn.text = "Ignore"
	ignore_btn.pressed.connect(func(): action_chosen.emit("ignore", {}))
	vbox.add_child(ignore_btn)


func close() -> void:
	hide()
