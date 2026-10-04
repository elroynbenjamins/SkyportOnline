class_name ResourceDropRules
extends RefCounted

const BASE_CHANCE := 0.40


static func chance_for_flight(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary
) -> float:
	if aircraft_profile.is_empty() or flight_plan.is_empty():
		return 0.0

	var country_code := String(flight_plan.get("country_code", ""))
	if CountryResourceCatalog.resources_for_country(country_code).size() != 3:
		return 0.0

	return BASE_CHANCE


static func modifier_breakdown(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary
) -> Dictionary:
	return {
		"base_chance": BASE_CHANCE,
		"aircraft_modifier": 0.0,
		"duration_modifier": 0.0,
		"size_modifier": 0.0,
		"final_chance": chance_for_flight(aircraft_profile, flight_plan)
	}


static func roll_resources(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary,
	rng: RandomNumberGenerator = null
) -> Array[Dictionary]:
	var chance := chance_for_flight(aircraft_profile, flight_plan)
	var country_code := String(flight_plan.get("country_code", ""))
	var resources := CountryResourceCatalog.resources_for_country(country_code)
	if chance <= 0.0 or resources.is_empty():
		return []

	var active_rng := rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()

	var rolls: Array[float] = []
	for _resource in resources:
		rolls.append(active_rng.randf())
	return evaluate_resources(country_code, rolls)


static func evaluate_resources(
	country_code: String,
	rolls: Array
) -> Array[Dictionary]:
	var resources := CountryResourceCatalog.resources_for_country(country_code)
	var results: Array[Dictionary] = []
	for index in range(resources.size()):
		var resource: Dictionary = resources[index]
		var roll := 1.0
		if index < rolls.size():
			roll = clampf(float(rolls[index]), 0.0, 1.0)
		var success := roll < BASE_CHANCE
		results.append({
			"id": String(resource.get("id", "")),
			"name": String(resource.get("name", "")),
			"chance": BASE_CHANCE,
			"roll": roll,
			"success": success,
			"amount": 1 if success else 0
		})
	return results


static func probability_summary() -> Dictionary:
	var miss := 1.0 - BASE_CHANCE
	return {
		"none": pow(miss, 3),
		"exactly_one": 3.0 * BASE_CHANCE * pow(miss, 2),
		"exactly_two": 3.0 * pow(BASE_CHANCE, 2) * miss,
		"all_three": pow(BASE_CHANCE, 3),
		"expected_resources": 3.0 * BASE_CHANCE
	}
