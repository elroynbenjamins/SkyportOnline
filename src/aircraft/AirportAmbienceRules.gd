class_name AirportAmbienceRules
extends RefCounted

const STAND_STATES := [
	"PARKED",
	"WAITING_FUEL",
	"UNLOADING",
	"SERVICING",
	"LOADING",
	"PUSHBACK_PREP",
	"READY_FOR_DESTINATION",
	"WAITING_PASSENGERS",
	"READY_FOR_DEPARTURE"
]


static func profile_for_state(state: String) -> Dictionary:
	match state:
		"PARKED":
			return {
				"chocks": true,
				"cones": 2,
				"workers": 0,
				"passengers": 0,
				"baggage": 0,
				"marshaller": false
			}
		"WAITING_FUEL":
			return {
				"chocks": true,
				"cones": 3,
				"workers": 1,
				"passengers": 0,
				"baggage": 0,
				"marshaller": false
			}
		"UNLOADING":
			return {
				"chocks": true,
				"cones": 4,
				"workers": 2,
				"passengers": 0,
				"baggage": 3,
				"marshaller": false
			}
		"SERVICING":
			return {
				"chocks": true,
				"cones": 4,
				"workers": 2,
				"passengers": 0,
				"baggage": 1,
				"marshaller": false
			}
		"LOADING":
			return {
				"chocks": true,
				"cones": 3,
				"workers": 1,
				"passengers": 3,
				"baggage": 2,
				"marshaller": false
			}
		"WAITING_PASSENGERS":
			return {
				"chocks": true,
				"cones": 2,
				"workers": 1,
				"passengers": 4,
				"baggage": 0,
				"marshaller": false
			}
		"READY_FOR_DESTINATION":
			return {
				"chocks": true,
				"cones": 2,
				"workers": 0,
				"passengers": 0,
				"baggage": 0,
				"marshaller": false
			}
		"READY_FOR_DEPARTURE":
			return {
				"chocks": true,
				"cones": 2,
				"workers": 1,
				"passengers": 0,
				"baggage": 0,
				"marshaller": false
			}
		"PUSHBACK_PREP":
			return {
				"chocks": false,
				"cones": 1,
				"workers": 0,
				"passengers": 0,
				"baggage": 0,
				"marshaller": true
			}
		_:
			return {}


static func is_stand_ambience_state(state: String) -> bool:
	return STAND_STATES.has(state)


static func size_scale(size_class: String) -> float:
	match size_class:
		"M":
			return 1.25
		"L":
			return 1.55
		"XL":
			return 1.85
		_:
			return 1.0


static func worker_count_for(
	state: String,
	size_class: String
) -> int:
	var profile := profile_for_state(state)
	var base := int(profile.get("workers", 0))
	if base <= 0:
		return 0
	if size_class == "M" and state in [
		"UNLOADING",
		"SERVICING"
	]:
		return base + 1
	return base


static func passenger_count_for(
	state: String,
	size_class: String
) -> int:
	var profile := profile_for_state(state)
	var base := int(profile.get("passengers", 0))
	if base <= 0:
		return 0
	if size_class == "M":
		return base + 1
	return base


static func baggage_count_for(
	state: String,
	size_class: String
) -> int:
	var profile := profile_for_state(state)
	var base := int(profile.get("baggage", 0))
	if base <= 0:
		return 0
	if size_class == "M":
		return base + 1
	return base
