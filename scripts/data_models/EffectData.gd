extends Resource
class_name EffectData

## イベント/妨害の効果を汎用的に表現する。0のフィールドは効果なしとして無視される。
## Generic representation of an event/hazard effect. Fields left at 0 are treated as no-op.

@export var description: String = ""
@export var hp_delta: int = 0
@export var light_delta: int = 0
@export var score_delta: int = 0
@export var apply_buff: BuffData = null
@export var drop_treasure_count: int = 0
@export var next_treasure_multiplier: float = 1.0
