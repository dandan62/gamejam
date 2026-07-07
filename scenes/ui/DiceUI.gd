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
	roll_button.text = "Roll Dice (1D6)"
	roll_button.pressed.connect(func(): roll_pressed.emit())
	vbox.add_child(roll_button)


func show_result(die: int, backpack_space: int, movement: int) -> void:
	result_label.text = "Roll: %d + Backpack %d = Movement %d" % [die, backpack_space, movement]
	dice3d.roll(die)


func set_enabled(enabled: bool) -> void:
	roll_button.disabled = not enabled
