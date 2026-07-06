extends PanelContainer
class_name HUD

var labels: Array = []
var _vbox: VBoxContainer


func setup(players: Array) -> void:
	_vbox = VBoxContainer.new()
	add_child(_vbox)
	labels.clear()
	for _p in players:
		var lbl := Label.new()
		_vbox.add_child(lbl)
		labels.append(lbl)
	refresh(players)


func refresh(players: Array) -> void:
	var status_text := {
		PlayerState.Status.ACTIVE: "Diving",
		PlayerState.Status.RETURNED: "Returned",
		PlayerState.Status.ELIMINATED: "Eliminated",
	}
	for i in range(players.size()):
		var p: PlayerState = players[i]
		var weight_text := "%d/%d" % [p.get_total_weight(), p.get_weight_capacity()]
		labels[i].text = "%s [%s]  HP:%d/%d  Light:%d/%d  Weight:%s  Treasures:%d  Score:%d" % [
			p.display_name, status_text[p.status], p.hp, p.max_hp, p.light, p.max_light,
			weight_text, p.carried_treasures.size(), p.banked_score
		]
