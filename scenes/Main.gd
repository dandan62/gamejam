extends Control

var turn_manager: TurnManager
var board: Board
var hud: HUD
var dice_ui: DiceUI
var direction_panel: DirectionPanel
var action_panel: ActionPanel
var event_popup: EventPopup
var game_over_screen: GameOverScreen


func _ready() -> void:
	GameManager.start_new_game()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(700, 680)
	add_child(scroll)

	board = Board.new()
	board.custom_minimum_size = Vector2(500, 1900)
	board.setup(GameManager.map_graph)
	board.node_clicked.connect(_on_board_node_clicked)
	scroll.add_child(board)

	var side_panel := VBoxContainer.new()
	side_panel.position = Vector2(740, 20)
	side_panel.size = Vector2(520, 680)
	add_child(side_panel)

	hud = HUD.new()
	side_panel.add_child(hud)
	hud.setup(GameManager.players)

	dice_ui = DiceUI.new()
	side_panel.add_child(dice_ui)
	dice_ui.roll_pressed.connect(_on_roll_pressed)

	direction_panel = DirectionPanel.new()
	side_panel.add_child(direction_panel)
	direction_panel.direction_chosen.connect(_on_direction_chosen)

	action_panel = ActionPanel.new()
	side_panel.add_child(action_panel)
	action_panel.action_chosen.connect(_on_action_chosen)

	event_popup = EventPopup.new()
	side_panel.add_child(event_popup)
	event_popup.choice_made.connect(_on_event_choice)

	game_over_screen = GameOverScreen.new()
	game_over_screen.position = Vector2(300, 200)
	game_over_screen.size = Vector2(600, 400)
	add_child(game_over_screen)

	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.dice_rolled.connect(_on_dice_rolled)
	turn_manager.direction_choice_needed.connect(_on_direction_choice_needed)
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
	board.queue_redraw()


func _close_all_prompts() -> void:
	direction_panel.close()
	action_panel.close()
	event_popup.close()


func _on_turn_started(player: PlayerState) -> void:
	dice_ui.set_enabled(not player.is_cpu)
	_close_all_prompts()
	_refresh_all()


func _on_roll_pressed() -> void:
	turn_manager.roll_dice()


func _on_dice_rolled(_player: PlayerState, dice: Dictionary, movement: int) -> void:
	dice_ui.show_result(dice, movement)
	dice_ui.set_enabled(false)


func _on_direction_choice_needed(player: PlayerState, can_forward: bool, can_backward: bool) -> void:
	if not player.is_cpu:
		direction_panel.prompt(can_forward, can_backward)


func _on_direction_chosen(forward: bool) -> void:
	direction_panel.close()
	turn_manager.choose_direction(forward)


func _on_path_choices_ready(_player: PlayerState, node_ids: Array, _forward: bool) -> void:
	board.set_highlighted(node_ids)


func _on_board_node_clicked(node_id: int) -> void:
	turn_manager.choose_path(node_id)


func _on_player_moved(_player: PlayerState, _node_id: int) -> void:
	board.set_highlighted([])
	_refresh_all()


func _on_player_returned(_player: PlayerState, _score_gained: int) -> void:
	_refresh_all()


func _on_tile_action_needed(player: PlayerState, node: MapNodeDef, context: Dictionary) -> void:
	if not player.is_cpu:
		action_panel.prompt(player, node, context)


func _on_action_chosen(action: String, extra: Dictionary) -> void:
	action_panel.close()
	turn_manager.choose_tile_action(action, extra)


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
