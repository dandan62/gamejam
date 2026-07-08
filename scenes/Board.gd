extends Control
class_name Board

## マップのノード・エッジ・プレイヤー駒を描画する盤面。
## ハイライトされている(=現在選択可能な)ノードはクリックで選択できる。
## Draws the map's nodes, edges, and player tokens.
## Highlighted (= currently selectable) nodes can be chosen by clicking them.

signal node_clicked(node_id: int)

var map_graph: MapGraph
var node_positions: Dictionary = {}
var highlighted_forward: Array = []
var highlighted_backward: Array = []

var visible_node_ids: Array = []  # node IDs the current player can see

const NODE_RADIUS := 18.0
const DEPTH_SPACING := 90.0
const LANE_SPACING := 90.0
const MARGIN := 60.0

var player_colors := [Color(0.2, 0.75, 0.35), Color(0.25, 0.55, 0.95), Color(0.95, 0.55, 0.15)]


func setup(graph: MapGraph) -> void:
	map_graph = graph
	_compute_positions()
	queue_redraw()


func _compute_positions() -> void:
	node_positions.clear()
	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		var x := MARGIN + n.lane * LANE_SPACING
		var y := MARGIN + n.depth * DEPTH_SPACING
		node_positions[n.id] = Vector2(x, y)


## forward_idsは奥へ進む候補、backward_idsは手前へ戻る候補。両方まとめてクリック可能にする。
## forward_ids are candidates deeper in, backward_ids are candidates back toward the surface.
## Both are clickable at once.
func set_highlighted(forward_ids: Array, backward_ids: Array) -> void:
	highlighted_forward = forward_ids
	highlighted_backward = backward_ids
	queue_redraw()
	
	
func set_visible_nodes(ids: Array) -> void:
	visible_node_ids = ids
	queue_redraw()

## ハイライト中のノードをクリックしたら node_clicked を発火する。
## Emits node_clicked when a currently-highlighted node is clicked.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	for node_id in highlighted_forward + highlighted_backward:
		if not node_positions.has(node_id):
			continue
		var pos: Vector2 = node_positions[node_id]
		if pos.distance_to(mb.position) <= NODE_RADIUS + 6.0:
			node_clicked.emit(node_id)
			return


const TREASURE_COLOR_LIGHT := Color(1.0, 0.95, 0.55)
const TREASURE_COLOR_DARK := Color(0.5, 0.22, 0.02)
const TREASURE_VALUE_BAND := 10
const TREASURE_MAX_BAND := 6


## 取得済みのお宝/遺物マスは何もないマスと同じ見た目にする。
## お宝マスは中身を見なくても強さの目安がわかるよう、価値が10上がるごとに
## 淡い黄色→濃い山吹色/こげ茶へ色が濃くなっていく。
## Already-claimed treasure/relic tiles look the same as an empty tile.
## Treasure tiles get darker every 10 points of value (pale yellow -> deep amber/brown),
## so players get a strength hint without seeing the exact number.
func _tile_color(node: MapNodeDef) -> Color:
	var tile_type := node.tile_type
	if tile_type == MapNodeDef.TileType.TREASURE and not GameManager.spawner.has_available_treasure(node.id):
		tile_type = MapNodeDef.TileType.EMPTY
	elif tile_type == MapNodeDef.TileType.RELIC and not GameManager.spawner.has_available_relic(node.id):
		tile_type = MapNodeDef.TileType.EMPTY

	match tile_type:
		MapNodeDef.TileType.START:
			return Color(0.85, 0.85, 0.9)
		MapNodeDef.TileType.TREASURE:
			var value: int = GameManager.spawner.treasure_by_node[node.id]["value"]
			return _treasure_color_for_value(value)
		MapNodeDef.TileType.EVENT:
			return Color(0.3, 0.6, 0.95)
		MapNodeDef.TileType.HAZARD:
			return Color(0.85, 0.25, 0.25)
		MapNodeDef.TileType.RELIC:
			return Color(0.65, 0.35, 0.85)
		_:
			return Color(0.6, 0.6, 0.65)


func _treasure_color_for_value(value: int) -> Color:
	var band: int = clamp(value / TREASURE_VALUE_BAND, 0, TREASURE_MAX_BAND)
	var t := float(band) / float(TREASURE_MAX_BAND)
	return TREASURE_COLOR_LIGHT.lerp(TREASURE_COLOR_DARK, t)


func _draw() -> void:
	if map_graph == null:
		return

	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		var from_pos: Vector2 = node_positions[n.id]
		for next_id in n.forward_connections:
			if node_positions.has(next_id):
				draw_line(from_pos, node_positions[next_id], Color(0.4, 0.4, 0.45), 3.0)

	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		var pos: Vector2 = node_positions[n.id]
		var is_visible: bool = visible_node_ids.is_empty() or visible_node_ids.has(n.id)
		var color := _tile_color(n) if is_visible else Color(0.15, 0.15, 0.18)
		if highlighted_forward.has(n.id):
			draw_circle(pos, NODE_RADIUS + 6, Color(1, 1, 1, 0.35))
		elif highlighted_backward.has(n.id):
			draw_circle(pos, NODE_RADIUS + 6, Color(0.3, 0.6, 1.0, 0.35))
		draw_circle(pos, NODE_RADIUS, color)
		draw_circle(pos, NODE_RADIUS, Color(0, 0, 0, 0.6), false, 2.0)

	var players: Array = GameManager.players
	for i in range(players.size()):
		var p: PlayerState = players[i]
		if p.status == PlayerState.Status.ELIMINATED:
			continue
		if not node_positions.has(p.current_node_id):
			continue
		var base_pos: Vector2 = node_positions[p.current_node_id]
		var offset := Vector2(cos(i * TAU / 3.0), sin(i * TAU / 3.0)) * 10.0
		draw_circle(base_pos + offset, 7.0, player_colors[i % player_colors.size()])
