class_name ServiceUpgradeCatalog
extends RefCounted

const UPGRADEABLE_IDS := [
	"ground_ops_depot",
	"cleaning_center",
	"passenger_service_hub",
	"baggage_depot",
	"catering_kitchen",
	"basic_fuel",
	"rapid_small_fuel",
	"regional_fuel",
	"rapid_regional_fuel"
]


static func is_upgradeable(building_id: String) -> bool:
	return UPGRADEABLE_IDS.has(building_id)


static func get_levels(building_id: String) -> Array[Dictionary]:
	match building_id:
		"ground_ops_depot":
			return _levels(
				3500, 9000, 18000,
				1.10, 1.15, 1.25,
				0, 1, 1,
				{"be_precision_parts": 1, "de_industrial_tools": 1},
				{"gb_specialty_goods": 2, "nl_horticulture": 2},
				{"de_machinery": 2, "fr_cosmetics": 2, "dk_renewable_parts": 1}
			)
		"basic_fuel":
			return _levels(
				4000, 10000, 22000,
				1.12, 1.22, 1.35,
				0, 1, 1,
				{"be_chemicals": 1, "de_industrial_tools": 1},
				{"gb_aerospace_parts": 2, "fr_cosmetics": 1},
				{"de_machinery": 3, "dk_renewable_parts": 2}
			)
		"rapid_small_fuel":
			return _levels(
				8000, 18000, 35000,
				1.08, 1.16, 1.26,
				0, 1, 1,
				{"be_chemicals": 2, "de_automotive_parts": 1},
				{"gb_aerospace_parts": 2, "dk_renewable_parts": 2},
				{"de_machinery": 3, "fr_luxury_goods": 2}
			)
		"regional_fuel":
			return _levels(
				10000, 24000, 45000,
				1.10, 1.20, 1.32,
				0, 1, 1,
				{"de_industrial_tools": 2, "gb_specialty_goods": 1},
				{"dk_renewable_parts": 2, "fr_cosmetics": 2},
				{"de_machinery": 4, "gb_aerospace_parts": 2}
			)
		"rapid_regional_fuel":
			return _levels(
				16000, 36000, 65000,
				1.08, 1.16, 1.25,
				0, 1, 1,
				{"de_automotive_parts": 2, "be_precision_parts": 2},
				{"gb_aerospace_parts": 3, "dk_renewable_parts": 2},
				{"de_machinery": 4, "fr_luxury_goods": 3}
			)
		"cleaning_center":
			return _specialized_levels(
				5500,
				13500,
				26000,
				{"fr_cosmetics": 1, "be_chemicals": 1},
				{"nl_horticulture": 2, "de_industrial_tools": 2},
				{"fr_luxury_goods": 2, "dk_renewable_parts": 2}
			)
		"passenger_service_hub":
			return _specialized_levels(
				6500,
				15000,
				29000,
				{"gb_specialty_goods": 1, "fr_gourmet_food": 1},
				{"be_precision_parts": 2, "de_automotive_parts": 2},
				{"gb_aerospace_parts": 2, "fr_luxury_goods": 2}
			)
		"baggage_depot":
			return _specialized_levels(
				7000,
				16500,
				31000,
				{"de_industrial_tools": 1, "be_precision_parts": 1},
				{"de_automotive_parts": 2, "gb_specialty_goods": 2},
				{"de_machinery": 3, "dk_renewable_parts": 2}
			)
		"catering_kitchen":
			return _specialized_levels(
				8000,
				18000,
				34000,
				{"fr_gourmet_food": 2, "be_chocolate": 1},
				{"nl_horticulture": 2, "dk_design_goods": 2},
				{"fr_luxury_goods": 3, "gb_specialty_goods": 2}
			)
		_:
			return []


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


static func service_types(
	building_id: String
) -> Array[String]:
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return []

	var result: Array[String] = []
	var legacy := String(definition.get("service", ""))
	if not legacy.is_empty():
		result.append(legacy)

	var services: Dictionary = definition.get("services", {})
	for service_type in services.keys():
		var value := String(service_type)
		if not result.has(value):
			result.append(value)
	result.sort()
	return result


static func effective_service_stats(
	building_id: String,
	service_type: String,
	level: int
) -> Dictionary:
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return {}

	var base_speed := 0.0
	var base_capacity := 0

	if String(definition.get("service", "")) == service_type:
		base_speed = float(definition.get("service_speed", 1.0))
		base_capacity = int(definition.get("vehicle_capacity", 1))
	else:
		var services: Dictionary = definition.get("services", {})
		if not services.has(service_type):
			return {}
		var service_data: Dictionary = services[service_type]
		base_speed = float(service_data.get("service_speed", 1.0))
		base_capacity = int(service_data.get("vehicle_capacity", 1))

	var upgrade := get_level(building_id, level)
	if upgrade.is_empty():
		upgrade = get_level(building_id, 1)

	var speed_multiplier := float(
		upgrade.get("speed_multiplier", 1.0)
	)
	var capacity_bonus := int(
		upgrade.get("capacity_bonus", 0)
	)

	return {
		"service_type": service_type,
		"service_speed": maxf(
			base_speed * speed_multiplier,
			0.1
		),
		"vehicle_capacity": maxi(
			base_capacity + capacity_bonus,
			1
		),
		"speed_multiplier": speed_multiplier,
		"capacity_bonus": capacity_bonus
	}


static func _specialized_levels(
	level_2_coin: int,
	level_3_coin: int,
	level_4_coin: int,
	level_2_resources: Dictionary,
	level_3_resources: Dictionary,
	level_4_resources: Dictionary
) -> Array[Dictionary]:
	return _levels(
		level_2_coin,
		level_3_coin,
		level_4_coin,
		1.10,
		1.18,
		1.30,
		0,
		1,
		1,
		level_2_resources,
		level_3_resources,
		level_4_resources
	)


static func _levels(
	level_2_coin: int,
	level_3_coin: int,
	level_4_coin: int,
	level_2_speed: float,
	level_3_speed: float,
	level_4_speed: float,
	level_2_capacity: int,
	level_3_capacity: int,
	level_4_capacity: int,
	level_2_resources: Dictionary,
	level_3_resources: Dictionary,
	level_4_resources: Dictionary
) -> Array[Dictionary]:
	return [
		{
			"level": 1,
			"speed_multiplier": 1.0,
			"capacity_bonus": 0,
			"coin_cost": 0,
			"resource_cost": {}
		},
		{
			"level": 2,
			"speed_multiplier": level_2_speed,
			"capacity_bonus": level_2_capacity,
			"coin_cost": level_2_coin,
			"resource_cost": level_2_resources
		},
		{
			"level": 3,
			"speed_multiplier": level_3_speed,
			"capacity_bonus": level_3_capacity,
			"coin_cost": level_3_coin,
			"resource_cost": level_3_resources
		},
		{
			"level": 4,
			"speed_multiplier": level_4_speed,
			"capacity_bonus": level_4_capacity,
			"coin_cost": level_4_coin,
			"resource_cost": level_4_resources
		}
	]
