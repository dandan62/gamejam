extends RefCounted
class_name MapGraph

## MapDefinitionからランタイムの隣接情報を構築する。
## Builds runtime adjacency info from a MapDefinition.

var definition: MapDefinition
var node_by_id: Dictionary = {}       # int -> MapNodeDef
var backward_map: Dictionary = {}     # int -> Array[int]
var broken_bridges: Dictionary = {}   # int -> true, node_ids of destroyed BRIDGE tiles


func setup(map_definition: MapDefinition) -> void:
	definition = map_definition
	node_by_id.clear()
	backward_map.clear()
	broken_bridges.clear()
	for node in definition.nodes:
		node_by_id[node.id] = node
	for node in definition.nodes:
		for next_id in node.forward_connections:
			if not backward_map.has(next_id):
				backward_map[next_id] = []
			backward_map[next_id].append(node.id)


## 橋マスを破壊済みにする。以後get_forward_ids/get_backward_idsの候補から除外され、誰も通れなくなる。
## Marks a bridge tile as destroyed. From then on it's excluded from get_forward_ids/get_backward_ids
## candidates, so no one can pass through it anymore.
func break_bridge(node_id: int) -> void:
	broken_bridges[node_id] = true


func is_bridge_broken(node_id: int) -> bool:
	return broken_bridges.get(node_id, false)


func get_all_nodes() -> Array:
	return node_by_id.values()


func get_node(node_id: int) -> MapNodeDef:
	return node_by_id.get(node_id, null)


func get_forward_ids(node_id: int) -> Array:
	var node: MapNodeDef = get_node(node_id)
	if node == null:
		return []
	return node.forward_connections.filter(func(id): return not is_bridge_broken(id))


func get_backward_ids(node_id: int) -> Array:
	var ids: Array = backward_map.get(node_id, [])
	return ids.filter(func(id): return not is_bridge_broken(id))


func has_forward(node_id: int) -> bool:
	return not get_forward_ids(node_id).is_empty()


func has_backward(node_id: int) -> bool:
	return not get_backward_ids(node_id).is_empty()


## start_idからhops歩以内（前進・後退どちらの辺も辿ってよい）で到達できるノードIDの集合を返す
## （start_id自身も含む、hops=0ならstart_idだけ）。視界（見える範囲）の計算に使う。
## Returns the set of node IDs reachable within `hops` steps of start_id, walking either
## forward or backward edges (start_id itself is included; hops=0 returns just start_id).
## Used to compute the player's visible range (fog of war).
func get_nodes_within_hops(start_id: int, hops: int) -> Array:
	var visited := {start_id: true}
	var frontier: Array = [start_id]
	for _i in range(hops):
		var next_frontier: Array = []
		for id in frontier:
			for neighbor_id in get_forward_ids(id) + get_backward_ids(id):
				if not visited.has(neighbor_id):
					visited[neighbor_id] = true
					next_frontier.append(neighbor_id)
		frontier = next_frontier
		if frontier.is_empty():
			break
	return visited.keys()
