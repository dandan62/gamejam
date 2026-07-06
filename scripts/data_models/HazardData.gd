extends Resource
class_name HazardData

## 選択肢なしで自動発動する妨害マスの効果。
## Effect of a hazard tile, applied automatically with no player choice.

@export var id: String = ""
@export var tier: int = 1
@export var description: String = ""
@export var effect: EffectData
