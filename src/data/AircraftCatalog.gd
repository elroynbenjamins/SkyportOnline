class_name AircraftCatalog
extends RefCounted

# Prototype profiles used by the first flight-system bridge.
# Names/stats can be replaced by the final V1 plane catalog without changing
# the flight-duration or World Map systems.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": "aerolet_100",
			"name": "Aerolet 100",
			"size": "S",
			"cruise_speed_kph": 320.0,
			"range_km": 850,
			"passengers": 18,
			"timer_factor": 1.00,
			"resource_drop_modifier": 0.00
		},
		{
			"id": "aerolet_120",
			"name": "Aerolet 120",
			"size": "S",
			"cruise_speed_kph": 410.0,
			"range_km": 1050,
			"passengers": 24,
			"timer_factor": 0.96,
			"resource_drop_modifier": -0.20
		},
		{
			"id": "regional_200",
			"name": "Regional 200",
			"size": "M",
			"cruise_speed_kph": 610.0,
			"range_km": 1800,
			"passengers": 58,
			"timer_factor": 1.00,
			"resource_drop_modifier": 0.20
		}
	]


static func get_profile(aircraft_id: String) -> Dictionary:
	for profile in all():
		if String(profile["id"]) == aircraft_id:
			return profile.duplicate(true)
	return {}


static func supports_destination(
	aircraft_id: String,
	distance_km: float
) -> bool:
	var profile := get_profile(aircraft_id)
	if profile.is_empty():
		return false
	return distance_km <= float(profile.get("range_km", 0.0))
