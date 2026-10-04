class_name PassengerUpgradeCatalog
extends RefCounted


static func get_levels(building_id: String) -> Array[Dictionary]:
	match building_id:
		"travel_office":
			return [
				{
					"level": 1,
					"passengers_per_minute": 1.5,
					"storage": 40,
					"coin_cost": 0,
					"resource_cost": {}
				},
				{
					"level": 2,
					"passengers_per_minute": 2.2,
					"storage": 55,
					"coin_cost": 2500,
					"resource_cost": {
						"be_chocolate": 2,
						"gb_specialty_goods": 1
					}
				},
				{
					"level": 3,
					"passengers_per_minute": 3.2,
					"storage": 75,
					"coin_cost": 6000,
					"resource_cost": {
						"fr_cosmetics": 2,
						"de_industrial_tools": 2
					}
				},
				{
					"level": 4,
					"passengers_per_minute": 4.5,
					"storage": 100,
					"coin_cost": 12000,
					"resource_cost": {
						"dk_design_goods": 3,
						"gb_specialty_goods": 2
					}
				},
				{
					"level": 5,
					"passengers_per_minute": 6.0,
					"storage": 135,
					"coin_cost": 22000,
					"resource_cost": {
						"de_machinery": 3,
						"fr_luxury_goods": 3,
						"nl_horticulture": 2
					}
				}
			]
		"shuttle_station":
			return [
				{
					"level": 1,
					"passengers_per_minute": 2.8,
					"storage": 30,
					"coin_cost": 0,
					"resource_cost": {}
				},
				{
					"level": 2,
					"passengers_per_minute": 4.0,
					"storage": 42,
					"coin_cost": 6500,
					"resource_cost": {
						"de_automotive_parts": 2,
						"fr_gourmet_food": 1
					}
				},
				{
					"level": 3,
					"passengers_per_minute": 5.5,
					"storage": 58,
					"coin_cost": 13000,
					"resource_cost": {
						"dk_renewable_parts": 2,
						"be_precision_parts": 2
					}
				},
				{
					"level": 4,
					"passengers_per_minute": 7.5,
					"storage": 80,
					"coin_cost": 24000,
					"resource_cost": {
						"gb_aerospace_parts": 3,
						"de_machinery": 3,
						"fr_luxury_goods": 2
					}
				}
			]
		_:
			return []


static func get_level(building_id: String, level: int) -> Dictionary:
	for data in get_levels(building_id):
		if int(data.get("level", 0)) == level:
			return data.duplicate(true)
	return {}


static func get_next_level(building_id: String, current_level: int) -> Dictionary:
	return get_level(building_id, current_level + 1)


static func max_level(building_id: String) -> int:
	var levels := get_levels(building_id)
	if levels.is_empty():
		return 1
	return int(levels[levels.size() - 1].get("level", 1))


static func passenger_stats(building_id: String, level: int) -> Dictionary:
	var data := get_level(building_id, level)
	if data.is_empty():
		data = get_level(building_id, 1)
	return {
		"passengers_per_minute": float(
			data.get("passengers_per_minute", 0.0)
		),
		"storage": int(data.get("storage", 0))
	}
