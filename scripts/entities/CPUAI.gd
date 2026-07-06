extends RefCounted
class_name CPUAI

## 簡易ヒューリスティックAI。深い探索はせず、残ライトや所持お宝の量から
## 前進/後退を判断し、マスの内容に応じて目的地やイベント選択肢を選ぶ。
## Simple heuristic AI. Does no deep search; decides advance/retreat from remaining
## light and how much treasure is carried, and picks destinations/event choices by tile content.

static func choose_direction(player: PlayerState, map_graph: MapGraph) -> bool:
	var can_forward := map_graph.has_forward(player.current_node_id)
	var can_backward := map_graph.has_backward(player.current_node_id)
	if can_forward and not can_backward:
		return true
	if can_backward and not can_forward:
		return false
	if player.light <= 2 and not player.carried_treasures.is_empty():
		return false
	if player.carried_treasures.size() >= 3:
		return false
	return true


static func choose_path(map_graph: MapGraph, candidates: Array) -> int:
	if candidates.is_empty():
		return -1
	var best_id: int = candidates[0]
	var best_score: int = -999
	for node_id in candidates:
		var node: MapNodeDef = map_graph.get_node(node_id)
		var score := 0
		match node.tile_type:
			MapNodeDef.TileType.TREASURE:
				score = 3
			MapNodeDef.TileType.RELIC:
				score = 2
			MapNodeDef.TileType.EVENT:
				score = 1
			MapNodeDef.TileType.EMPTY:
				score = 0
			MapNodeDef.TileType.HAZARD:
				score = -2
		if score > best_score:
			best_score = score
			best_id = node_id
	return best_id


static func choose_treasure_action(player: PlayerState, treasure_data: TreasureData) -> String:
	if treasure_data != null and player.can_pick_up(treasure_data):
		return "pick_up"
	return "ignore"


static func choose_relic_action() -> String:
	return "pick_up"


static func choose_empty_action() -> String:
	return "ignore"


static func choose_event(event: EventData) -> String:
	var score_a := _score_effect(event.choice_a_effect)
	var score_b := _score_effect(event.choice_b_effect)
	return "a" if score_a >= score_b else "b"


static func _score_effect(effect: EffectData) -> float:
	if effect == null:
		return 0.0
	var score := 0.0
	score += effect.hp_delta * 2.0
	score += effect.light_delta * 1.5
	score += effect.score_delta * 0.5
	score -= effect.drop_treasure_count * 2.0
	if effect.next_treasure_multiplier > 1.0:
		score += 1.0
	return score
