extends Resource
class_name RelicData

## 拾うと即座に永続バフとして付与され、以後ロストしない特殊アイテム。
## Special item that grants a permanent buff the instant it's picked up, and is never lost afterward.

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var description: String = ""
@export var buffs: Array = []  # Array[BuffData]
