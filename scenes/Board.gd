extends Control
class_name Board

## マップのノード・エッジ・プレイヤー駒を描画する盤面。
## ハイライトされている(=現在選択可能な)ノードはクリックで選択できる。
## 盤面全体は黒で覆われており、現在の手番プレイヤーの現在地からvision_radiusホップ以内
## （set_vision_radiusで設定）のマスだけが見える（フォグ・オブ・ウォー）。加えて、
## スタート地点の層(depth 0)は視界に関わらず常に見える。道は見えているマスと見えている
## マスの間だけでなく、見えているマスから伸びている先(未探索でも)まで描画する。
## 背景イラストは、キャンバス最上部からスタート地点にかけては上ほど明るい縦グラデーションで、
## それ以外の見えているマスは円形パッチ(端はグラデーションでぼかし、四角く切り抜かれた
## ようにならない)で照らすため、同じ層(同じ深度)でも見えていないレーンのマスは暗闇のまま残る。
## マス間の間隔はCANVAS_SIZE固定サイズいっぱいに広がるよう、そのマップの最大レーン数/深度から
## 逆算する（背景イラストをCANVAS_SIZEの比率で作れば、マップが変わっても常にマス配置が
## 背景に合う）。
## Draws the map's nodes, edges, and player tokens.
## Highlighted (= currently selectable) nodes can be chosen by clicking them.
## The whole board is covered in black; only tiles within vision_radius hops of the current
## turn's player position (set via set_vision_radius) are revealed (fog of war). On top of
## that, the start's layer (depth 0) is always visible regardless of vision range. Paths are
## drawn out from any revealed tile to wherever they lead, even into still-unexplored darkness,
## not just between two revealed tiles. The background illustration is lit with a vertical
## gradient (brightest at the top) from the canvas top down to the start, and with a soft
## feathered circular patch around every other revealed tile, so an unrevealed lane at an
## already-explored depth stays dark rather than getting exposed as a hard-edged square.
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

## 見えている各マスの周囲を照らす円形パッチの半径。中心(core)はそのまま完全に見え、
## coreからouterにかけてアルファがなだらかに落ちていく（四角い切り抜きにならないように）。
## Radius of the circular patch that lights up each individually-revealed tile. Fully clear
## inside the core radius, fading smoothly out to fully dark at the outer radius (so the
## revealed area is a soft circle, not a hard-edged square).
const BACKGROUND_REVEAL_OUTER_RADIUS := 150.0
const BACKGROUND_REVEAL_CORE_RADIUS := 70.0
const BACKGROUND_REVEAL_SEGMENTS := 24

## スタート地点までの上部を照らす縦グラデーションの分割数（多いほど滑らか）。
## Number of horizontal strips used for the top-to-start vertical light gradient (more = smoother).
const START_LIGHT_STEPS := 40

## 縦グラデーションの開始地点(一番明るい点)をキャンバス最上部(y=0)からこの分だけ下にずらす
## （最上部は掘り始める前の岩盤のような扱いにして、光が差し込む起点をスタート寄りにする）。
## Shifts the vertical gradient's starting point (its brightest point) down from the canvas top
## (y=0) by this much (the very top reads as undug rock, and the light shaft begins closer to
## the start).
const START_LIGHT_TOP_OFFSET := 150.0

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


## 背景イラストのうち、①スタート地点までの上部（縦グラデーションで明るく）と
## ②見えている各マスの周囲（円形パッチ、端はグラデーションでぼかす）だけを黒地の上に描画する。
## depth 0のマスは①でまとめて照らされるので、②の円形パッチは重複を避けるためスキップする。
## Draws only two things on top of the black base: (1) the area from the canvas top down to the
## start, lit with a vertical gradient, and (2) a soft circular patch around each other
## individually-revealed tile (feathered at the edge). depth-0 tiles are already lit by (1), so
## they're skipped in (2) to avoid a redundant hard overlap.
func _draw_background_band(revealed: Dictionary) -> void:
	if background_texture == null:
		return

	_draw_start_light_gradient()

	for id in revealed.keys():
		var n: MapNodeDef = map_graph.get_node(id)
		if n != null and n.depth == 0:
			continue
		if not node_positions.has(id):
			continue
		_draw_reveal_patch(node_positions[id])


