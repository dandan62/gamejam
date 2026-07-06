extends Resource
class_name TreasureData

## お宝1種類の定義。tierが深いほどmin_value/max_valueを高く設定することで
## 「奥に行くほど高得点だがリスクも高い」を表現する（tierと配置マップ側の対応で調整）。
## Definition of one treasure type. Setting a higher min_value/max_value for deeper tiers
## expresses "higher score but higher risk the deeper you go" (tuned via tier + map placement).

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var min_value: int = 1
@export var max_value: int = 10
@export var hp_damage: int = 0
@export var weight: int = 1
@export var buffs: Array = []  # Array[BuffData] -- 手書き.tresでの扱いやすさのため型指定なし
								# Array[BuffData] -- left untyped so it's easy to hand-write in .tres files
