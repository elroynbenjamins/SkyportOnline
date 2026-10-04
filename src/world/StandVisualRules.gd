class_name StandVisualRules
extends RefCounted


static func canonical_state(raw_state: String) -> String:
	match raw_state:
		"", "IDLE":
			return "IDLE"
		"INBOUND_RESERVED", "APPROACH", "LANDING_ROLL", "TAXIING_IN":
			return "INBOUND_RESERVED"
		"PARKED":
			return "PARKED"
		"WAITING_FUEL", "UNLOADING", "SERVICING", "LOADING":
			return "TURNAROUND"
		"WAITING_PASSENGERS":
			return "WAITING_PASSENGERS"
		"PUSHBACK_PREP":
			return "PUSHBACK_PREP"
		"READY_FOR_DESTINATION":
			return "READY_FOR_DESTINATION"
		"READY_FOR_DEPARTURE":
			return "READY_FOR_DEPARTURE"
		_:
			return "IDLE"


static func color_for_state(raw_state: String) -> Color:
	match canonical_state(raw_state):
		"INBOUND_RESERVED":
			return Color("67b8e8")
		"PARKED":
			return Color("d9e4e8")
		"TURNAROUND":
			return Color("f0c95d")
		"WAITING_PASSENGERS":
			return Color("f49a61")
		"PUSHBACK_PREP":
			return Color("7ad5a0")
		"READY_FOR_DESTINATION":
			return Color("d69bea")
		"READY_FOR_DEPARTURE":
			return Color("65d69a")
		_:
			return Color("6fbf83")


static func is_occupied(raw_state: String) -> bool:
	return canonical_state(raw_state) != "IDLE"


static func should_draw_entry_chevron(raw_state: String) -> bool:
	return canonical_state(raw_state) == "INBOUND_RESERVED"


static func should_draw_departure_chevron(raw_state: String) -> bool:
	return canonical_state(raw_state) in [
		"PUSHBACK_PREP",
		"READY_FOR_DEPARTURE"
	]


static func label_for_state(raw_state: String) -> String:
	match canonical_state(raw_state):
		"INBOUND_RESERVED":
			return "INBOUND"
		"PARKED":
			return "PARKED"
		"TURNAROUND":
			return "SERVICE"
		"WAITING_PASSENGERS":
			return "PAX"
		"PUSHBACK_PREP":
			return "PUSH"
		"READY_FOR_DESTINATION":
			return "ROUTE"
		"READY_FOR_DEPARTURE":
			return "READY"
		_:
			return "OPEN"
