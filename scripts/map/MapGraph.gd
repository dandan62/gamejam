extends RefCounted
class_name MapGraph

## MapDefinitionからランタイムの隣接情報を構築する。
## Builds runtime adjacency info from a MapDefinition.

var definition: MapDefinition
var node_by_id: Dictionary = {}       # int -> MapNodeDef
var backward_map: Dictionary = {}     # int -> Array[int]


func setup(map_definition: MapDefinition) -> void:
	definition = map_definition
	node_by_id.clear()
	backward_map.clear()
	for node in definition.nodes:
		node_by_id[node.id] = node
	for node in definition.nodes:
		for next_id in node.forward_connections:
			if not backward_map.has(next_id):
				backward_map[next_id] = []
			backward_map[next_id].append(node.id)


func get_all_nodes() -> Array:
	return node_by_id.values()


func get_node(node_id: int) -> MapNodeDef:
	return node_by_id.get(node_id, null)


func get_forward_ids(node_id: int) -> Array:
	var node: MapNodeDef = get_node(node_id)
	if node == null:
		return []
	return node.forward_connections


func get_backward_ids(node_id: int) -> Array:
	return backward_map.get(node_id, [])


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
