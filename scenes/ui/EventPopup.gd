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
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
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
	a_button.text = _with_icon_summary(event.choice_a_text, event.choice_a_effect)
	b_button.text = _with_icon_summary(event.choice_b_text, event.choice_b_effect)
	show()


func _with_icon_summary(text: String, effect: EffectData) -> String:
	if effect == null:
		return text
	var summary := effect.icon_summary()
	return "%s  %s" % [text, summary] if summary != "" else text


func close() -> void:
	hide()
