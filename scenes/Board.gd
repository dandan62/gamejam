extends Control
class_name Board

## マップのノード・エッジ・プレイヤー駒を描画する盤面。
## ハイライトされている(=現在選択可能な)ノードはクリックで選択できる。
## 盤面全体は黒で覆われており、現在の手番プレイヤーの現在地からvision_radiusホップ以内
## （set_vision_radiusで設定）のマスだけが見える（フォグ・オブ・ウォー）。
## Draws the map's nodes, edges, and player tokens.
## Highlighted (= currently selectable) nodes can be chosen by clicking them.
## The whole board is covered in black; only tiles within vision_radius hops of the current
## turn's player position (set via set_vision_radius) are revealed (fog of war).

signal node_clicked(node_id: int)

var map_graph: MapGraph
var node_positions: Dictionary = {}
var highlighted_forward: Array = []
var highlighted_backward: Array = []
var vision_radius: int = 0

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


## 見える範囲（現在の手番プレイヤーの現在地からのホップ数）を設定する。
## 0なら現在地のマスしか見えない。マップ全体は黒で覆われ、見える範囲外は描画されない。
## Sets the visible range (in hops from the current turn's player position).
## 0 means only the current tile is visible. The rest of the map stays covered in black.
func set_vision_radius(radius: int) -> void:
	vision_radius = radius
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
		MapNodeDef.TileType.TREASURE:
			var value: int = GameManager.spawner.treasure_by_node[node.id]["value"]
			return _treasure_color_for_value(value)
		MapNodeDef.TileType.BRIDGE:
			if map_graph.is_bridge_broken(node.id):
				return TileIcons.BRIDGE_BROKEN_COLOR
			return TileIcons.BRIDGE_COLOR
		_:
			return TileIcons.color_for(tile_type)


func _treasure_color_for_value(value: int) -> Color:
	var band: int = clamp(value / TREASURE_VALUE_BAND, 0, TREASURE_MAX_BAND)
	var t := float(band) / float(TREASURE_MAX_BAND)
	return TREASURE_COLOR_LIGHT.lerp(TREASURE_COLOR_DARK, t)


func _draw() -> void:
	if map_graph == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)

	var revealed: Dictionary = {}
	var current_player := GameManager.get_current_player()
	if current_player != null:
		for id in map_graph.get_nodes_within_hops(current_player.current_node_id, vision_radius):
			revealed[id] = true

	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		if not revealed.has(n.id):
			continue
		var from_pos: Vector2 = node_positions[n.id]
		for next_id in n.forward_connections:
			if revealed.has(next_id) and node_positions.has(next_id):
				draw_line(from_pos, node_positions[next_id], Color(0.4, 0.4, 0.45), 3.0)

	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		if not revealed.has(n.id):
			continue
		var pos: Vector2 = node_positions[n.id]
		var color := _tile_color(n)
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
		if not revealed.has(p.current_node_id):
			continue
		if not node_positions.has(p.current_node_id):
			continue
		var base_pos: Vector2 = node_positions[p.current_node_id]
		var offset := Vector2(cos(i * TAU / 3.0), sin(i * TAU / 3.0)) * 10.0
		draw_circle(base_pos + offset, 7.0, player_colors[i % player_colors.size()])
