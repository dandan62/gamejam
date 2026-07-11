extends PanelContainer
class_name ActionPanel

signal action_chosen(action: String)

var vbox: VBoxContainer


func _ready() -> void:
	vbox = VBoxContainer.new()
	add_child(vbox)
	hide()


func _clear() -> void:
	for child in vbox.get_children():
		child.queue_free()


func prompt(context: Dictionary) -> void:
	_clear()
	var info := Label.new()

	match context.get("kind"):
		"treasure":
			var data: TreasureData = context["data"]
			info.text = "Treasure: %s (%s / %s / %s)  %s" % [
				data.display_name,
				StatIcons.tag("Score", StatIcons.SCORE, str(context["value"])),
				StatIcons.tag("Weight", StatIcons.WEIGHT, str(data.weight)),
				StatIcons.tag("HP", StatIcons.HP, "-%d" % data.hp_damage),
				StatIcons.buffs_summary(data.buffs),
			]
			vbox.add_child(info)
			var pick_btn := Button.new()
			pick_btn.text = "Pick Up"
			pick_btn.disabled = not context.get("can_pick_up", false)
			pick_btn.pressed.connect(func(): action_chosen.emit("pick_up"))
			vbox.add_child(pick_btn)
			_add_ignore_button()
		"relic":
			var relic: RelicData = context["data"]
			info.text = "Relic: %s (%s)  %s  %s" % [
				relic.display_name,
				StatIcons.tag("Weight", StatIcons.WEIGHT, str(relic.weight)),
				relic.description,
				StatIcons.buffs_summary(relic.buffs),
			]
			vbox.add_child(info)
			var pick_btn := Button.new()
			pick_btn.text = "Pick Up"
			pick_btn.disabled = not context.get("can_pick_up", false)
			pick_btn.pressed.connect(func(): action_chosen.emit("pick_up"))
			vbox.add_child(pick_btn)
			_add_ignore_button()
		"bridge":
			info.text = "Bridge: destroy it behind you to block everyone (including yourself) from crossing this tile again?"
			vbox.add_child(info)
			var destroy_btn := Button.new()
			destroy_btn.text = "Destroy Bridge"
			destroy_btn.pressed.connect(func(): action_chosen.emit("destroy_bridge"))
			vbox.add_child(destroy_btn)
			var keep_btn := Button.new()
			keep_btn.text = "Leave It"
			keep_btn.pressed.connect(func(): action_chosen.emit("keep_bridge"))
			vbox.add_child(keep_btn)
	show()


func _add_ignore_button() -> void:
	var ignore_btn := Button.new()
	ignore_btn.text = "Ignore"
	ignore_btn.pressed.connect(func(): action_chosen.emit("ignore"))
	vbox.add_child(ignore_btn)


func close() -> void:
	hide()
