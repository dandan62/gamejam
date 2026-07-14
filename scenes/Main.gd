extends Control

const MARGIN := 20.0
const GAP := 20.0

var turn_manager: TurnManager
var board: Board
var hud: HUD
var dice_ui: DiceUI
var action_panel: ActionPanel
var event_popup: EventPopup
var game_over_screen: GameOverScreen
var round_label: Label
var turn_countdown_label: Label
var movement_label: Label
var movement_panel: PanelContainer
var map_legend: MapLegend
var map_select_panel: PanelContainer


## マップが2つ以上あるときだけ、開始前にマップ選択画面を出す。1つしか無ければ従来通り
## 即座にそれで始める。
## Only shows a map-select screen up front when 2+ maps exist. With just one, starts it
## immediately as before.
func _ready() -> void:
	var map_names: Array = DataLoader.maps.keys()
	if map_names.size() <= 1:
		_start_game(DataLoader.get_first_map().map_name if not map_names.is_empty() else "")
	else:
		_show_map_select(map_names)


func _show_map_select(map_names: Array) -> void:
	map_select_panel = PanelContainer.new()
	map_select_panel.position = Vector2(500, 300)
	map_select_panel.size = Vector2(400, 300)
	add_child(map_select_panel)

	var vbox := VBoxContainer.new()
	map_select_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose a Map"
	vbox.add_child(title)

	for map_name in map_names:
		var btn := Button.new()
		btn.text = map_name
		btn.pressed.connect(func(): _start_game(map_name))
		vbox.add_child(btn)


func _start_game(map_name: String) -> void:
	if map_select_panel != null:
		map_select_panel.queue_free()
		map_select_panel = null

	GameManager.start_new_game(map_name)

	## マップ側とステータス側の横幅を6:4の比率で割り振る
	## （左右マージン20px・間のギャップ20pxを引いた残りを6:4で分ける）。
	## Splits the width between the map area and the status area at a 6:4 ratio
	## (after subtracting the 20px side margins and the 20px gap between them).
	var available_width := 1600.0 - MARGIN * 2.0 - GAP
	var map_width := available_width * 0.6
	var status_width := available_width - map_width
	var status_x := MARGIN + map_width + GAP

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(MARGIN, 20)
	scroll.size = Vector2(map_width, 900)
	add_child(scroll)

	board = Board.new()
	board.custom_minimum_size = Board.CANVAS_SIZE
	board.setup(GameManager.map_graph)
	board.node_clicked.connect(_on_board_node_clicked)
	scroll.add_child(board)

	## マップ(scroll)の上に固定表示する残りターン数の警告。scrollの外の兄弟ノードとして
	## 同じ座標に重ねているので、盤面をスクロールしても位置がずれない。
	## Fixed warning banner overlaid on top of the map (scroll). It's a sibling positioned at the
	## same coordinates rather than a child of scroll, so it doesn't move when the board scrolls.
	turn_countdown_label = Label.new()
	add_child(turn_countdown_label)
	turn_countdown_label.position = Vector2(MARGIN, 20)
	turn_countdown_label.size = Vector2(map_width, 40)
	turn_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_countdown_label.add_theme_font_size_override("font_size", 28)
	turn_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	turn_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_countdown_label.add_theme_constant_override("outline_size", 6)

	## マップ(scroll)の右上に重ねて表示するマス凡例＋その下の残り移動回数パネル。
	## turn_countdown_labelと同じく、scrollの外の兄弟ノード(right_overlay)を固定座標に
	## 置くことで、盤面をスクロールしても位置がずれない。VBoxContainerで縦に並べているので、
	## マス凡例がプルダウンで開閉して高さが変わっても、移動回数パネルは常にその真下に来る。
	## turn_countdown_labelの帯(y=20〜60)とは重ならないよう、その下から始める。
	## Tile legend + the remaining-move-count panel below it, overlaid at the map's top-right
	## corner. Same trick as turn_countdown_label -- a sibling (right_overlay) positioned at a
	## fixed coordinate outside scroll, so it doesn't move when the board scrolls. Stacked in a
	## VBoxContainer so the movement panel always sits directly below the legend even as the
	## legend's pulldown changes its height. Starts below turn_countdown_label's band (y=20-60)
	## so they don't overlap.
	var right_overlay := VBoxContainer.new()
	add_child(right_overlay)
	right_overlay.position = Vector2(MARGIN + map_width - MapLegend.PANEL_WIDTH, 65)
	right_overlay.add_theme_constant_override("separation", 10)

	map_legend = MapLegend.new()
	right_overlay.add_child(map_legend)

	movement_panel = PanelContainer.new()
	movement_panel.custom_minimum_size = Vector2(MapLegend.PANEL_WIDTH, MapLegend.PANEL_WIDTH)
	right_overlay.add_child(movement_panel)
	var movement_panel_style := StyleBoxFlat.new()
	movement_panel_style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	movement_panel_style.border_color = Color(0.55, 0.15, 0.8)
	movement_panel_style.set_border_width_all(3)
	movement_panel.add_theme_stylebox_override("panel", movement_panel_style)

	var movement_vbox := VBoxContainer.new()
	movement_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	movement_panel.add_child(movement_vbox)

	var movement_title := Label.new()
	movement_title.text = "残り移動回数"
	movement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_vbox.add_child(movement_title)

	movement_label = Label.new()
	movement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var movement_font := SystemFont.new()
	movement_font.font_weight = 700
	movement_label.add_theme_font_override("font", movement_font)
	movement_label.add_theme_font_size_override("font_size", 120)
	movement_label.add_theme_color_override("font_color", Color(0.55, 0.15, 0.8))
	movement_label.add_theme_color_override("font_outline_color", Color.BLACK)
	movement_label.add_theme_constant_override("outline_size", 6)
	movement_vbox.add_child(movement_label)

	var side_scroll := ScrollContainer.new()
	side_scroll.position = Vector2(status_x, 20)
	side_scroll.size = Vector2(status_width, 900)
	add_child(side_scroll)

	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(status_width - 20.0, 0)
	side_scroll.add_child(side_panel)

	hud = HUD.new()
	side_panel.add_child(hud)
	hud.setup(GameManager.players)

	dice_ui = DiceUI.new()
	side_panel.add_child(dice_ui)
	dice_ui.option_chosen.connect(_on_option_chosen)

	action_panel = ActionPanel.new()
	side_panel.add_child(action_panel)
	action_panel.action_chosen.connect(_on_action_chosen)

	event_popup = EventPopup.new()
	side_panel.add_child(event_popup)
	event_popup.choice_made.connect(_on_event_choice)

	game_over_screen = GameOverScreen.new()
	game_over_screen.position = Vector2(350, 230)
	game_over_screen.size = Vector2(900, 500)
	add_child(game_over_screen)

	round_label = Label.new()
	add_child(round_label)
	round_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	round_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	round_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	round_label.position -= Vector2(20, 20)

	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.movement_option_chosen.connect(_on_movement_option_chosen)
	turn_manager.vision_changed.connect(_on_vision_changed)
	turn_manager.movement_changed.connect(_on_movement_changed)
	turn_manager.path_choices_ready.connect(_on_path_choices_ready)
	turn_manager.player_moved.connect(_on_player_moved)
	turn_manager.player_returned.connect(_on_player_returned)
	turn_manager.tile_action_needed.connect(_on_tile_action_needed)
	turn_manager.event_choice_needed.connect(_on_event_choice_needed)
	turn_manager.player_eliminated.connect(_on_player_eliminated)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.game_over.connect(_on_game_over)

	turn_manager.start_game()


