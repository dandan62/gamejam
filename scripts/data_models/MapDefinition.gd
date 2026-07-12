extends Resource
class_name MapDefinition

@export var map_name: String = ""
@export var nodes: Array = []  # Array[MapNodeDef]
@export var start_node_id: int = 0
## trueなら、このマップのTREASURE/RELICは取得してもマスから消えず、何度でも拾える
## （MapTextLoaderがマップファイル先頭の"#"行から読み取る。既定はfalse＝従来通り一度きり）。
## If true, this map's TREASURE/RELIC tiles never disappear after being picked up and can be
## taken again and again (set via a "#" directive line at the top of the map file; MapTextLoader
## reads it. Defaults to false -- the original one-time-only behavior).
@export var treasures_persist: bool = false
