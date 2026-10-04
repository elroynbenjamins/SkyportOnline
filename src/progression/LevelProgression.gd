class_name LevelProgression
extends RefCounted

const MAX_LEVEL := 20
const XP_TO_NEXT := [
	0,
	120,
	180,
	260,
	360,
	500,
	680,
	900,
	1200,
	1500,
	1850,
	2250,
	2700,
	3200,
	3800,
	4500,
	5300,
	6200,
	7200,
	8400
]


static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	if level < 1 or level >= XP_TO_NEXT.size():
		return 0
	return int(XP_TO_NEXT[level])


static func add_xp(level: int, current_xp: int, amount: int) -> Dictionary:
	var new_level := clampi(level, 1, MAX_LEVEL)
	var new_xp := maxi(current_xp, 0) + maxi(amount, 0)
	var levels_gained := 0

	while new_level < MAX_LEVEL:
		var required := xp_to_next(new_level)
		if required <= 0 or new_xp < required:
			break
		new_xp -= required
		new_level += 1
		levels_gained += 1

	if new_level >= MAX_LEVEL:
		new_xp = 0

	return {
		"level": new_level,
		"xp": new_xp,
		"xp_to_next": xp_to_next(new_level),
		"levels_gained": levels_gained
	}
