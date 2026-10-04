class_name RunwayStrategyRules
extends RefCounted

const AUTO := "auto"
const ARRIVALS := "arrival"
const DEPARTURES := "departure"

const PREFERRED_BONUS := -18.0
const NON_PREFERRED_PENALTY := 14.0


static func valid_strategy(value: String) -> bool:
	return value in [
		AUTO,
		ARRIVALS,
		DEPARTURES
	]


static func normalize(value: String) -> String:
	return value if valid_strategy(value) else AUTO


static func score_adjustment(
	strategy: String,
	operation: String,
	runway_count: int
) -> float:
	if runway_count < 2:
		return 0.0

	var normalized := normalize(strategy)
	if normalized == AUTO:
		return 0.0
	if normalized == operation:
		return PREFERRED_BONUS
	return NON_PREFERRED_PENALTY


static func short_label(strategy: String) -> String:
	match normalize(strategy):
		ARRIVALS:
			return "ARR PREF"
		DEPARTURES:
			return "DEP PREF"
		_:
			return "AUTO"


static func display_name(strategy: String) -> String:
	match normalize(strategy):
		ARRIVALS:
			return "Arrivals preferred"
		DEPARTURES:
			return "Departures preferred"
		_:
			return "Automatic"
