extends RefCounted
class_name DiceRoller

static func roll_2d6() -> Dictionary:
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	return {"d1": d1, "d2": d2, "total": d1 + d2}
