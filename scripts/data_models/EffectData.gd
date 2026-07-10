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


## 0でないフィールドを「ラベル＋アイコン＋数値」の短い文字列にまとめる
## （例: "HP ❤-1  Light 🔦-1  Score 💰+3"）。イベント/妨害の選択肢テキストに添えて、
## 数値の増減を文章に埋め込まず一目で分かるようにするために使う。
## Summarizes the non-default fields into a short "label + icon + value" string
## (e.g. "HP ❤-1  Light 🔦-1  Score 💰+3"). Appended to event/hazard choice text so the
## numeric impact reads at a glance instead of being buried in prose.
func icon_summary() -> String:
	var parts: PackedStringArray = []
	if hp_delta != 0:
		parts.append(StatIcons.tag("HP", StatIcons.HP, StatIcons.signed(hp_delta)))
	if light_delta != 0:
		parts.append(StatIcons.tag("Light", StatIcons.LIGHT, StatIcons.signed(light_delta)))
	if score_delta != 0:
		parts.append(StatIcons.tag("Score", StatIcons.SCORE, StatIcons.signed(score_delta)))
	if drop_treasure_count != 0:
		parts.append(StatIcons.tag("Bag", StatIcons.TREASURE_COUNT, StatIcons.signed(-drop_treasure_count)))
	if next_treasure_multiplier != 1.0:
		parts.append("Score %sx%s" % [StatIcons.SCORE, str(next_treasure_multiplier)])
	if apply_buff != null:
		parts.append("%s %s" % [
			StatIcons.BUFF,
			StatIcons.tag(StatIcons.stat_label(apply_buff.stat), StatIcons.stat_icon(apply_buff.stat), StatIcons.signed(apply_buff.amount)),
		])
	return "  ".join(parts)
