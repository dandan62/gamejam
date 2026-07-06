extends Node
class_name TurnManager

## 1ターンの進行を担うステートマシン。
## 人間プレイヤーの手番ではUIからの呼び出し(roll_dice/choose_direction/...)を待ち、
## CPUの手番では各ステートに入った直後にCPUAIの判断で自動的に同じ関数を呼ぶ。
## State machine that drives a single turn.
## On a human player's turn it waits for UI calls (roll_dice/choose_direction/...);
## on a CPU turn it calls those same functions itself right after entering each state,
## using CPUAI's decisions.

enum State {
	IDLE,
	WAITING_ROLL,
	WAITING_DIRECTION,
	WAITING_PATH,
	WAITING_TILE_ACTION,
	WAITING_EVENT_CHOICE,
	GAME_OVER,
}

signal turn_started(player: PlayerState)
signal dice_rolled(player: PlayerState, dice: Dictionary, movement: int)
signal direction_choice_needed(player: PlayerState, can_forward: bool, can_backward: bool)
signal path_choices_ready(player: PlayerState, node_ids: Array, forward: bool)
signal player_moved(player: PlayerState, node_id: int)
signal player_returned(player: PlayerState, score_gained: int)
signal tile_action_needed(player: PlayerState, node: MapNodeDef, context: Dictionary)
signal event_choice_needed(player: PlayerState, event: EventData)
signal effect_applied(player: PlayerState, description: String)
signal player_eliminated(player: PlayerState)
signal turn_ended(player: PlayerState)
signal game_over(ranking: Array)

const MAX_ROUNDS := 15

var state: State = State.IDLE

var _movement: int = 0
var _forward: bool = true
var _current_node: MapNodeDef
var _pending_event: EventData
var _was_return: bool = false


func start_game() -> void:
	state = State.IDLE
	_start_turn(GameManager.get_current_player())


func _start_turn(player: PlayerState) -> void:
	if player == null:
		state = State.GAME_OVER
		game_over.emit(GameManager.get_ranking())
		return
	_was_return = false
	state = State.WAITING_ROLL
	turn_started.emit(player)
	if player.is_cpu:
		roll_dice()


func roll_dice() -> void:
	if state != State.WAITING_ROLL:
		return
	var player := GameManager.get_current_player()
	var dice := DiceRoller.roll_2d6()
	_movement = dice["total"] + player.get_stat_bonus(BuffData.Stat.MOVE)
	_movement = max(_movement, 0)
	dice_rolled.emit(player, dice, _movement)

	if _movement <= 0:
		_finish_turn(player)
		return

	var map_graph: MapGraph = GameManager.map_graph
	var can_forward := map_graph.has_forward(player.current_node_id)
	var can_backward := map_graph.has_backward(player.current_node_id)

	if not can_forward and not can_backward:
		_finish_turn(player)
		return

	state = State.WAITING_DIRECTION
	if can_forward and not can_backward:
		choose_direction(true)
		return
	if can_backward and not can_forward:
		choose_direction(false)
		return

	direction_choice_needed.emit(player, can_forward, can_backward)
	if player.is_cpu:
		choose_direction(CPUAI.choose_direction(player, map_graph))


func choose_direction(forward: bool) -> void:
	if state != State.WAITING_DIRECTION:
		return
	_forward = forward
	var player := GameManager.get_current_player()
	var map_graph: MapGraph = GameManager.map_graph
	var candidates: Array = map_graph.get_reachable(player.current_node_id, _movement, forward)

	state = State.WAITING_PATH
	path_choices_ready.emit(player, candidates, forward)

	if candidates.size() == 1:
		choose_path(candidates[0])
	elif player.is_cpu:
		choose_path(CPUAI.choose_path(map_graph, candidates))


func choose_path(node_id: int) -> void:
	if state != State.WAITING_PATH:
		return
	var player := GameManager.get_current_player()
	var map_graph: MapGraph = GameManager.map_graph

	player.current_node_id = node_id
	player_moved.emit(player, node_id)

	var start_node_id: int = map_graph.definition.start_node_id
	if not _forward and node_id == start_node_id:
		_resolve_return(player)
		return

	_current_node = map_graph.get_node(node_id)
	_resolve_tile(player)


func _resolve_return(player: PlayerState) -> void:
	_was_return = true
	var gained := player.bank_carried_treasures()
	player.light = player.max_light
	player.status = PlayerState.Status.RETURNED
	player_returned.emit(player, gained)
	_finish_turn(player)


