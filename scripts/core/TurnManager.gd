extends Node
class_name TurnManager

## 1ターンの進行を担うステートマシン。
## ターン開始時、プレイヤーは移動オプション(1〜3)を選ぶ。移動力自体はダイス1個＋
## バックパックの空き（＋MOVEバフ）のままオプションでは変わらないが、選んだ値がそのまま
## 「見える範囲(マス数、フォグ・オブ・ウォーの半径)」と「ターン終了時のライト消費量」になる
## （大きい数を選ぶほど遠くまで見えるが、ライトも多く減る）。
## ダイスで決まった移動力を使って1マスずつ進み、止まったマスごとにアクションを解決する
## （移動力を使い切るか、経路が尽きるか、帰還するまで繰り返す）。移動が終わると
## 見える範囲は0（現在地のみ）に戻る。
## 進行方向はターン開始時に固定されず、1マスごとに前進/後退を選び直せる。
## 人間プレイヤーの手番ではUIからの呼び出し(choose_movement_option/choose_path/...)を待ち、
## CPUの手番では各ステートに入った直後にCPUAIの判断で自動的に同じ関数を呼ぶ。
## State machine that drives a single turn.
## At the start of a turn, the player picks an option (1-3). Movement itself is unaffected by
## the option -- it's still 1 die roll + empty backpack space (+ any MOVE buff) -- but the
## chosen value directly becomes the visible range (fog-of-war radius, in tiles) and the Light
## spent at end of turn (picking a bigger number sees further but costs more Light).
## Using the dice-rolled movement budget, the player advances one tile at a time, resolving an
## action on each tile landed on (repeats until movement runs out, the path runs out, or the
## player returns to the surface). Once movement ends, the visible range drops back to 0
## (current tile only).
## Direction isn't locked in at the start of the turn -- forward/backward can be
## re-chosen on every single tile.
## On a human player's turn it waits for UI calls (choose_movement_option/choose_path/...);
## on a CPU turn it calls those same functions itself right after entering each state,
## using CPUAI's decisions.

enum State {
	IDLE,
	WAITING_MOVE_CHOICE,
	WAITING_STEP,
	WAITING_TILE_ACTION,
	WAITING_EVENT_CHOICE,
	GAME_OVER,
}

signal turn_started(player: PlayerState)
signal movement_option_chosen(player: PlayerState, option: int, die: int, backpack_space: int, movement: int)
signal vision_changed(radius: int)
signal movement_changed(player: PlayerState, remaining: int, total: int)
signal path_choices_ready(player: PlayerState, forward_ids: Array, backward_ids: Array)
signal player_moved(player: PlayerState, node_id: int)
signal player_returned(player: PlayerState, score_gained: int)
signal tile_action_needed(player: PlayerState, node: MapNodeDef, context: Dictionary)
signal event_choice_needed(player: PlayerState, event: EventData)
signal effect_applied(player: PlayerState, description: String)
signal player_eliminated(player: PlayerState)
signal turn_ended(player: PlayerState)
signal game_over(ranking: Array)

const MAX_ROUNDS := 8

var state: State = State.IDLE

var _movement: int = 0
var _remaining_steps: int = 0
var _current_node: MapNodeDef
var _pending_event: EventData
var _was_return: bool = false
var _light_cost: int = 1


func start_game() -> void:
	state = State.IDLE
	_start_turn(GameManager.get_current_player())


func _start_turn(player: PlayerState) -> void:
	if player == null:
		state = State.GAME_OVER
		game_over.emit(GameManager.get_ranking())
		return
	if player.status == PlayerState.Status.RETURNED:
		player.status = PlayerState.Status.ACTIVE
	_was_return = false
	state = State.WAITING_MOVE_CHOICE
	turn_started.emit(player)
	if player.is_cpu:
		choose_movement_option(CPUAI.choose_movement_option(player))


