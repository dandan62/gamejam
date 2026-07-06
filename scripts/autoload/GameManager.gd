extends Node

## プレイヤー一覧・ターン順・マップ/宝配置などゲーム全体の状態を保持するオートロード。
## 実際のターン進行ロジックはこれを参照する TurnManager（Main配下のノード）が担う。
## Autoload holding overall game state: player list, turn order, map/treasure placement, etc.
## The actual turn-progression logic lives in TurnManager (a node under Main), which reads this.

signal game_initialized

var players: Array = []          # Array[PlayerState]
var map_graph: MapGraph
var spawner: TreasureSpawner
var current_player_index: int = 0
var round_number: int = 1


func start_new_game(map_name: String = "") -> void:
	players.clear()
	var map_def: MapDefinition = DataLoader.get_map(map_name) if map_name != "" else DataLoader.get_first_map()
	if map_def == null:
		push_error("GameManager: no map found")
		return

	map_graph = MapGraph.new()
	map_graph.setup(map_def)

	spawner = TreasureSpawner.new()
	spawner.setup(map_graph)

	_add_player(0, "Player 1", false, map_def.start_node_id)
	_add_player(1, "Player 2", false, map_def.start_node_id)
	_add_player(2, "CPU", true, map_def.start_node_id)

	current_player_index = 0
	round_number = 1
	game_initialized.emit()


func _add_player(id: int, display_name: String, is_cpu: bool, start_node_id: int) -> void:
	var p := PlayerState.new()
	p.id = id
	p.display_name = display_name
	p.is_cpu = is_cpu
	p.current_node_id = start_node_id
	players.append(p)


func get_current_player() -> PlayerState:
	return players[current_player_index]


## 現在のプレイヤーから見て次にACTIVEなプレイヤーへ手番を移す。
## 全員終了していれば null を返す。全ACTIVEプレイヤーが1巡したらround_numberを進める。
## Advances the turn to the next ACTIVE player after the current one.
## Returns null if everyone is finished. Advances round_number once all ACTIVE players
## have had one turn each.
func advance_to_next_player() -> PlayerState:
	for i in range(1, players.size() + 1):
		var raw_next := current_player_index + i
		var idx := raw_next % players.size()
		if players[idx].status == PlayerState.Status.ACTIVE:
			if raw_next >= players.size():
				round_number += 1
			current_player_index = idx
			return players[idx]
	return null


func any_active_players() -> bool:
	for p in players:
		if p.status == PlayerState.Status.ACTIVE:
			return true
	return false


func get_ranking() -> Array:
	var sorted_players: Array = players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.banked_score > b.banked_score)
	return sorted_players