func _resolve_tile(player: PlayerState) -> void:
	var node := _current_node
	match node.tile_type:
		MapNodeDef.TileType.TREASURE:
			if GameManager.spawner.has_available_treasure(node.id):
				state = State.WAITING_TILE_ACTION
				var entry: Dictionary = GameManager.spawner.treasure_by_node[node.id]
				var data: TreasureData = entry["data"]
				tile_action_needed.emit(player, node, {"kind": "treasure", "data": data, "value": entry["value"], "can_pick_up": player.can_pick_up(data)})
				if player.is_cpu:
					choose_tile_action(CPUAI.choose_treasure_action(player, data))
			else:
				_resolve_empty(player)
		MapNodeDef.TileType.RELIC:
			if GameManager.spawner.has_available_relic(node.id):
				state = State.WAITING_TILE_ACTION
				var relic: RelicData = GameManager.spawner.relic_by_node[node.id]["data"]
				tile_action_needed.emit(player, node, {"kind": "relic", "data": relic})
				if player.is_cpu:
					choose_tile_action(CPUAI.choose_relic_action())
			else:
				_after_tile_resolved(player)
		MapNodeDef.TileType.EVENT:
			var event: EventData = DataLoader.events_by_id.get(node.fixed_event_id, null)
			if event == null:
				event = DataLoader.get_event_for_tier(TierSelector.pick_tier(node.depth))
			if event == null:
				_after_tile_resolved(player)
				return
			_pending_event = event
			state = State.WAITING_EVENT_CHOICE
			event_choice_needed.emit(player, event)
			if player.is_cpu:
				choose_event(CPUAI.choose_event(event))
		MapNodeDef.TileType.HAZARD:
			var hazard: HazardData = DataLoader.hazards_by_id.get(node.fixed_hazard_id, null)
			if hazard == null:
				hazard = DataLoader.get_hazard_for_tier(TierSelector.pick_tier(node.depth))
			if hazard != null:
				_apply_effect(player, hazard.effect)
				effect_applied.emit(player, hazard.description)
			_after_tile_resolved(player)
		_:
			_resolve_empty(player)


func _resolve_empty(player: PlayerState) -> void:
	state = State.WAITING_TILE_ACTION
	tile_action_needed.emit(player, _current_node, {"kind": "empty", "can_discard": not player.carried_treasures.is_empty()})
	if player.is_cpu:
		choose_tile_action(CPUAI.choose_empty_action())


## action: "pick_up" | "ignore" | "discard"
## extra: discardの場合 {"index": int}
## action: "pick_up" | "ignore" | "discard"
## extra: {"index": int} when action is "discard"
func choose_tile_action(action: String, extra: Dictionary = {}) -> void:
	if state != State.WAITING_TILE_ACTION:
		return
	var player := GameManager.get_current_player()
	var node := _current_node

	if action == "pick_up":
		if node.tile_type == MapNodeDef.TileType.TREASURE:
			var preview: Dictionary = GameManager.spawner.treasure_by_node[node.id]
			if player.can_pick_up(preview["data"]):
				var entry: Dictionary = GameManager.spawner.take_treasure(node.id)
				player.pick_up_treasure(entry["data"], entry["value"])
		elif node.tile_type == MapNodeDef.TileType.RELIC:
			var relic: RelicData = GameManager.spawner.take_relic(node.id)
			player.add_relic_buffs(relic.buffs)
	elif action == "discard":
		if extra.has("index"):
			player.drop_treasure(int(extra["index"]))

	_after_tile_resolved(player)


func choose_event(choice: String) -> void:
	if state != State.WAITING_EVENT_CHOICE:
		return
	var player := GameManager.get_current_player()
	var effect: EffectData = _pending_event.choice_a_effect if choice == "a" else _pending_event.choice_b_effect
	_apply_effect(player, effect)
	_pending_event = null
	_after_tile_resolved(player)


func _apply_effect(player: PlayerState, effect: EffectData) -> void:
	if effect == null:
		return
	player.hp = max(player.hp + effect.hp_delta, 0)
	player.light = clamp(player.light + effect.light_delta, 0, player.max_light)
	player.banked_score += effect.score_delta
	if effect.apply_buff != null:
		player.permanent_buffs.append(effect.apply_buff)
	for i in range(effect.drop_treasure_count):
		if player.carried_treasures.is_empty():
			break
		player.carried_treasures.remove_at(player.carried_treasures.size() - 1)
	if effect.next_treasure_multiplier != 1.0:
		player.next_treasure_multiplier = effect.next_treasure_multiplier


func _after_tile_resolved(player: PlayerState) -> void:
	if _check_elimination(player):
		_finish_turn(player)
		return
	state = State.WAITING_ROLL
	_finish_turn(player)


func _check_elimination(player: PlayerState) -> bool:
	if player.status != PlayerState.Status.ACTIVE:
		return false
	if player.hp <= 0 or player.light <= 0:
		player.lose_all_carried_treasures()
		player.status = PlayerState.Status.ELIMINATED
		player_eliminated.emit(player)
		return true
	return false


func _finish_turn(player: PlayerState) -> void:
	if not _was_return and player.status == PlayerState.Status.ACTIVE:
		var light_cost: int = max(1 - player.get_stat_bonus(BuffData.Stat.LIGHT), 0)
		player.light = max(player.light - light_cost, 0)
		_check_elimination(player)

	turn_ended.emit(player)

	if not GameManager.any_active_players():
		state = State.GAME_OVER
		game_over.emit(GameManager.get_ranking())
		return

	var next_player := GameManager.advance_to_next_player()

	if GameManager.round_number > MAX_ROUNDS:
		_force_end_by_round_limit()
		return

	_start_turn(next_player)


## ラウンド上限に達した時点でまだ潜行中(ACTIVE)のプレイヤーは、
## 未帰還のお宝を全ロストして脱落扱いとし、強制的にゲームを終了する。
## Once the round limit is reached, any player still diving (ACTIVE) loses
## all unreturned treasure, is marked as eliminated, and the game is force-ended.
func _force_end_by_round_limit() -> void:
	for p in GameManager.players:
		if p.status == PlayerState.Status.ACTIVE:
			p.lose_all_carried_treasures()
			p.status = PlayerState.Status.ELIMINATED
			player_eliminated.emit(p)
	state = State.GAME_OVER
	game_over.emit(GameManager.get_ranking())
