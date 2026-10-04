class_name DestinationCatalog
extends RefCounted

# Development origin only. The airport-creation flow will replace this with
# the player's selected home country / airport.
const DEVELOPMENT_HOME_NAME := "Amsterdam"


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "brussels",
			"city": "Brussels",
			"country": "Belgium",
			"country_code": "BE",
			"distance_km": 175.0,
			"unlock_level": 1,
			"coin_reward": 420,
			"xp_reward": 32,
			"passenger_load_factor": 0.65,
			"demand_label": "Feeder",
			"map_position": Vector2(0.43, 0.59)
		},
		{
			"id": "london",
			"city": "London",
			"country": "United Kingdom",
			"country_code": "GB",
			"distance_km": 360.0,
			"unlock_level": 1,
			"coin_reward": 760,
			"xp_reward": 48,
			"passenger_load_factor": 0.90,
			"demand_label": "Busy",
			"map_position": Vector2(0.28, 0.48)
		},
		{
			"id": "frankfurt",
			"city": "Frankfurt",
			"country": "Germany",
			"country_code": "DE",
			"distance_km": 365.0,
			"unlock_level": 2,
			"coin_reward": 790,
			"xp_reward": 50,
			"passenger_load_factor": 0.82,
			"demand_label": "Business",
			"map_position": Vector2(0.56, 0.59)
		},
		{
			"id": "paris",
			"city": "Paris",
			"country": "France",
			"country_code": "FR",
			"distance_km": 430.0,
			"unlock_level": 2,
			"coin_reward": 900,
			"xp_reward": 58,
			"passenger_load_factor": 0.88,
			"demand_label": "Popular",
			"map_position": Vector2(0.39, 0.70)
		},
		{
			"id": "berlin",
			"city": "Berlin",
			"country": "Germany",
			"country_code": "DE",
			"distance_km": 575.0,
			"unlock_level": 4,
			"coin_reward": 1180,
			"xp_reward": 72,
			"passenger_load_factor": 0.78,
			"demand_label": "Steady",
			"map_position": Vector2(0.68, 0.48)
		},
		{
			"id": "copenhagen",
			"city": "Copenhagen",
			"country": "Denmark",
			"country_code": "DK",
			"distance_km": 620.0,
			"unlock_level": 5,
			"coin_reward": 1280,
			"xp_reward": 78,
			"passenger_load_factor": 0.72,
			"demand_label": "Moderate",
			"map_position": Vector2(0.61, 0.30)
		}
	]


static func get_destination(destination_id: String) -> Dictionary:
	for destination in all():
		if String(destination["id"]) == destination_id:
			return destination.duplicate(true)
	return {}


static func unlocked_for_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination in all():
		if level >= int(destination.get("unlock_level", 1)):
			result.append(destination.duplicate(true))
	return result
