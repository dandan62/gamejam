extends Control
class_name Board

## マップのノード・エッジ・プレイヤー駒を描画する盤面。
## ハイライトされている(=現在選択可能な)ノードはクリックで選択できる。
## 盤面全体は黒で覆われており、現在の手番プレイヤーの現在地からvision_radiusホップ以内
## （set_vision_radiusで設定）のマスだけが見える（フォグ・オブ・ウォー）。
## マス間の間隔はCANVAS_SIZE固定サイズいっぱいに広がるよう、そのマップの最大レーン数/深度から
## 逆算する（背景イラストをCANVAS_SIZEの比率で作れば、マップが変わっても常にマス配置が
## 背景に合う）。
## Draws the map's nodes, edges, and player tokens.
## Highlighted (= currently selectable) nodes can be chosen by clicking them.
## The whole board is covered in black; only tiles within vision_radius hops of the current
## turn's player position (set via set_vision_radius) are revealed (fog of war).
## Tile spacing is derived from the map's own max lane count/depth so nodes always spread out to
## fill the fixed CANVAS_SIZE (an illustration authored at CANVAS_SIZE's aspect ratio will line up
## with the tile layout no matter which map is loaded).

signal node_clicked(node_id: int)

var map_graph: MapGraph
var node_positions: Dictionary = {}
var highlighted_forward: Array = []
var highlighted_backward: Array = []
var vision_radius: int = 0
var remaining_rounds: int = -1  # -1 = unknown/not set yet -- no warning border drawn
var background_texture: Texture2D = null

const NODE_RADIUS := 18.0
const MARGIN := 60.0
const CANVAS_SIZE := Vector2(560, 1900)
const BACKGROUND_BAND_PADDING := 80.0

## 残りラウンドがこの数以下になると盤面の枠が赤く点滅する
## （ゲームが突然終わるのをプレイヤーに事前に知らせるため）。
## Once remaining rounds drops to this or below, the board's border blinks red (so the sudden
## round-limit ending doesn't blindside players).
const RED_WARNING_ROUNDS := 3
const WARNING_BORDER_WIDTH := 6.0
const BLINK_HZ := 2.0

var player_colors := [Color(0.2, 0.75, 0.35), Color(0.25, 0.55, 0.95), Color(0.95, 0.55, 0.15)]


func setup(graph: MapGraph) -> void:
	map_graph = graph
	_compute_positions()
	background_texture = null
	if map_graph.definition.background_image_path != "":
		background_texture = load(map_graph.definition.background_image_path)
	queue_redraw()


func _compute_positions() -> void:
	node_positions.clear()

	var max_lane := 0
	var max_depth := 0
	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		max_lane = max(max_lane, n.lane)
		max_depth = max(max_depth, n.depth)

	var lane_spacing := (CANVAS_SIZE.x - MARGIN * 2.0) / max_lane if max_lane > 0 else 0.0
	var depth_spacing := (CANVAS_SIZE.y - MARGIN * 2.0) / max_depth if max_depth > 0 else 0.0

	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		var x := MARGIN + n.lane * lane_spacing
		var y := MARGIN + n.depth * depth_spacing
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


## 残りラウンド数を更新する。赤点滅の範囲内にいる間は_processが継続的にqueue_redrawして
## アニメーションさせる。
## Updates the remaining-round count. While within the red-blink range, _process keeps calling
## queue_redraw so the blink animates.
func set_remaining_rounds(remaining: int) -> void:
	remaining_rounds = remaining
	queue_redraw()


func _process(_delta: float) -> void:
	if remaining_rounds >= 0 and remaining_rounds <= RED_WARNING_ROUNDS:
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


const TREASURE_COLOR_LIGHT := Color(1.0, 1.0, 0.8)
const TREASURE_COLOR_DARK := Color(1.0, 1.0, 0)
const TREASURE_VALUE_BAND := 10
const TREASURE_MAX_BAND := 6


## 取得済みのお宝/遺物マスは何もないマスと同じ見た目にする。
## お宝マスは中身を見なくても強さの目安がわかるよう、価値が10上がるごとに
## 淡い黄色→濃い黄色へ色が濃くなっていく。
## Already-claimed treasure/relic tiles look the same as an empty tile.
## Treasure tiles get darker every 10 points of value (pale yellow -> saturated yellow),
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


## 背景イラストのうち、見えている範囲(revealed)のノードのY座標帯だけを黒地の上に描画する。
## フォグ・オブ・ウォーの「未探索は見せない」を保ちつつ、探索済みの深度では絵を見せる
## （ノード配置はCANVAS_SIZEいっぱいに広がる前提なので、テクスチャ座標=盤面座標のまま使える）。
## Draws only the revealed nodes' Y-range slice of the background illustration on top of the
## black base, so unexplored depths stay hidden while explored ones show the art (node layout
## always fills CANVAS_SIZE, so texture coordinates line up 1:1 with board coordinates).
func _draw_background_band(revealed: Dictionary) -> void:
	if background_texture == null or revealed.is_empty():
		return

	var min_y := INF
	var max_y := -INF
	for id in revealed.keys():
		if not node_positions.has(id):
			continue
		var y: float = node_positions[id].y
		min_y = min(min_y, y)
		max_y = max(max_y, y)
	if min_y == INF:
		return

	min_y = clamp(min_y - BACKGROUND_BAND_PADDING, 0.0, CANVAS_SIZE.y)
	max_y = clamp(max_y + BACKGROUND_BAND_PADDING, 0.0, CANVAS_SIZE.y)
	var band := Rect2(0.0, min_y, CANVAS_SIZE.x, max_y - min_y)
	draw_texture_rect_region(background_texture, band, band)


func _draw() -> void:
	if map_graph == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)

	var revealed: Dictionary = {}
	var current_player := GameManager.get_current_player()
	if current_player != null:
		for id in map_graph.get_nodes_within_hops(current_player.current_node_id, vision_radius):
			revealed[id] = true

	_draw_background_band(revealed)

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

	_draw_round_warning_border()


## 残りラウンドがRED_WARNING_ROUNDS以下になると、盤面の外枠を赤く点滅させて知らせる
## （sin波で不透明度を揺らす）。
## Once remaining rounds drops to RED_WARNING_ROUNDS or below, blinks the board's outer border
## red to warn (opacity driven by a sine wave).
func _draw_round_warning_border() -> void:
	if remaining_rounds < 0 or remaining_rounds > RED_WARNING_ROUNDS:
		return
	var alpha: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * BLINK_HZ))
	var color := Color(1.0, 0.1, 0.1, alpha)
	var rect := Rect2(Vector2.ZERO, size).grow(-WARNING_BORDER_WIDTH * 0.5)
	draw_rect(rect, color, false, WARNING_BORDER_WIDTH)
