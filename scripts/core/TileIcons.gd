extends RefCounted
class_name TileIcons

## マス種別ごとの色・ラベル・役割説明を一箇所にまとめる。Boardの盤面描画とDiceUIの
## 凡例表示の両方がここを参照することで、表示がずれないようにする。
## Centralizes each tile type's color, label, and role description in one place, so
## Board's board rendering and DiceUI's legend both stay in sync.

const START_COLOR := Color(0.85, 0.85, 0.9)
const EMPTY_COLOR := Color(0.6, 0.6, 0.65)
const TREASURE_COLOR := Color(1.0, 0.85, 0.35)
const EVENT_COLOR := Color(0.3, 0.6, 0.95)
const BRIDGE_COLOR := Color(0.85, 0.25, 0.25)
const BRIDGE_BROKEN_COLOR := Color(0.3, 0.12, 0.12)
const RELIC_COLOR := Color(0.65, 0.35, 0.85)

## 凡例に表示する順番。
## Display order for the legend.
const ALL_TYPES := [
	MapNodeDef.TileType.START,
	MapNodeDef.TileType.EMPTY,
	MapNodeDef.TileType.TREASURE,
	MapNodeDef.TileType.EVENT,
	MapNodeDef.TileType.BRIDGE,
	MapNodeDef.TileType.RELIC,
]


static func color_for(tile_type: int) -> Color:
	match tile_type:
		MapNodeDef.TileType.START:
			return START_COLOR
		MapNodeDef.TileType.TREASURE:
			return TREASURE_COLOR
		MapNodeDef.TileType.EVENT:
			return EVENT_COLOR
		MapNodeDef.TileType.BRIDGE:
			return BRIDGE_COLOR
		MapNodeDef.TileType.RELIC:
			return RELIC_COLOR
		_:
			return EMPTY_COLOR


static func label_for(tile_type: int) -> String:
	match tile_type:
		MapNodeDef.TileType.START:
			return "Start"
		MapNodeDef.TileType.TREASURE:
			return "Treasure"
		MapNodeDef.TileType.EVENT:
			return "Event"
		MapNodeDef.TileType.BRIDGE:
			return "Bridge"
		MapNodeDef.TileType.RELIC:
			return "Relic"
		_:
			return "Empty"


static func description_for(tile_type: int) -> String:
	match tile_type:
		MapNodeDef.TileType.START:
			return "Surface / return point"
		MapNodeDef.TileType.TREASURE:
			return "Pick up for Score (costs HP/Weight)"
		MapNodeDef.TileType.EVENT:
			return "Pick one of two effects"
		MapNodeDef.TileType.BRIDGE:
			return "Choose to destroy it after crossing (blocks everyone after)"
		MapNodeDef.TileType.RELIC:
			return "Pick up for a permanent buff"
		_:
			return "Nothing here"
