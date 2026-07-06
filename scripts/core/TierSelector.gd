extends RefCounted
class_name TierSelector

## 深度に応じてお宝/イベント/妨害のtier(1〜7)を重み付き抽選する。
## depth1-3: tier1のみ。depth4-6: tier1/2が半々。
## depth7以降は3深度ごとに基準tier(3から開始、以後+1)が50%、
## その前後のtier(±1)が25%ずつ出現する。基準tierが上限(7)に達した場合、
## 存在しない側の25%は基準tierへ加算される。
## Weighted-random pick of a treasure/event/hazard tier (1-7) based on depth.
## depth 1-3: tier 1 only. depth 4-6: tier 1/2 fifty-fifty.
## From depth 7 on, every 3 depths the primary tier (starting at 3, +1 per block) gets 50%,
## and the tiers on either side (±1) get 25% each. Once the primary tier hits the cap (7),
## the missing side's 25% is added back onto the primary tier.

const MAX_TIER := 7


static func pick_tier(depth: int) -> int:
	var weights := get_weights(depth)
	var keys: Array = weights.keys()
	keys.sort()
	var roll := randf()
	var cumulative := 0.0
	for tier in keys:
		cumulative += weights[tier]
		if roll <= cumulative:
			return tier
	return keys[keys.size() - 1]


static func get_weights(depth: int) -> Dictionary:
	if depth <= 3:
		return {1: 1.0}
	if depth <= 6:
		return {1: 0.5, 2: 0.5}

	var block_index := int(floor(float(depth - 7) / 3.0))
	var primary: int = min(3 + block_index, MAX_TIER)

	var weights := {primary: 0.5}
	_add_weight(weights, primary - 1, 0.25, primary)
	_add_weight(weights, primary + 1, 0.25, primary)
	return weights


static func _add_weight(weights: Dictionary, tier: int, amount: float, fallback: int) -> void:
	var target := tier
	if target < 1 or target > MAX_TIER:
		target = fallback
	weights[target] = weights.get(target, 0.0) + amount
