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
## 空でなければ、Boardの背景として使う画像のres://パス
## （MapTextLoaderがマップファイル先頭の"#"行の background=ファイル名 から読み取り、
## data/maps/ 内のファイル名として解決する）。空なら背景なし（従来通り黒一色）。
## If non-empty, the res:// path of the image Board uses as its background (set via a
## "background=filename" token on the "#" directive line at the top of the map file;
## MapTextLoader resolves it as a filename inside data/maps/). Empty means no background
## (falls back to the original solid black).
@export var background_image_path: String = ""
