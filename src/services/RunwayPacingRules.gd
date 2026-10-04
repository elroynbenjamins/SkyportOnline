class_name RunwayPacingRules
extends RefCounted

const DEPARTURE_TO_DEPARTURE := 2.5
const DEPARTURE_TO_ARRIVAL := 3.5
const ARRIVAL_TO_DEPARTURE := 3.0
const ARRIVAL_TO_ARRIVAL := 4.5


static func separation_seconds(
	previous_operation: String,
	next_operation: String
) -> float:
	if previous_operation.is_empty() or next_operation.is_empty():
		return 0.0

	match previous_operation:
		"arrival":
			if next_operation == "arrival":
				return ARRIVAL_TO_ARRIVAL
			return ARRIVAL_TO_DEPARTURE
		"departure":
			if next_operation == "arrival":
				return DEPARTURE_TO_ARRIVAL
			return DEPARTURE_TO_DEPARTURE
		_:
			return 0.0


static func operation_token(operation: String) -> String:
	match operation:
		"arrival":
			return "LAND"
		"departure":
			return "DEP"
		_:
			return "—"


static func operation_label(operation: String) -> String:
	match operation:
		"arrival":
			return "landing"
		"departure":
			return "departure"
		_:
			return "movement"