func _refresh_all() -> void:
	hud.refresh(GameManager.players)
	round_label.text = "Round %d / %d" % [GameManager.round_number, TurnManager.MAX_ROUNDS]
	board.set_remaining_rounds(TurnManager.MAX_ROUNDS - GameManager.round_number + 1)
	board.queue_redraw()


func _close_all_prompts() -> void:
	action_panel.close()
	event_popup.close()


func _on_turn_started(player: PlayerState) -> void:
	dice_ui.set_enabled(not player.is_cpu)
	hud.set_active_player(player.id)
	movement_label.text = ""
	_close_all_prompts()
	_refresh_all()
	_update_turn_countdown()


## ラウンド上限が近いことを、ターン開始からダイスを振るまでの間だけ知らせる
## （"3 turns left" → "2 turns left" → "last turn"）。ダイスを振った時点(_on_movement_option_chosen)で消す。
## Warns that the round limit is close, only for the window between turn start and rolling the
## dice ("3 turns left" -> "2 turns left" -> "last turn"). Cleared once the dice are rolled
## (_on_movement_option_chosen).
func _update_turn_countdown() -> void:
	var remaining := TurnManager.MAX_ROUNDS - GameManager.round_number + 1
	match remaining:
		3:
			turn_countdown_label.text = "3 turns left"
		2:
			turn_countdown_label.text = "2 turns left"
		1:
			turn_countdown_label.text = "last turn"
		_:
			turn_countdown_label.text = ""


func _on_option_chosen(option: int) -> void:
	turn_manager.choose_movement_option(option)


func _on_movement_option_chosen(_player: PlayerState, option: int, die: int, backpack_space: int, movement: int) -> void:
	dice_ui.show_result(option, die, backpack_space, movement)
	dice_ui.set_enabled(false)
	turn_countdown_label.text = ""


func _on_vision_changed(radius: int) -> void:
	board.set_vision_radius(radius)


func _on_movement_changed(_player: PlayerState, remaining: int, _total: int) -> void:
	movement_label.text = str(remaining)
	_refresh_all()


func _on_path_choices_ready(_player: PlayerState, forward_ids: Array, backward_ids: Array) -> void:
	board.set_highlighted(forward_ids, backward_ids)


func _on_board_node_clicked(node_id: int) -> void:
	action_panel.close()
	turn_manager.handle_board_click(node_id)


func _on_player_moved(_player: PlayerState, _node_id: int) -> void:
	board.set_highlighted([], [])
	_refresh_all()


func _on_player_returned(_player: PlayerState, _score_gained: int) -> void:
	_refresh_all()


func _on_tile_action_needed(player: PlayerState, _node: MapNodeDef, context: Dictionary) -> void:
	if not player.is_cpu:
		action_panel.prompt(context)


func _on_action_chosen(action: String) -> void:
	action_panel.close()
	turn_manager.choose_tile_action(action)


func _on_event_choice_needed(player: PlayerState, event: EventData) -> void:
	if not player.is_cpu:
		event_popup.prompt(event)


func _on_event_choice(choice: String) -> void:
	event_popup.close()
	turn_manager.choose_event(choice)


func _on_player_eliminated(_player: PlayerState) -> void:
	_refresh_all()


func _on_turn_ended(_player: PlayerState) -> void:
	_refresh_all()


func _on_game_over(ranking: Array) -> void:
	board.set_vision_radius(0)
	movement_label.text = ""
	hud.set_active_player(-1)
	_refresh_all()
	game_over_screen.show_ranking(ranking)
