extends PanelContainer
class_name DirectionPanel

signal direction_chosen(forward: bool)

var forward_button: Button
var backward_button: Button


func _ready() -> void:
	var hbox := HBoxContainer.new()
	add_child(hbox)
	forward_button = Button.new()
	forward_button.text = "Advance"
	forward_button.pressed.connect(func(): direction_chosen.emit(true))
	hbox.add_child(forward_button)
	backward_button = Button.new()
	backward_button.text = "Retreat"
	backward_button.pressed.connect(func(): direction_chosen.emit(false))
	hbox.add_child(backward_button)
	hide()


func prompt(can_forward: bool, can_backward: bool) -> void:
	forward_button.disabled = not can_forward
	backward_button.disabled = not can_backward
	show()


func close() -> void:
	hide()
