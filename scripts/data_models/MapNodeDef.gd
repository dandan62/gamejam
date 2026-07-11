extends Resource
class_name MapNodeDef

## マップ上の1マスの定義。forward_connectionsで次の深度のノードIDへ接続する
## （1ノードから最大5本まで分岐可能）。fixed_*_idを指定するとそのマスは
## 常に指定のイベント/遺物になり、空ならtier内からランダム抽選される。
## BRIDGEは橋マス：通過したプレイヤーが橋を破壊するか選べる（破壊すると以後誰も
## そのマスを通れなくなる。壊さなければ次に通過した誰かが改めて選べる）。
## Definition of one map tile. forward_connections links to node IDs at the next depth
## (up to 5 branches per node). If a fixed_*_id is set, that tile always uses the specified
## event/relic; if left empty, one is picked at random from within its tier.
## BRIDGE is a bridge tile: whoever crosses it can choose to destroy it (once destroyed, no one
## can pass through that tile again; if left intact, the next player to cross gets the same choice).

enum TileType { START, EMPTY, TREASURE, EVENT, BRIDGE, RELIC }

@export var id: int = 0
@export var depth: int = 0
@export var lane: int = 0
@export var tile_type: TileType = TileType.EMPTY
@export var tier: int = 1
@export var forward_connections: Array = []  # Array[int]
@export var fixed_event_id: String = ""
@export var fixed_relic_id: String = ""
