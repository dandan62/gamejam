extends RefCounted
class_name MapTextLoader

## data/maps/*.txt を読み込みMapDefinitionを構築するテキストマップローダー。
##
## ファイルの先頭行が"#"で始まる場合、それはマス行ではなくオプション行として扱われる
## （スペース区切りの "キー=値" を列挙。例: "#persist_tiles=true background=イラスト32.png"）。
## 省略した場合は全て既定値。
##   persist_tiles=true  : TREASURE/RELICが取得してもマスから消えず、何度でも拾えるようになる。
##   background=ファイル名: data/maps/ 内の画像ファイルをBoardの背景として使う（スペース不可）。
##
## フォーマット：（オプション行の次から）depth0から順に「マス行」「接続行」を交互に並べる
## （最後はマス行で終わる）。
##   マス行   : 1文字=1レーン。 S=スタート n=何もない t=お宝 e=イベント h=橋 r=遺物 .(ピリオド)=そのレーンにマスなし
##   接続行   : 空行なら「隣接レーン同士を自動接続」。
##              手動指定する場合は "元レーン:先レーン,先レーン,..." をスペース区切りで列挙。
##              例) "0:0,1,2,3,4" は深度0の0番レーンが次の深度の0〜4番レーン全てに繋がる。
## マス行の文字数（＝レーン数）は深度ごとに変えてよい。
##
## Text-based map loader that reads data/maps/*.txt and builds a MapDefinition.
##
## If the file's first line starts with "#", it's an option line rather than a tile line
## (space-separated "key=value" tokens, e.g. "#persist_tiles=true background=イラスト32.png").
## Omit it and everything defaults.
##   persist_tiles=true : TREASURE/RELIC tiles never disappear after being picked up and can be
##                         taken again and again.
##   background=file    : uses an image file inside data/maps/ as Board's background (no spaces).
##
## Format (starting right after the option line, if any): starting at depth 0, alternate "tile
## lines" and "connector lines" (ends on a tile line).
##   tile line     : 1 character = 1 lane. S=start n=empty t=treasure e=event h=bridge r=relic .(dot)=no lane here
##   connector line: a blank line means "auto-connect adjacent lanes."
##                   To connect manually, list "sourceLane:targetLane,targetLane,..." separated by spaces.
##                   e.g. "0:0,1,2,3,4" connects lane 0 at depth 0 to all lanes 0-4 at the next depth.
## The number of characters (= lane count) in a tile line may differ per depth.

const TILE_CHARS := {
	"S": 0, # MapNodeDef.TileType.START
	"n": 1, # MapNodeDef.TileType.EMPTY
	"t": 2, # MapNodeDef.TileType.TREASURE
	"e": 3, # MapNodeDef.TileType.EVENT
	"h": 4, # MapNodeDef.TileType.BRIDGE
	"r": 5, # MapNodeDef.TileType.RELIC
}
const GAP_CHAR := "."
const OPTION_PREFIX := "#"


static func load_from_file(path: String) -> MapDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapTextLoader: cannot open file: %s" % path)
		return null

	var lines: Array = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)

	if lines.is_empty():
		push_error("MapTextLoader: map file is empty: %s" % path)
		return null

	var map := MapDefinition.new()
	map.map_name = path.get_file().get_basename()

	if lines[0].begins_with(OPTION_PREFIX):
		_parse_options(map, lines[0])
		lines.remove_at(0)

	var nodes: Array = []
	var lane_ids_by_depth: Dictionary = {}
	var next_id := 0
	var max_depth := int((lines.size() - 1) / 2)

	for depth in range(max_depth + 1):
		var tile_line: String = lines[depth * 2]
		var lane_map := {}
		for lane in range(tile_line.length()):
			var ch := tile_line[lane]
			if ch == GAP_CHAR or ch == " ":
				continue
			if not TILE_CHARS.has(ch):
				push_error("MapTextLoader: unknown tile symbol '%s' (depth=%d, lane=%d) in %s" % [ch, depth, lane, path])
				continue
			var n := MapNodeDef.new()
			n.id = next_id
			next_id += 1
			n.depth = depth
			n.lane = lane
			n.tile_type = TILE_CHARS[ch]
			nodes.append(n)
			lane_map[lane] = n.id
			if n.tile_type == MapNodeDef.TileType.START:
				map.start_node_id = n.id
		lane_ids_by_depth[depth] = lane_map

	for depth in range(max_depth):
		var cur_map: Dictionary = lane_ids_by_depth[depth]
		var next_map: Dictionary = lane_ids_by_depth[depth + 1]
		var connector_index := depth * 2 + 1
		var connector_line: String = lines[connector_index] if connector_index < lines.size() else ""

		if connector_line.strip_edges() == "":
			_auto_connect(nodes, cur_map, next_map)
		else:
			_manual_connect(nodes, cur_map, next_map, connector_line, depth, path)

	map.nodes = nodes
	return map


static func _parse_options(map: MapDefinition, line: String) -> void:
	var body := line.substr(OPTION_PREFIX.length())
	for token in body.split(" ", false):
		var parts := token.split("=")
		if parts.size() != 2:
			continue
		var key := parts[0].strip_edges()
		var value := parts[1].strip_edges()
		match key:
			"persist_tiles":
				map.treasures_persist = value == "true"
			"background":
				map.background_image_path = "res://data/maps/" + value


static func _find_node(nodes: Array, id: int) -> MapNodeDef:
	for n in nodes:
		if n.id == id:
			return n
	return null


static func _auto_connect(nodes: Array, cur_map: Dictionary, next_map: Dictionary) -> void:
	for lane in cur_map.keys():
		var node := _find_node(nodes, cur_map[lane])
		for dl in [-1, 0, 1]:
			var nl = lane + dl
			if next_map.has(nl):
				node.forward_connections.append(next_map[nl])


static func _manual_connect(nodes: Array, cur_map: Dictionary, next_map: Dictionary, line: String, depth: int, path: String) -> void:
	for token in line.split(" ", false):
		if token.strip_edges() == "":
			continue
		var parts := token.split(":")
		if parts.size() != 2:
			push_error("MapTextLoader: invalid connector token '%s' (depth=%d) in %s" % [token, depth, path])
			continue
		var src_lane := int(parts[0])
		if not cur_map.has(src_lane):
			push_error("MapTextLoader: source lane %d does not exist (depth=%d) in %s" % [src_lane, depth, path])
			continue
		var node := _find_node(nodes, cur_map[src_lane])
		for target_str in parts[1].split(","):
			if target_str.strip_edges() == "":
				continue
			var target_lane := int(target_str)
			if not next_map.has(target_lane):
				push_error("MapTextLoader: target lane %d does not exist (depth=%d) in %s" % [target_lane, depth + 1, path])
				continue
			node.forward_connections.append(next_map[target_lane])
