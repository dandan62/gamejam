extends RefCounted
class_name MapGraph

## MapDefinitionからランタイムの隣接情報を構築し、
## 「現在地からちょうどN歩、前進/後退した場合に到達できるノード」を計算する。
## Builds runtime adjacency info from a MapDefinition and computes
## "which nodes are reachable from here after moving exactly N steps forward/backward."

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


## forward=trueなら奥へ、falseなら地上方向へ、ちょうどsteps歩進んだ場合に
## 到達できる終着ノードID一覧を返す。経路が途中で尽きた場合（分岐の末端、
## または後退でスタート地点=深度0に到達）はそこで打ち止めとして扱う。
## Returns the destination node IDs reachable after moving exactly `steps` steps,
## deeper if forward=true or toward the surface if forward=false. If a path runs out early
## (a branch dead-end, or reaching the start node at depth 0 while retreating), it stops there.
func get_reachable(current_id: int, steps: int, forward: bool) -> Array:
	var results: Dictionary = {}
	_walk(current_id, steps, forward, results)
	return results.keys()


func _walk(node_id: int, remaining: int, forward: bool, results: Dictionary) -> void:
	var next_ids: Array = get_forward_ids(node_id) if forward else get_backward_ids(node_id)
	if remaining <= 0 or next_ids.is_empty():
		results[node_id] = true
		return
	for next_id in next_ids:
		_walk(next_id, remaining - 1, forward, results)


func has_forward(node_id: int) -> bool:
	return not get_forward_ids(node_id).is_empty()


func has_backward(node_id: int) -> bool:
	return not get_backward_ids(node_id).is_empty()