## キャンバス最上部は常に全開で明るく見せ、START_LIGHT_TOP_OFFSETの位置からスタート地点に
## かけては上ほど明るい縦グラデーションで背景を見せる（スタート地点だけでなく、そこに至る
## までの通路の上部も光が差し込んでいるように見せる）。
## The very top of the canvas is always shown at full brightness, and the area from
## START_LIGHT_TOP_OFFSET down to the start is lit with a vertical gradient (brightest at its
## top), so the surface above the start reads as sunlit, not just the start tile itself.
func _draw_start_light_gradient() -> void:
	var start_id: int = map_graph.definition.start_node_id
	if not node_positions.has(start_id):
		return
	var start_y: float = node_positions[start_id].y
	var band_top: float = clamp(START_LIGHT_TOP_OFFSET, 0.0, CANVAS_SIZE.y)
	var band_bottom: float = clamp(start_y + BACKGROUND_REVEAL_OUTER_RADIUS, band_top, CANVAS_SIZE.y)

	if band_top > 0.0:
		var top_rect := Rect2(0.0, 0.0, CANVAS_SIZE.x, band_top)
		draw_texture_rect_region(background_texture, top_rect, top_rect)

	if band_bottom <= band_top:
		return

	for i in range(START_LIGHT_STEPS):
		var t0 := float(i) / float(START_LIGHT_STEPS)
		var t1 := float(i + 1) / float(START_LIGHT_STEPS)
		var y0: float = lerp(band_top, band_bottom, t0)
		var y1: float = lerp(band_top, band_bottom, t1)
		var alpha := 1.0 - t0
		var strip := Rect2(0.0, y0, CANVAS_SIZE.x, y1 - y0)
		draw_texture_rect_region(background_texture, strip, strip, Color(1, 1, 1, alpha))


## posを中心に、coreの半径までは完全に見せ、outerの半径にかけてアルファを滑らかに0まで
## 落とす円形パッチを描く。四角いdraw_texture_rect_regionではなく、テクスチャ付きポリゴンの
## 頂点カラー(アルファ)を補間させることで丸く柔らかいエッジを作る。
## Draws a circular patch centered on pos: fully visible out to the core radius, then its alpha
## smoothly fades to 0 by the outer radius. Uses textured polygons with per-vertex alpha
## (interpolated by the renderer) instead of a plain rect, so the edge comes out round and soft
## rather than a hard square.
func _draw_reveal_patch(pos: Vector2) -> void:
	var tex_size: Vector2 = background_texture.get_size()

	var inner_points := PackedVector2Array()
	var inner_uvs := PackedVector2Array()
	var inner_colors := PackedColorArray()
	for i in range(BACKGROUND_REVEAL_SEGMENTS):
		var angle := TAU * i / BACKGROUND_REVEAL_SEGMENTS
		var p := pos + Vector2(cos(angle), sin(angle)) * BACKGROUND_REVEAL_CORE_RADIUS
		inner_points.append(p)
		inner_uvs.append(p / tex_size)
		inner_colors.append(Color(1, 1, 1, 1))
	draw_polygon(inner_points, inner_colors, inner_uvs, background_texture)

	for i in range(BACKGROUND_REVEAL_SEGMENTS):
		var a0 := TAU * i / BACKGROUND_REVEAL_SEGMENTS
		var a1 := TAU * (i + 1) / BACKGROUND_REVEAL_SEGMENTS
		var dir0 := Vector2(cos(a0), sin(a0))
		var dir1 := Vector2(cos(a1), sin(a1))
		var inner0 := pos + dir0 * BACKGROUND_REVEAL_CORE_RADIUS
		var inner1 := pos + dir1 * BACKGROUND_REVEAL_CORE_RADIUS
		var outer0 := pos + dir0 * BACKGROUND_REVEAL_OUTER_RADIUS
		var outer1 := pos + dir1 * BACKGROUND_REVEAL_OUTER_RADIUS
		var quad_points := PackedVector2Array([inner0, inner1, outer1, outer0])
		var quad_uvs := PackedVector2Array([inner0 / tex_size, inner1 / tex_size, outer1 / tex_size, outer0 / tex_size])
		var quad_colors := PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0),
		])
		draw_polygon(quad_points, quad_colors, quad_uvs, background_texture)


func _draw() -> void:
	if map_graph == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)

	var revealed: Dictionary = {}
	var current_player := GameManager.get_current_player()
	if current_player != null:
		for id in map_graph.get_nodes_within_hops(current_player.current_node_id, vision_radius):
			revealed[id] = true

	## スタート地点の層(depth 0)は視界に関わらず常に見える。
	## The start's layer (depth 0) is always visible regardless of vision range.
	for node in map_graph.get_all_nodes():
		var start_layer_node: MapNodeDef = node
		if start_layer_node.depth == 0:
			revealed[start_layer_node.id] = true

	_draw_background_band(revealed)

	## 道は「見えているマスまで」ではなく「見えているマスにつながっている先」まで見せる
	## （片方の端が見えていれば、その先が未探索の暗闇でも道自体は描く）。
	## Paths are drawn out to whatever a revealed tile connects to, not just between two
	## revealed tiles (if either endpoint is revealed, the path itself is drawn even when it
	## leads into still-unexplored darkness).
	for node in map_graph.get_all_nodes():
		var n: MapNodeDef = node
		var from_pos: Vector2 = node_positions[n.id]
		for next_id in n.forward_connections:
			if not node_positions.has(next_id):
				continue
			if revealed.has(n.id) or revealed.has(next_id):
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
