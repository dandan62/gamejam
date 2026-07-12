extends RefCounted
class_name TreasureSpawner

## ゲーム開始時にTREASURE/RELICマスへ中身を1回だけ抽選して割り当てる。
## 誰かが取得すると taken=true になり、以後はEMPTY相当として扱われる
## （persist_tilesがtrueのマップでは taken にならず、代わりにそのマスの中身をtierから
## 改めて抽選し直す＝拾うたびに置いてある物が変わる）。
## At game start, rolls contents for TREASURE/RELIC tiles exactly once.
## Once someone picks it up, taken=true and the tile behaves like EMPTY from then on
## (on a map with persist_tiles=true, it never becomes taken -- instead the tile's contents are
## re-rolled from its tier on the spot, so what's sitting there changes every time it's taken).

var treasure_by_node: Dictionary = {}  # node_id -> {data: TreasureData, value: int, taken: bool, depth: int}
var relic_by_node: Dictionary = {}     # node_id -> {data: RelicData, taken: bool, depth: int}
var persist_tiles: bool = false


func setup(map_graph: MapGraph, persist_tiles: bool = false) -> void:
	treasure_by_node.clear()
	relic_by_node.clear()
	self.persist_tiles = persist_tiles
	for node in map_graph.get_all_nodes():
		var map_node: MapNodeDef = node
		if map_node.tile_type == MapNodeDef.TileType.TREASURE:
			var entry: Variant = _roll_treasure(map_node.depth)
			if entry != null:
				treasure_by_node[map_node.id] = entry
		elif map_node.tile_type == MapNodeDef.TileType.RELIC:
			var entry: Variant = _roll_relic(map_node.depth)
			if entry != null:
				relic_by_node[map_node.id] = entry


func _roll_treasure(depth: int) -> Variant:
	var tier := TierSelector.pick_tier(depth)
	var pool: Array = DataLoader.get_treasures_for_tier(tier)
	if pool.is_empty():
		return null
	var data: TreasureData = pool[randi() % pool.size()]
	var value := randi_range(data.min_value, data.max_value)
	return {"data": data, "value": value, "taken": false, "depth": depth}


func _roll_relic(depth: int) -> Variant:
	var tier := TierSelector.pick_tier(depth)
	var pool: Array = DataLoader.get_relics_for_tier(tier)
	if pool.is_empty():
		return null
	var data: RelicData = pool[randi() % pool.size()]
	return {"data": data, "taken": false, "depth": depth}


func has_available_treasure(node_id: int) -> bool:
	return treasure_by_node.has(node_id) and not treasure_by_node[node_id]["taken"]


func has_available_relic(node_id: int) -> bool:
	return relic_by_node.has(node_id) and not relic_by_node[node_id]["taken"]


## 取得: 現在の中身(entry)を返す。persist_tilesがtrueなら、返す前にそのマスの中身を
## 同じtierから改めて抽選し直して置き換える（＝一旦空にしてから新しい中身で更新するのと
## 同じ結果になる）。falseなら従来通りtaken=trueにするだけ。
## Pick up: returns the current contents (entry). If persist_tiles is true, before returning it
## re-rolls the tile's contents from the same tier and replaces them (equivalent to clearing the
## tile and then restocking it with something new). If false, just marks taken=true as before.
func take_treasure(node_id: int) -> Dictionary:
	var entry: Dictionary = treasure_by_node[node_id]
	if persist_tiles:
		var restocked: Variant = _roll_treasure(entry["depth"])
		if restocked != null:
			treasure_by_node[node_id] = restocked
	else:
		entry["taken"] = true
	return entry


func take_relic(node_id: int) -> RelicData:
	var entry: Dictionary = relic_by_node[node_id]
	if persist_tiles:
		var restocked: Variant = _roll_relic(entry["depth"])
		if restocked != null:
			relic_by_node[node_id] = restocked
	else:
		entry["taken"] = true
	return entry["data"]
