class_name TimeOfDayRules
extends RefCounted

const PHASE_DAWN := "DAWN"
const PHASE_DAY := "DAY"
const PHASE_EVENING := "EVENING"
const PHASE_NIGHT := "NIGHT"


static func phase_for_hour(hour: int) -> String:
	var normalized := posmod(hour, 24)
	if normalized >= 6 and normalized < 8:
		return PHASE_DAWN
	if normalized >= 8 and normalized < 18:
		return PHASE_DAY
	if normalized >= 18 and normalized < 21:
		return PHASE_EVENING
	return PHASE_NIGHT


static func display_name(phase: String) -> String:
	match phase:
		PHASE_DAWN:
			return "Dawn"
		PHASE_EVENING:
			return "Evening"
		PHASE_NIGHT:
			return "Night"
		_:
			return "Day"


static func profile_for_phase(phase: String) -> Dictionary:
	match phase:
		PHASE_DAWN:
			return {
				"phase": PHASE_DAWN,
				"world_tint": Color(0.16, 0.09, 0.05, 0.15),
				"window_strength": 0.45,
				"airfield_light_strength": 0.58,
				"floodlight_strength": 0.34
			}
		PHASE_EVENING:
			return {
				"phase": PHASE_EVENING,
				"world_tint": Color(0.05, 0.08, 0.16, 0.28),
				"window_strength": 0.78,
				"airfield_light_strength": 0.84,
				"floodlight_strength": 0.62
			}
		PHASE_NIGHT:
			return {
				"phase": PHASE_NIGHT,
				"world_tint": Color(0.015, 0.04, 0.10, 0.50),
				"window_strength": 1.0,
				"airfield_light_strength": 1.0,
				"floodlight_strength": 0.90
			}
		_:
			return {
				"phase": PHASE_DAY,
				"world_tint": Color(0.0, 0.0, 0.0, 0.0),
				"window_strength": 0.08,
				"airfield_light_strength": 0.20,
				"floodlight_strength": 0.0
			}


static func profile_for_hour(hour: int) -> Dictionary:
	return profile_for_phase(phase_for_hour(hour))


static func is_low_light(phase: String) -> bool:
	return phase in [
		PHASE_DAWN,
		PHASE_EVENING,
		PHASE_NIGHT
	]


static func normalized_phase(phase: String) -> String:
	var value := phase.to_upper()
	if value in [
		PHASE_DAWN,
		PHASE_DAY,
		PHASE_EVENING,
		PHASE_NIGHT
	]:
		return value
	return PHASE_DAY
