class_name FlightRewardRules
extends RefCounted


static func create_return_reward(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if aircraft_profile.is_empty() or flight_plan.is_empty():
		return {}

	var resource_rolls := ResourceDropRules.roll_resources(
		aircraft_profile,
		flight_plan,
		rng
	)
	var resources_won: Array[Dictionary] = []
	for result in resource_rolls:
		if bool(result.get("success", false)):
			resources_won.append({
				"id": String(result.get("id", "")),
				"name": String(result.get("name", "")),
				"amount": int(result.get("amount", 1))
			})

	return {
		"destination_id": String(
			flight_plan.get("destination_id", "")
		),
		"city": String(flight_plan.get("city", "")),
		"country": String(flight_plan.get("country", "")),
		"country_code": String(
			flight_plan.get("country_code", "")
		),
		"coins": int(flight_plan.get("coin_reward", 0)),
		"xp": int(flight_plan.get("xp_reward", 0)),
		"resource_chance": ResourceDropRules.chance_for_flight(
			aircraft_profile,
			flight_plan
		),
		"resource_rolls": resource_rolls,
		"resources_won": resources_won
	}
