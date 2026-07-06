extends RefCounted
class_name TreasureSpawner

## ゲーム開始時にTREASURE/RELICマスへ中身を1回だけ抽選して割り当てる。
## 誰かが取得すると taken=true になり、以後はEMPTY相当として扱われる。
## At game start, rolls contents for TREASURE/RELIC tiles exactly once.
## Once someone picks it up, taken=true and the tile behaves like EMPTY from then on.

var treasure_by_node: Dictionary = {}  # node_id -> {data: TreasureData, value: int, taken: bool}
var relic_by_node: Dictionary = {}     # node_id -> {data: RelicData, taken: bool}


func setup(map_graph: MapGraph) -> void:
	treasure_by_node.clear()
	relic_by_node.clear()
	for node in map_graph.get_all_nodes():
		var map_node: MapNodeDef = node
		if map_node.tile_type == MapNodeDef.TileType.TREASURE:
			var tier := TierSelector.pick_tier(map_node.depth)
			var pool: Array = DataLoader.get_treasures_for_tier(tier)
			if pool.is_empty():
				continue
			var data: TreasureData = pool[randi() % pool.size()]
			var value := randi_range(data.min_value, data.max_value)
			treasure_by_node[map_node.id] = {"data": data, "value": value, "taken": false}
		elif map_node.tile_type == MapNodeDef.TileType.RELIC:
			var relic_tier := TierSelector.pick_tier(map_node.depth)
			var relic_pool: Array = DataLoader.get_relics_for_tier(relic_tier)
			if relic_pool.is_empty():
				continue
			var data: RelicData = relic_pool[randi() % relic_pool.size()]
			relic_by_node[map_node.id] = {"data": data, "taken": false}


func has_available_treasure(node_id: int) -> bool:
	return treasure_by_node.has(node_id) and not treasure_by_node[node_id]["taken"]


func has_available_relic(node_id: int) -> bool:
	return relic_by_node.has(node_id) and not relic_by_node[node_id]["taken"]


func take_treasure(node_id: int) -> Dictionary:
	var entry: Dictionary = treasure_by_node[node_id]
	entry["taken"] = true
	return entry


func take_relic(node_id: int) -> RelicData:
	var entry: Dictionary = relic_by_node[node_id]
	entry["taken"] = true
	return entry["data"]
