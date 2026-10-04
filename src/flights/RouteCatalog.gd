class_name RouteCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "northsea_shuttle",
			"name": "North Sea Shuttle",
			"destination_name": "Bremen",
			"country_code": "DE",
			"distance_km": 180,
			"demand": 10,
			"ticket_yield": 60,
			"completion_bonus": 80,
			"xp_reward": 8,
			"unlock_level": 1,
			"max_aircraft_size": "S",
			"route_class": "local",
			"resource_pool_key": "country:DE",
			"resource_drop_chance": 0.40
		},
		{
			"id": "lowlands_link",
			"name": "Lowlands Link",
			"destination_name": "Brussels",
			"country_code": "BE",
			"distance_km": 260,
			"demand": 18,
			"ticket_yield": 64,
			"completion_bonus": 100,
			"xp_reward": 12,
			"unlock_level": 2,
			"max_aircraft_size": "S",
			"route_class": "local",
			"resource_pool_key": "country:BE",
			"resource_drop_chance": 0.40
		},
		{
			"id": "channel_hop",
			"name": "Channel Hop",
			"destination_name": "London",
			"country_code": "GB",
			"distance_km": 430,
			"demand": 26,
			"ticket_yield": 70,
			"completion_bonus": 130,
			"xp_reward": 18,
			"unlock_level": 4,
			"max_aircraft_size": "S",
			"route_class": "short",
			"resource_pool_key": "country:GB",
			"resource_drop_chance": 0.40
		},
		{
			"id": "alpine_connector",
			"name": "Alpine Connector",
			"destination_name": "Zurich",
			"country_code": "CH",
			"distance_km": 690,
			"demand": 36,
			"ticket_yield": 82,
			"completion_bonus": 190,
			"xp_reward": 24,
			"unlock_level": 6,
			"max_aircraft_size": "S",
			"route_class": "short",
			"resource_pool_key": "country:CH",
			"resource_drop_chance": 0.40
		},
		{
			"id": "nordic_connector",
			"name": "Nordic Connector",
			"destination_name": "Copenhagen",
			"country_code": "DK",
			"distance_km": 900,
			"demand": 48,
			"ticket_yield": 90,
			"completion_bonus": 260,
			"xp_reward": 34,
			"unlock_level": 8,
			"max_aircraft_size": "M",
			"route_class": "regional",
			"resource_pool_key": "country:DK",
			"resource_drop_chance": 0.40
		},
		{
			"id": "central_express",
			"name": "Central Express",
			"destination_name": "Prague",
			"country_code": "CZ",
			"distance_km": 1200,
			"demand": 62,
			"ticket_yield": 98,
			"completion_bonus": 340,
			"xp_reward": 45,
			"unlock_level": 10,
			"max_aircraft_size": "M",
			"route_class": "regional",
			"resource_pool_key": "country:CZ",
			"resource_drop_chance": 0.40
		},
		{
			"id": "southern_business",
			"name": "Southern Business",
			"destination_name": "Milan",
			"country_code": "IT",
			"distance_km": 1450,
			"demand": 72,
			"ticket_yield": 108,
			"completion_bonus": 450,
			"xp_reward": 58,
			"unlock_level": 12,
			"max_aircraft_size": "M",
			"route_class": "regional",
			"resource_pool_key": "country:IT",
			"resource_drop_chance": 0.40
		},
		{
			"id": "iberian_sunline",
			"name": "Iberian Sunline",
			"destination_name": "Barcelona",
			"country_code": "ES",
			"distance_km": 1800,
			"demand": 82,
			"ticket_yield": 120,
			"completion_bonus": 560,
			"xp_reward": 75,
			"unlock_level": 15,
			"max_aircraft_size": "M",
			"route_class": "long_regional",
			"resource_pool_key": "country:ES",
			"resource_drop_chance": 0.40
		},
		{
			"id": "mediterranean_reach",
			"name": "Mediterranean Reach",
			"destination_name": "Rome",
			"country_code": "IT",
			"distance_km": 2200,
			"demand": 96,
			"ticket_yield": 132,
			"completion_bonus": 700,
			"xp_reward": 95,
			"unlock_level": 17,
			"max_aircraft_size": "M",
			"route_class": "long_regional",
			"resource_pool_key": "country:IT",
			"resource_drop_chance": 0.40
		}
	]


static func get_definition(route_id: String) -> Dictionary:
	for definition in all():
		if String(definition.get("id", "")) == route_id:
			return definition.duplicate(true)
	return {}


static func get_available(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in all():
		if int(definition.get("unlock_level", 1)) <= level:
			result.append(definition.duplicate(true))
	return result
