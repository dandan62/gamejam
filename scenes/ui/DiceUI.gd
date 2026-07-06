extends PanelContainer
class_name DiceUI

signal roll_pressed

var result_label: Label
var roll_button: Button
var dice3d: Dice3D


func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	dice3d = Dice3D.new()
	vbox.add_child(dice3d)
	result_label = Label.new()
	result_label.text = "Roll the dice"
	vbox.add_child(result_label)
	roll_button = Button.new()
	roll_button.text = "Roll Dice (2D6)"
	roll_button.pressed.connect(func(): roll_pressed.emit())
	vbox.add_child(roll_button)


func show_result(dice: Dictionary, movement: int) -> void:
	result_label.text = "Roll: %d + %d = %d  -> Movement %d" % [dice["d1"], dice["d2"], dice["total"], movement]
	dice3d.roll(dice["d1"], dice["d2"])


func set_enabled(enabled: bool) -> void:
	roll_button.disabled = not enabled
