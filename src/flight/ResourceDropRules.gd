class_name ResourceDropRules
extends RefCounted

const BASE_CHANCE := 0.40
const MIN_CHANCE := 0.20
const MAX_CHANCE := 0.70


static func chance_for_flight(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary
) -> float:
	if aircraft_profile.is_empty() or flight_plan.is_empty():
		return 0.0

	var country_code := String(flight_plan.get("country_code", ""))
	if CountryResourceCatalog.resources_for_country(country_code).size() != 3:
		return 0.0

	var aircraft_modifier := clampf(
		float(aircraft_profile.get("resource_drop_modifier", 0.0)),
		-0.20,
		0.20
	)
	var duration_modifier := _route_distance_modifier(
		float(flight_plan.get("distance_km", 0.0))
	)
	var size_modifier := _size_modifier(
		String(aircraft_profile.get("size", "S"))
	)

	var chance := BASE_CHANCE
	chance *= 1.0 + aircraft_modifier
	chance *= 1.0 + duration_modifier
	chance *= 1.0 + size_modifier
	return clampf(chance, MIN_CHANCE, MAX_CHANCE)


static func modifier_breakdown(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary
) -> Dictionary:
	var route_distance_km := float(
		flight_plan.get("distance_km", 0.0)
	)
	var size := String(aircraft_profile.get("size", "S"))
	return {
		"base_chance": BASE_CHANCE,
		"aircraft_modifier": clampf(
			float(
				aircraft_profile.get(
					"resource_drop_modifier",
					0.0
				)
			),
			-0.20,
			0.20
		),
		"duration_modifier": _route_distance_modifier(route_distance_km),
		"route_distance_modifier": _route_distance_modifier(route_distance_km),
		"size_modifier": _size_modifier(size),
		"final_chance": chance_for_flight(
			aircraft_profile,
			flight_plan
		)
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
	return evaluate_resources(country_code, rolls, chance)


static func evaluate_resources(
	country_code: String,
	rolls: Array,
	chance: float = BASE_CHANCE
) -> Array[Dictionary]:
	var resources := CountryResourceCatalog.resources_for_country(country_code)
	var results: Array[Dictionary] = []
	var final_chance := clampf(chance, 0.0, 1.0)

	for index in range(resources.size()):
		var resource: Dictionary = resources[index]
		var roll := 1.0
		if index < rolls.size():
			roll = clampf(float(rolls[index]), 0.0, 1.0)
		var success := roll < final_chance
		results.append({
			"id": String(resource.get("id", "")),
			"name": String(resource.get("name", "")),
			"chance": final_chance,
			"roll": roll,
			"success": success,
			"amount": 1 if success else 0
		})
	return results


static func probability_summary(
	chance: float = BASE_CHANCE
) -> Dictionary:
	var p := clampf(chance, 0.0, 1.0)
	var miss := 1.0 - p
	return {
		"none": pow(miss, 3),
		"exactly_one": 3.0 * p * pow(miss, 2),
		"exactly_two": 3.0 * pow(p, 2) * miss,
		"all_three": pow(p, 3),
		"expected_resources": 3.0 * p
	}


static func _route_distance_modifier(
	distance_km: float
) -> float:
	var distance := maxf(distance_km, 0.0)
	if distance < 450.0:
		return -0.10
	if distance < 900.0:
		return -0.05
	if distance < 2000.0:
		return 0.0
	if distance < 5000.0:
		return 0.05
	return 0.10


static func _size_modifier(size: String) -> float:
	match size:
		"M":
			return 0.05
		"L":
			return 0.10
		"XL":
			return 0.15
		_:
			return 0.0
