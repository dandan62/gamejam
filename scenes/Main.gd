extends Control

var turn_manager: TurnManager
var board: Board
var hud: HUD
var dice_ui: DiceUI
var action_panel: ActionPanel
var event_popup: EventPopup
var game_over_screen: GameOverScreen
var round_label: Label



func _ready() -> void:
	GameManager.start_new_game()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(760, 900)
	add_child(scroll)

	board = Board.new()
	GameManager.board = board
	board.custom_minimum_size = Vector2(560, 1900)
	board.setup(GameManager.map_graph)
	board.node_clicked.connect(_on_board_node_clicked)
	scroll.add_child(board)

	var side_scroll := ScrollContainer.new()
	side_scroll.position = Vector2(800, 20)
	side_scroll.size = Vector2(780, 900)
	add_child(side_scroll)

	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(760, 0)
	side_scroll.add_child(side_panel)

	hud = HUD.new()
	side_panel.add_child(hud)
	hud.setup(GameManager.players)

	dice_ui = DiceUI.new()
	side_panel.add_child(dice_ui)
	dice_ui.roll_pressed.connect(_on_roll_pressed)

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
	turn_manager.dice_rolled.connect(_on_dice_rolled)
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
	board.queue_redraw()


func _close_all_prompts() -> void:
	action_panel.close()
	event_popup.close()


func _on_turn_started(player: PlayerState) -> void:
	dice_ui.set_enabled(not player.is_cpu)
	hud.set_movement(player, 0, 0)
	_close_all_prompts()
	_refresh_all()


func _on_roll_pressed() -> void:
	turn_manager.roll_dice()


func _on_dice_rolled(_player: PlayerState, die: int, backpack_space: int, movement: int) -> void:
	dice_ui.show_result(die, backpack_space, movement)
	dice_ui.set_enabled(false)


func _on_movement_changed(player: PlayerState, remaining: int, total: int) -> void:
	hud.set_movement(player, remaining, total)
	_refresh_all()


func _on_path_choices_ready(_player: PlayerState, forward_ids: Array, backward_ids: Array) -> void:
	board.set_highlighted(forward_ids, backward_ids)


func _on_board_node_clicked(node_id: int) -> void:
	turn_manager.choose_path(node_id)


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
	_refresh_all()
	game_over_screen.show_ranking(ranking)
