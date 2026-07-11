extends Resource
class_name RelicData

## スコアの無いお宝のように振る舞う特殊アイテム。拾うとバックパックに入って重量を占有し、
## 即座に永続バフとして付与され、以後（スタート地点に帰還してもロストしても）ロストしない。
## Behaves like a scoreless treasure. Picked up, it sits in the backpack and occupies weight
## capacity, and its buffs are granted permanently the instant it's picked up. Unlike carried
## treasure it's never lost -- not on returning to the surface, not on elimination.

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var description: String = ""
@export var weight: int = 1
@export var buffs: Array = []  # Array[BuffData]
