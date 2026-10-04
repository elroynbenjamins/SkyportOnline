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

	var aircraft_modifier := clampf(
		float(aircraft_profile.get("resource_drop_modifier", 0.0)),
		-0.20,
		0.20
	)
	var duration_modifier := _duration_modifier(
		float(flight_plan.get("duration_seconds", 0.0))
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
	var duration_seconds := float(
		flight_plan.get("duration_seconds", 0.0)
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
		"duration_modifier": _duration_modifier(duration_seconds),
		"size_modifier": _size_modifier(size),
		"final_chance": chance_for_flight(
			aircraft_profile,
			flight_plan
		)
	}


static func roll_resources(
	aircraft_profile: Dictionary,
	flight_plan: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var country_code := String(
		flight_plan.get("country_code", "")
	)
	var resources := CountryResourceCatalog.resources_for_country(
		country_code
	)
	var chance := chance_for_flight(
		aircraft_profile,
		flight_plan
	)
	var results: Array[Dictionary] = []

	for resource in resources:
		var roll := rng.randf()
		var success := roll < chance
		results.append({
			"id": String(resource.get("id", "")),
			"name": String(resource.get("name", "")),
			"chance": chance,
			"roll": roll,
			"success": success,
			"amount": 1 if success else 0
		})

	return results


static func _duration_modifier(duration_seconds: float) -> float:
	var minutes := duration_seconds / 60.0
	if minutes < 5.0:
		return -0.10
	if minutes < 10.0:
		return -0.05
	if minutes < 20.0:
		return 0.0
	if minutes < 40.0:
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
