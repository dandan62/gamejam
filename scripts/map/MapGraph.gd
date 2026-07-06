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
