extends RefCounted
class_name CPUAI

## 簡易ヒューリスティックAI。深い探索はせず、残ライトや所持お宝の量から
## 前進/後退を判断し、マスの内容に応じて目的地やイベント選択肢を選ぶ。
## 方向はターン開始時ではなく1マスごとに判断し直す。
## Simple heuristic AI. Does no deep search; decides advance/retreat from remaining
## light and how much treasure is carried, and picks destinations/event choices by tile content.
## Direction is re-evaluated every single tile rather than once per turn.

## ターン開始時のオプション(1〜3、見える範囲とライト消費量を決める。移動力自体には影響しない)
## を残りライトから決める。残りが少なければ小さいオプションでライトを温存し、余裕があれば
## 大きいオプションで見える範囲を広げる。
## Picks the turn's option (1-3, which sets the visible range and Light cost -- it doesn't
## affect movement itself) from remaining Light. Conserves Light with a small option when low,
## widens the visible range with a bigger option when there's headroom.
static func choose_movement_option(player: PlayerState) -> int:
	if player.light <= 3:
		return 1
	if player.light <= 6:
		return 2
	return 3


## その1マスで前進/後退のどちらを選ぶかを決め、選んだ側の中から目的地を選ぶ。
## Decides forward vs. backward for this one tile, then picks a destination
## among the candidates on the chosen side.
static func choose_path(map_graph: MapGraph, player: PlayerState, forward_ids: Array, backward_ids: Array) -> int:
	if _wants_retreat(player, forward_ids, backward_ids):
		return backward_ids[0]
	if not forward_ids.is_empty():
		return _best_forward(map_graph, forward_ids)
	return backward_ids[0]


static func _wants_retreat(player: PlayerState, forward_ids: Array, backward_ids: Array) -> bool:
	if backward_ids.is_empty():
		return false
	if forward_ids.is_empty():
		return true
	if player.light <= 2 and not player.carried_treasures.is_empty():
		return true
	if player.carried_treasures.size() >= 3:
		return true
	return false


static func _best_forward(map_graph: MapGraph, candidates: Array) -> int:
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
