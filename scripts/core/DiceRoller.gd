extends RefCounted
class_name DiceRoller

static func roll_1d6() -> int:
	return randi_range(1, 6)