## option: 1〜3。移動力自体は変わらず(ダイス1個＋バックパックの空きのまま)、この値は
## 「見える範囲(マス数)」と「ターン終了時のライト消費量」だけを決める
## （大きく選ぶほど遠くまで見えるが、ライトも多く減る）。
## option: 1-3. Movement itself is unaffected (still 1 die roll + empty backpack space);
## this value only decides the visible range (in tiles) and the Light spent at end of turn
## (a bigger pick sees further but costs more Light).
func choose_movement_option(option: int) -> void:
	if state != State.WAITING_MOVE_CHOICE:
		return
	option = clamp(option, 1, 3)
	var player := GameManager.get_current_player()
	_light_cost = option
	vision_changed.emit(option)

	var die := DiceRoller.roll_1d6()
	var backpack_space := player.get_weight_capacity() - player.get_total_weight()
	_movement = die + backpack_space + player.get_stat_bonus(BuffData.Stat.MOVE)
	_movement = max(_movement, 0)
	movement_option_chosen.emit(player, option, die, backpack_space, _movement)

	var map_graph: MapGraph = GameManager.map_graph
	if _movement <= 0 or (not map_graph.has_forward(player.current_node_id) and not map_graph.has_backward(player.current_node_id)):
		movement_changed.emit(player, 0, _movement)
		_finish_turn(player)
		return

	_remaining_steps = _movement
	movement_changed.emit(player, _remaining_steps, _movement)
	_advance_one_step()


## 現在地から1マスだけ先の候補を、前進・後退の両方向まとめて提示する。
## 方向はターン開始時に固定するのではなく、1マス進むごとに毎回選び直せる
## （前進候補と後退候補を合わせて1つならCPU/自動で即決定、複数なら
## （人間なら盤面クリック、CPUならCPUAIで）選ばせる）。候補が無い
## （前後とも末端）場合はそこで移動を打ち切ってターンを終える。
## Presents the candidates exactly one tile ahead in both directions combined.
## Direction is no longer locked in at the start of the turn -- it can be chosen
## again on every single step (if there's only one candidate overall it's chosen
## automatically; with several, the player picks -- map click for humans, CPUAI
## for CPU). If there are no candidates in either direction, movement stops here
## and the turn ends.
func _advance_one_step() -> void:
	var player := GameManager.get_current_player()
	var map_graph: MapGraph = GameManager.map_graph
	var forward_ids: Array = map_graph.get_forward_ids(player.current_node_id)
	var backward_ids: Array = map_graph.get_backward_ids(player.current_node_id)
	var candidates: Array = forward_ids + backward_ids

	if candidates.is_empty():
		state = State.WAITING_MOVE_CHOICE
		_finish_turn(player)
		return

	state = State.WAITING_STEP
	path_choices_ready.emit(player, forward_ids, backward_ids)

	if candidates.size() == 1:
		choose_path(candidates[0])
	elif player.is_cpu:
		choose_path(CPUAI.choose_path(map_graph, player, forward_ids, backward_ids))


func choose_path(node_id: int) -> void:
	if state != State.WAITING_STEP:
		return
	var player := GameManager.get_current_player()
	var map_graph: MapGraph = GameManager.map_graph
	var forward_ids: Array = map_graph.get_forward_ids(player.current_node_id)
	var is_forward: bool = forward_ids.has(node_id)

	player.current_node_id = node_id
	player_moved.emit(player, node_id)

	var start_node_id: int = map_graph.definition.start_node_id
	if not is_forward and node_id == start_node_id:
		_resolve_return(player)
		return

	_remaining_steps -= 1
	movement_changed.emit(player, _remaining_steps, _movement)
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
				_after_tile_resolved(player)
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
			_after_tile_resolved(player)


## action: "pick_up" | "ignore"
func choose_tile_action(action: String) -> void:
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
	if _remaining_steps > 0:
		_advance_one_step()
		return
	state = State.WAITING_MOVE_CHOICE
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
		var light_cost: int = max(_light_cost - player.get_stat_bonus(BuffData.Stat.LIGHT), 0)
		player.light = max(player.light - light_cost, 0)
		_check_elimination(player)

	vision_changed.emit(0)
	turn_ended.emit(player)

	if not GameManager.has_non_eliminated_players():
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
