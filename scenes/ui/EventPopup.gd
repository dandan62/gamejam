extends PanelContainer
class_name EventPopup

signal choice_made(choice: String)

var desc_label: Label
var a_button: Button
var b_button: Button


func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	desc_label = Label.new()
	vbox.add_child(desc_label)
	a_button = Button.new()
	a_button.pressed.connect(func(): choice_made.emit("a"))
	vbox.add_child(a_button)
	b_button = Button.new()
	b_button.pressed.connect(func(): choice_made.emit("b"))
	vbox.add_child(b_button)
	hide()


func prompt(event: EventData) -> void:
	desc_label.text = event.description
	a_button.text = event.choice_a_text
	b_button.text = event.choice_b_text
	show()


func close() -> void:
	hide()
