extends Node

## data/ 以下の .tres リソース（お宝/イベント/妨害/遺物）と .txt マップを
## 起動時に再帰的に読み込み、tier/id別に引けるキャッシュを提供するオートロード。
## 個別ファイルを追加・編集するだけでゲーム内容を調整できるようにするための仕組み。
## Autoload that recursively loads all .tres resources under data/ (treasures/events/
## hazards/relics) and .txt maps at startup, and exposes caches lookup-able by tier/id.
## Lets game content be tuned just by adding/editing individual files.

var treasures_by_tier: Dictionary = {}
var events_by_tier: Dictionary = {}
var hazards_by_tier: Dictionary = {}
var relics_by_tier: Dictionary = {}
var events_by_id: Dictionary = {}
var hazards_by_id: Dictionary = {}
var relics_by_id: Dictionary = {}
var maps: Dictionary = {}


func _ready() -> void:
	_load_folder("res://data/treasures", _register_treasure)
	_load_folder("res://data/events", _register_event)
	_load_folder("res://data/hazards", _register_hazard)
	_load_folder("res://data/relics", _register_relic)
	_load_maps("res://data/maps")


## data/maps/*.txt をテキストマップとして読み込む（MapTextLoader参照）。
## Loads data/maps/*.txt as text maps (see MapTextLoader).
func _load_maps(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("DataLoader: folder not found: %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with(".") and file_name.ends_with(".txt"):
			var map := MapTextLoader.load_from_file(path + "/" + file_name)
			if map != null:
				maps[map.map_name] = map
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_folder(path: String, register: Callable) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("DataLoader: folder not found: %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := path + "/" + file_name
			if dir.current_is_dir():
				_load_folder(full_path, register)
			elif file_name.ends_with(".tres"):
				var res: Resource = load(full_path)
				if res != null:
					register.call(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_treasure(res: Resource) -> void:
	if res is TreasureData:
		var t: TreasureData = res
		if not treasures_by_tier.has(t.tier):
			treasures_by_tier[t.tier] = []
		treasures_by_tier[t.tier].append(t)


func _register_event(res: Resource) -> void:
	if res is EventData:
		var e: EventData = res
		if not events_by_tier.has(e.tier):
			events_by_tier[e.tier] = []
		events_by_tier[e.tier].append(e)
		if e.id != "":
			events_by_id[e.id] = e


func _register_hazard(res: Resource) -> void:
	if res is HazardData:
		var h: HazardData = res
		if not hazards_by_tier.has(h.tier):
			hazards_by_tier[h.tier] = []
		hazards_by_tier[h.tier].append(h)
		if h.id != "":
			hazards_by_id[h.id] = h


func _register_relic(res: Resource) -> void:
	if res is RelicData:
		var r: RelicData = res
		if not relics_by_tier.has(r.tier):
			relics_by_tier[r.tier] = []
		relics_by_tier[r.tier].append(r)
		if r.id != "":
			relics_by_id[r.id] = r


## 指定tierのプールが空の場合、存在するtierの中で最も近いものにフォールバックする。
## If the pool for the given tier is empty, falls back to the nearest tier that does exist.
func _nearest_available_tier(dict: Dictionary, tier: int) -> int:
	if dict.has(tier) or dict.is_empty():
		return tier
	var best: int = tier
	var best_dist: int = -1
	for key in dict.keys():
		var dist: int = abs(int(key) - tier)
		if best_dist == -1 or dist < best_dist:
			best_dist = dist
			best = key
	return best


func get_treasures_for_tier(tier: int) -> Array:
	var actual_tier := _nearest_available_tier(treasures_by_tier, tier)
	return treasures_by_tier.get(actual_tier, [])


func get_event_for_tier(tier: int) -> EventData:
	var actual_tier := _nearest_available_tier(events_by_tier, tier)
	var pool: Array = events_by_tier.get(actual_tier, [])
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func get_hazard_for_tier(tier: int) -> HazardData:
	var actual_tier := _nearest_available_tier(hazards_by_tier, tier)
	var pool: Array = hazards_by_tier.get(actual_tier, [])
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func get_relics_for_tier(tier: int) -> Array:
	var actual_tier := _nearest_available_tier(relics_by_tier, tier)
	return relics_by_tier.get(actual_tier, [])


func get_map(map_name: String) -> MapDefinition:
	return maps.get(map_name, null)


func get_first_map() -> MapDefinition:
	for key in maps.keys():
		return maps[key]
	return null
