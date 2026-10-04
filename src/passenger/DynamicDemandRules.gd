class_name DynamicDemandRules
extends RefCounted

const SLOT_SECONDS := 1800

const CONDITION_ORDER := [
	"normal",
	"off_peak",
	"normal",
	"surge",
	"normal",
	"seasonal",
	"normal",
	"contract"
]

const CONDITIONS := {
	"normal": {
		"label": "Normal",
		"short_label": "NORMAL",
		"demand_modifier": 1.00,
		"coin_multiplier": 1.00,
		"xp_multiplier": 1.00
	},
	"off_peak": {
		"label": "Off-Peak",
		"short_label": "OFF-PEAK",
		"demand_modifier": 0.80,
		"coin_multiplier": 0.90,
		"xp_multiplier": 0.95
	},
	"surge": {
		"label": "Demand Surge",
		"short_label": "SURGE",
		"demand_modifier": 1.15,
		"coin_multiplier": 1.15,
		"xp_multiplier": 1.10
	},
	"seasonal": {
		"label": "Seasonal Rush",
		"short_label": "SEASONAL",
		"demand_modifier": 1.10,
		"coin_multiplier": 1.10,
		"xp_multiplier": 1.15
	},
	"contract": {
		"label": "Priority Contract",
		"short_label": "CONTRACT",
		"demand_modifier": 1.20,
		"coin_multiplier": 1.25,
		"xp_multiplier": 1.20
	}
}


static func condition_for(
	destination_id: String,
	now_unix: int = -1
) -> Dictionary:
	var timestamp := now_unix
	if timestamp < 0:
		timestamp = int(Time.get_unix_time_from_system())

	var slot := floori(
		float(timestamp) / float(SLOT_SECONDS)
	)
	var offset := _stable_destination_offset(destination_id)
	var condition_id := String(
		CONDITION_ORDER[
			(slot + offset) % CONDITION_ORDER.size()
		]
	)

	var result: Dictionary = CONDITIONS.get(
		condition_id,
		CONDITIONS["normal"]
	).duplicate(true)
	result["id"] = condition_id
	result["slot"] = slot
	result["starts_at_unix"] = slot * SLOT_SECONDS
	result["ends_at_unix"] = (slot + 1) * SLOT_SECONDS
	result["remaining_seconds"] = maxi(
		int(result["ends_at_unix"]) - timestamp,
		0
	)
	return result


static func apply_to_flight_plan(
	flight_plan: Dictionary,
	condition: Dictionary
) -> Dictionary:
	if flight_plan.is_empty():
		return {}

	var result := flight_plan.duplicate(true)
	var coin_multiplier := maxf(
		float(condition.get("coin_multiplier", 1.0)),
		0.0
	)
	var xp_multiplier := maxf(
		float(condition.get("xp_multiplier", 1.0)),
		0.0
	)

	result["base_coin_reward"] = int(
		flight_plan.get("coin_reward", 0)
	)
	result["base_xp_reward"] = int(
		flight_plan.get("xp_reward", 0)
	)
	result["coin_reward"] = maxi(
		int(round(
			float(result["base_coin_reward"])
			* coin_multiplier
		)),
		0
	)
	result["xp_reward"] = maxi(
		int(round(
			float(result["base_xp_reward"])
			* xp_multiplier
		)),
		0
	)
	result["passenger_demand_modifier"] = maxf(
		float(condition.get("demand_modifier", 1.0)),
		0.0
	)
	result["demand_condition_id"] = String(
		condition.get("id", "normal")
	)
	result["demand_condition_label"] = String(
		condition.get("label", "Normal")
	)
	result["demand_condition_short_label"] = String(
		condition.get("short_label", "NORMAL")
	)
	result["demand_condition_ends_at_unix"] = int(
		condition.get("ends_at_unix", 0)
	)
	result["demand_coin_multiplier"] = coin_multiplier
	result["demand_xp_multiplier"] = xp_multiplier
	return result


static func condition_summary(
	destination_id: String,
	now_unix: int = -1
) -> String:
	var condition := condition_for(destination_id, now_unix)
	return "%s • %+.0f%% pax • Coins %+.0f%% • XP %+.0f%%" % [
		String(condition.get("label", "Normal")),
		(
			float(condition.get("demand_modifier", 1.0))
			- 1.0
		) * 100.0,
		(
			float(condition.get("coin_multiplier", 1.0))
			- 1.0
		) * 100.0,
		(
			float(condition.get("xp_multiplier", 1.0))
			- 1.0
		) * 100.0
	]


static func format_remaining(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var minutes := floori(float(total) / 60.0)
	var remaining := total % 60
	return "%02d:%02d" % [minutes, remaining]


static func _stable_destination_offset(destination_id: String) -> int:
	var total := 0
	for index in range(destination_id.length()):
		total += destination_id.unicode_at(index) * (index + 1)
	return posmod(total, CONDITION_ORDER.size())
