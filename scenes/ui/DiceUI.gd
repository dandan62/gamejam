extends PanelContainer
class_name DiceUI

## ターン開始時に、見える範囲とライト消費量を決めるオプション(1〜3)を選ばせ、続けて
## 1D6を振らせるUI。移動力自体はダイス＋バックパックの空きで決まり、オプションの影響は
## 受けない。オプションが決めるのは見える範囲(フォグ・オブ・ウォー)とターン終了時の
## ライト消費量だけ。
## 移動力がどう決まるかわかりにくいという声を受け、結果はダイスの出目が確定した瞬間
## （3Dダイスのトス演出=roll_finishedの後）に一気に出すのではなく、「出目→+Bag→=Move」の
## 順に一段ずつ表示してから、計算過程を消して最終的な移動力だけを大きく残すアニメーション
## にしている(_animate_calc)。
## UI that has the player pick an option (1-3, which sets the visible range and end-of-turn
## Light cost) at the start of a turn, then rolls 1d6. Movement itself is decided purely by
## the die + empty backpack space and isn't affected by the option -- the option only controls
## the visible range (fog of war) and the Light spent at end of turn.
## Because how the movement value gets computed wasn't obvious at a glance, the result isn't
## dumped all at once the instant the die value is known -- it's revealed step by step
## ("die roll" -> "+ Bag" -> "= Move") only after the 3D toss animation settles
## (Dice3D.roll_finished), then the working-out is cleared and just the final movement value is
## left behind, enlarged (_animate_calc).

signal option_chosen(option: int)

const STEP_DELAY := 0.6

var result_label: Label
var light_label: Label
var dice3d: Dice3D
var option_buttons: Array = []  # Array[Button]

var _pending_die: int = 0
var _pending_backpack_space: int = 0
var _pending_movement: int = 0


func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	dice3d = Dice3D.new()
	vbox.add_child(dice3d)
	dice3d.roll_finished.connect(_on_roll_finished)

	light_label = Label.new()
	light_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(light_label)

	result_label = Label.new()
	result_label.text = "Choose your Light spend, then roll"
	result_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(result_label)

	for i in range(3):
		var option := i + 1
		var btn := Button.new()
		btn.text = "%d: %s (%s)" % [
			option,
			StatIcons.tag("Light", StatIcons.LIGHT, StatIcons.signed(-option)),
			StatIcons.tag("Vision", StatIcons.VISION, str(option)),
		]
		btn.pressed.connect(func(): option_chosen.emit(option))
		vbox.add_child(btn)
		option_buttons.append(btn)


func show_result(option: int, die: int, backpack_space: int, movement: int) -> void:
	light_label.text = StatIcons.tag("Light", StatIcons.LIGHT, StatIcons.signed(-option))
	result_label.text = ""
	_pending_die = die
	_pending_backpack_space = backpack_space
	_pending_movement = movement
	dice3d.roll(die)


## ダイスの出目が確定した(3Dトス演出が終わった)直後に呼ばれ、計算過程を一段ずつ見せてから
## 最終的な移動力だけを残すアニメーションを開始する。
## Called right after the die value settles (the 3D toss finishes); kicks off the animation
## that reveals the working-out a step at a time before leaving just the final movement value.
func _on_roll_finished() -> void:
	_animate_calc()


func _animate_calc() -> void:
	var die_tag := StatIcons.tag("Roll", StatIcons.DICE, str(_pending_die))
	var bag_tag := StatIcons.tag("Bag", StatIcons.TREASURE_COUNT, str(_pending_backpack_space))
	var move_tag := StatIcons.tag("Move", StatIcons.MOVE, str(_pending_movement))

	result_label.text = die_tag
	await get_tree().create_timer(STEP_DELAY).timeout

	result_label.text = "%s + %s" % [die_tag, bag_tag]
	await get_tree().create_timer(STEP_DELAY).timeout

	result_label.text = "%s + %s = %s" % [die_tag, bag_tag, move_tag]
	await get_tree().create_timer(STEP_DELAY).timeout

	result_label.text = move_tag


## enabled=falseは「選び終わった/CPUの手番」を意味するので、選択肢ボタン自体を隠す
## （選んだ後も選択肢が表示され続けて紛らわしいという声を受けて）。次のターンで
## enabled=trueになると再び表示される。
## enabled=false means "already chosen" or "CPU's turn", so the option buttons are hidden
## entirely (previously they stayed visible-but-disabled after choosing, which was confusing).
## They reappear once enabled=true is set again for the next turn.
func set_enabled(enabled: bool) -> void:
	for btn in option_buttons:
		btn.disabled = not enabled
		btn.visible = enabled
