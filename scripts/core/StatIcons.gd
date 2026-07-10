extends RefCounted
class_name StatIcons

## ステータスを文章だけ・アイコンだけではなく「ラベル＋アイコン＋数値」（例: "HP ❤-1"）
## で表すための定義。HUD/ActionPanel/EventPopup/DiceUIなど、ステータスの増減を表示する
## 箇所はここのアイコン・ラベルで統一する。
## Definitions for representing a stat as "label + icon + value" (e.g. "HP ❤-1") rather than
## text alone or an icon alone. HUD/ActionPanel/EventPopup/DiceUI and anywhere else that
## displays a stat delta should draw from these icons/labels for consistency.

const HP := "❤"
const LIGHT := "🔦"
const SCORE := "💰"
const WEIGHT := "⚖"
const MOVE := "👣"
const TREASURE_COUNT := "🎒"
const VISION := "👁"
const DICE := "🎲"
const BUFF := "✨"


## +符号を明示した数値文字列にする（0未満はそのまま "-1" のように表示される）。
## Formats a number with an explicit + sign for positive values (negatives already read as "-1").
static func signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


## "HP ❤-1" のように ラベル＋アイコン＋値 の文字列を作る。
## Builds a "label + icon + value" string like "HP ❤-1".
static func tag(label: String, icon: String, value: String = "") -> String:
	return "%s %s%s" % [label, icon, value]


static func stat_icon(stat: int) -> String:
	match stat:
		BuffData.Stat.MOVE:
			return MOVE
		BuffData.Stat.WEIGHT:
			return WEIGHT
		BuffData.Stat.LIGHT:
			return LIGHT
		_:
			return "?"


static func stat_label(stat: int) -> String:
	match stat:
		BuffData.Stat.MOVE:
			return "Move"
		BuffData.Stat.WEIGHT:
			return "Weight"
		BuffData.Stat.LIGHT:
			return "Light"
		_:
			return "?"


## 複数のバフをまとめて "✨ Move 👣+2  ✨ Light 🔦-1" のような文字列にする。
## Summarizes a list of buffs into a string like "✨ Move 👣+2  ✨ Light 🔦-1".
static func buffs_summary(buffs: Array) -> String:
	var parts: PackedStringArray = []
	for b in buffs:
		var buff: BuffData = b
		parts.append("%s %s" % [BUFF, tag(stat_label(buff.stat), stat_icon(buff.stat), signed(buff.amount))])
	return "  ".join(parts)
