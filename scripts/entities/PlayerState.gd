extends RefCounted
class_name PlayerState

enum Status { ACTIVE, RETURNED, ELIMINATED }

var id: int = 0
var display_name: String = ""
var is_cpu: bool = false

var hp: int = 3
var max_hp: int = 3
var light: int = 5
var max_light: int = 5
var weight_capacity_base: int = 5

var current_node_id: int = 0
var status: Status = Status.ACTIVE

var carried_treasures: Array = []   # Array of {data: TreasureData, value: int}
var carried_relics: Array = []      # Array[RelicData] -- occupies weight, never removed (not even on return/elimination)
var permanent_buffs: Array = []     # Array[BuffData], from permanent treasure buffs + relics
var banked_score: int = 0
var next_treasure_multiplier: float = 1.0


func get_active_buffs() -> Array:
	var result: Array = []
	result.append_array(permanent_buffs)
	for entry in carried_treasures:
		var data: TreasureData = entry["data"]
		for b in data.buffs:
			if b.duration == BuffData.Duration.WHILE_HELD:
				result.append(b)
	return result


func get_stat_bonus(stat: int) -> int:
	var total := 0
	for b in get_active_buffs():
		if b.stat == stat:
			total += b.amount
	return total


func get_weight_capacity() -> int:
	return weight_capacity_base + get_stat_bonus(BuffData.Stat.WEIGHT)


func get_total_weight() -> int:
	var total := 0
	for entry in carried_treasures:
		var data: TreasureData = entry["data"]
		total += data.weight
	for relic in carried_relics:
		total += relic.weight
	return total


func can_carry_weight(extra_weight: int) -> bool:
	return get_total_weight() + extra_weight <= get_weight_capacity()


func can_pick_up(treasure_data: TreasureData) -> bool:
	return can_carry_weight(treasure_data.weight)


func can_pick_up_relic(relic_data: RelicData) -> bool:
	return can_carry_weight(relic_data.weight)


func add_permanent_buffs_from(buffs: Array) -> void:
	for b in buffs:
		if b.duration == BuffData.Duration.PERMANENT:
			permanent_buffs.append(b)


## 遺物はスコアの無いお宝として carried_relics に入り、重量を占有し続ける
## （bank_carried_treasures/lose_all_carried_treasuresの対象外なので、帰還しても脱落しても消えない）。
## バフは duration の指定に関わらず、拾った時点で常に永続として付与される。
## MAX_HP/MAX_LIGHTは上限そのものを引き上げる特殊枠のため、バフリストに積まず
## その場でmax_hp/max_light（と現在値）を直接加算する。
## Relics go into carried_relics as scoreless treasure and permanently occupy weight capacity
## (they're outside bank_carried_treasures/lose_all_carried_treasures, so they survive both
## returning to the surface and elimination). Their buffs are always granted as permanent the
## moment they're picked up, regardless of the buff's own duration setting. MAX_HP/MAX_LIGHT are
## a special case that raise the cap itself, so instead of being pushed onto the buff list they
## directly increment max_hp/max_light (and the current value) on the spot.
func pick_up_relic(data: RelicData) -> void:
	carried_relics.append(data)
	for b in data.buffs:
		if b.stat == BuffData.Stat.MAX_HP:
			max_hp += b.amount
			hp += b.amount
		elif b.stat == BuffData.Stat.MAX_LIGHT:
			max_light += b.amount
			light += b.amount
		else:
			permanent_buffs.append(b)


## value は TreasureSpawner がノード配置時に一度だけロールした値を渡す。
## `value` is the number TreasureSpawner rolled once when placing this node's contents.
func pick_up_treasure(data: TreasureData, value: int) -> void:
	var final_value := int(round(value * next_treasure_multiplier))
	next_treasure_multiplier = 1.0
	carried_treasures.append({"data": data, "value": final_value})
	hp = max(hp - data.hp_damage, 0)
	add_permanent_buffs_from(data.buffs)


func lose_all_carried_treasures() -> void:
	carried_treasures.clear()


func bank_carried_treasures() -> int:
	var total := 0
	for entry in carried_treasures:
		total += int(entry["value"])
	banked_score += total
	carried_treasures.clear()
	return total


func is_finished() -> bool:
	return status != Status.ACTIVE
