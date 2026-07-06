extends PanelContainer
class_name GameOverScreen

var vbox: VBoxContainer


func _ready() -> void:
	vbox = VBoxContainer.new()
	add_child(vbox)
	hide()


func show_ranking(ranking: Array) -> void:
	for child in vbox.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Game Over! Final Results"
	vbox.add_child(title)
	for i in range(ranking.size()):
		var p: PlayerState = ranking[i]
		var lbl := Label.new()
		var status_text := "Returned" if p.status == PlayerState.Status.RETURNED else "Eliminated"
		lbl.text = "#%d: %s - %d pts (%s)" % [i + 1, p.display_name, p.banked_score, status_text]
		vbox.add_child(lbl)
	show()
