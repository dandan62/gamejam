extends RefCounted
class_name TierSelector

## 深度に応じてお宝/イベント/遺物のtierを決める。
## depth1-6: tier1, depth7-12: tier2, depth13-18: tier3, depth19-20: tier4。
## Decides the treasure/event/relic tier from depth.
## depth 1-6: tier 1, depth 7-12: tier 2, depth 13-18: tier 3, depth 19-20: tier 4.


static func pick_tier(depth: int) -> int:
	if depth <= 6:
		return 1
	if depth <= 12:
		return 2
	if depth <= 18:
		return 3
	return 4
