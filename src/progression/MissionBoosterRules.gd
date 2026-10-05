class_name MissionBoosterRules
extends RefCounted

const DURATION_SECONDS := 7200

const CATALOG := {
	"booster_ground_crew": {
		"title": "Ground Crew",
		"description": "20% faster ground handling",
		"effect": "ground_service_speed",
		"multiplier": 1.20
	},
	"booster_tailwind": {
		"title": "Tailwind",
		"description": "10% shorter flight travel time",
		"effect": "flight_duration",
		"multiplier": 0.90
	},
	"booster_passengers": {
		"title": "Tourism Rush",
		"description": "20% faster passenger production",
		"effect": "passenger_production",
		"multiplier": 1.20
	},
	"booster_gold": {
		"title": "Golden Routes",
		"description": "10% more Gold from completed flights",
		"effect": "flight_gold",
		"multiplier": 1.10
	},
	"booster_xp": {
		"title": "Flight School",
		"description": "10% more XP from completed flights",
		"effect": "flight_xp",
		"multiplier": 1.10
	}
}

static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for key in CATALOG.keys():
		result.append(String(key))
	return result

static func definition(booster_id: String) -> Dictionary:
	return (CATALOG.get(booster_id, {}) as Dictionary).duplicate(true)

static func activate(state: Dictionary, booster_id: String, unix_time: float) -> bool:
	if not CATALOG.has(booster_id):
		return false
	var inventory: Dictionary = state.get("booster_inventory", {})
	var available := int(inventory.get(booster_id, 0))
	if available <= 0:
		return false
	var active: Dictionary = state.get("active_boosters", {})
	var now := int(floor(unix_time))
	var current_expiry := int(active.get(booster_id, 0))
	active[booster_id] = maxi(current_expiry, now) + DURATION_SECONDS
	inventory[booster_id] = available - 1
	state["booster_inventory"] = inventory
	state["active_boosters"] = active
	return true

static func is_active(state: Dictionary, booster_id: String, unix_time: float) -> bool:
	return remaining_seconds(state, booster_id, unix_time) > 0

static func remaining_seconds(state: Dictionary, booster_id: String, unix_time: float) -> int:
	var active: Dictionary = state.get("active_boosters", {})
	return maxi(int(active.get(booster_id, 0)) - int(floor(unix_time)), 0)

static func active_profile(state: Dictionary, unix_time: float) -> Dictionary:
	var result := {
		"ground_service_speed": 1.0,
		"flight_duration": 1.0,
		"passenger_production": 1.0,
		"flight_gold": 1.0,
		"flight_xp": 1.0
	}
	for booster_id in CATALOG.keys():
		var id := String(booster_id)
		if not is_active(state, id, unix_time):
			continue
		var definition_value: Dictionary = CATALOG[id]
		var effect := String(definition_value.get("effect", ""))
		if result.has(effect):
			result[effect] = float(definition_value.get("multiplier", 1.0))
	return result

static func format_remaining(seconds: int) -> String:
	var bounded := maxi(seconds, 0)
	var hours := bounded / 3600
	var minutes := (bounded % 3600) / 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % maxi(minutes, 1)
