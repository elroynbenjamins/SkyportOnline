class_name AirTrafficUpgradeCatalog
extends RefCounted

const UPGRADEABLE_IDS := [
	"atc_tower"
]


static func is_upgradeable(building_id: String) -> bool:
	return UPGRADEABLE_IDS.has(building_id)


static func get_levels(building_id: String) -> Array[Dictionary]:
	if building_id != "atc_tower":
		return []

	return [
		{
			"level": 1,
			"separation_multiplier": 0.92,
			"coin_cost": 0,
			"resource_cost": {}
		},
		{
			"level": 2,
			"separation_multiplier": 0.84,
			"coin_cost": 14000,
			"resource_cost": {
				"be_precision_parts": 2,
				"gb_aerospace_parts": 1
			}
		},
		{
			"level": 3,
			"separation_multiplier": 0.76,
			"coin_cost": 32000,
			"resource_cost": {
				"de_machinery": 2,
				"dk_renewable_parts": 2
			}
		},
		{
			"level": 4,
			"separation_multiplier": 0.68,
			"coin_cost": 60000,
			"resource_cost": {
				"jp_precision_electronics": 2,
				"kr_semiconductors": 2,
				"us_flight_computers": 1
			}
		}
	]


static func get_level(
	building_id: String,
	level: int
) -> Dictionary:
	for data in get_levels(building_id):
		if int(data.get("level", 0)) == level:
			return data.duplicate(true)
	return {}


static func get_next_level(
	building_id: String,
	current_level: int
) -> Dictionary:
	return get_level(building_id, current_level + 1)


static func max_level(building_id: String) -> int:
	var levels := get_levels(building_id)
	if levels.is_empty():
		return 1
	return int(levels[levels.size() - 1].get("level", 1))


static func separation_multiplier(
	building_id: String,
	level: int
) -> float:
	var data := get_level(building_id, level)
	if data.is_empty():
		return 1.0
	return clampf(
		float(data.get("separation_multiplier", 1.0)),
		0.50,
		1.0
	)


static func separation_preview(
	building_id: String,
	level: int
) -> Dictionary:
	var multiplier := separation_multiplier(
		building_id,
		level
	)
	return {
		"multiplier": multiplier,
		"departure_departure": RunwayPacingRules.separation_seconds(
			"departure",
			"departure",
			multiplier
		),
		"departure_arrival": RunwayPacingRules.separation_seconds(
			"departure",
			"arrival",
			multiplier
		),
		"arrival_departure": RunwayPacingRules.separation_seconds(
			"arrival",
			"departure",
			multiplier
		),
		"arrival_arrival": RunwayPacingRules.separation_seconds(
			"arrival",
			"arrival",
			multiplier
		)
	}
