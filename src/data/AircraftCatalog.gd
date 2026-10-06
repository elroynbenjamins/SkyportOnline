class_name AircraftCatalog
extends RefCounted

# Approved V1 aircraft roster. L / XL remain future-ready but are intentionally
# not part of the first playable catalog.
#
# Ground timers are base seconds before facility upgrades. Fuel-station speed
# modifies fuel only; future passenger/cargo/catering buildings can modify
# their own service category without changing the aircraft definition.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": "pico_p8",
			"name": "Pico P8",
			"size": "S",
			"unlock_level": 1,
			"catalog_role": "Cheap starter",
			"cruise_speed_kph": 280.0,
			"range_km": 320,
			"passengers": 8,
			"reference_flight_minutes": 4.0,
			"timer_factor": 0.350,
			"resource_drop_modifier": 0.00,
			"taxi_speed": 122.0,
			"approach_speed": 205.0,
			"landing_speed": 148.0,
			"takeoff_speed": 242.0,
			"takeoff_acceleration": 138.0,
			"approach_spawn_distance": 520.0,
			"climb_out_distance": 540.0,
			"approach_visual_lift": 74.0,
			"climb_visual_lift": 82.0,
			"deboard_seconds": 6.0,
			"cargo_unload_seconds": 6.0,
			"fuel_seconds": 12.0,
			"clean_seconds": 7.0,
			"catering_seconds": 6.0,
			"board_seconds": 10.0,
			"cargo_load_seconds": 8.0,
			"pushback_seconds": 3.0
		},
		{
			"id": "swift_s14",
			"name": "Swift S14",
			"size": "S",
			"unlock_level": 2,
			"catalog_role": "Fast short-route aircraft",
			"cruise_speed_kph": 360.0,
			"range_km": 430,
			"passengers": 14,
			"reference_flight_minutes": 4.0,
			"timer_factor": 0.335,
			"resource_drop_modifier": -0.20,
			"taxi_speed": 132.0,
			"approach_speed": 218.0,
			"landing_speed": 158.0,
			"takeoff_speed": 252.0,
			"takeoff_acceleration": 148.0,
			"approach_spawn_distance": 560.0,
			"climb_out_distance": 590.0,
			"approach_visual_lift": 78.0,
			"climb_visual_lift": 90.0,
			"deboard_seconds": 7.0,
			"cargo_unload_seconds": 7.0,
			"fuel_seconds": 11.0,
			"clean_seconds": 7.0,
			"catering_seconds": 6.0,
			"board_seconds": 11.0,
			"cargo_load_seconds": 9.0,
			"pushback_seconds": 3.0
		},
		{
			"id": "comet_c22",
			"name": "Comet C22",
			"size": "S",
			"unlock_level": 4,
			"catalog_role": "Early economy aircraft",
			"cruise_speed_kph": 420.0,
			"range_km": 600,
			"passengers": 22,
			"reference_flight_minutes": 6.0,
			"timer_factor": 0.420,
			"resource_drop_modifier": -0.10,
			"taxi_speed": 118.0,
			"deboard_seconds": 8.0,
			"cargo_unload_seconds": 9.0,
			"fuel_seconds": 15.0,
			"clean_seconds": 9.0,
			"catering_seconds": 8.0,
			"board_seconds": 13.0,
			"cargo_load_seconds": 11.0,
			"pushback_seconds": 3.0
		},
		{
			"id": "voyager_v32",
			"name": "Voyager V32",
			"size": "S",
			"unlock_level": 6,
			"catalog_role": "Long-range small aircraft",
			"cruise_speed_kph": 470.0,
			"range_km": 900,
			"passengers": 32,
			"reference_flight_minutes": 8.0,
			"timer_factor": 0.418,
			"resource_drop_modifier": 0.05,
			"taxi_speed": 112.0,
			"deboard_seconds": 9.0,
			"cargo_unload_seconds": 11.0,
			"fuel_seconds": 19.0,
			"clean_seconds": 10.0,
			"catering_seconds": 9.0,
			"board_seconds": 15.0,
			"cargo_load_seconds": 14.0,
			"pushback_seconds": 4.0
		},
		{
			"id": "nimbus_n40",
			"name": "Nimbus N40",
			"size": "M",
			"unlock_level": 8,
			"catalog_role": "First regional aircraft",
			"cruise_speed_kph": 540.0,
			"range_km": 1050,
			"passengers": 40,
			"reference_flight_minutes": 9.0,
			"timer_factor": 0.463,
			"resource_drop_modifier": 0.10,
			"taxi_speed": 100.0,
			"deboard_seconds": 11.0,
			"cargo_unload_seconds": 15.0,
			"fuel_seconds": 24.0,
			"clean_seconds": 13.0,
			"catering_seconds": 11.0,
			"board_seconds": 18.0,
			"cargo_load_seconds": 18.0,
			"pushback_seconds": 5.0
		},
		{
			"id": "arrow_a52",
			"name": "Arrow A52",
			"size": "M",
			"unlock_level": 10,
			"catalog_role": "Fast regional aircraft",
			"cruise_speed_kph": 620.0,
			"range_km": 1300,
			"passengers": 52,
			"reference_flight_minutes": 8.0,
			"timer_factor": 0.382,
			"resource_drop_modifier": -0.10,
			"taxi_speed": 108.0,
			"deboard_seconds": 12.0,
			"cargo_unload_seconds": 17.0,
			"fuel_seconds": 22.0,
			"clean_seconds": 13.0,
			"catering_seconds": 11.0,
			"board_seconds": 19.0,
			"cargo_load_seconds": 20.0,
			"pushback_seconds": 5.0
		},
		{
			"id": "atlas_a64",
			"name": "Atlas A64",
			"size": "M",
			"unlock_level": 12,
			"catalog_role": "Capacity / economy aircraft",
			"cruise_speed_kph": 560.0,
			"range_km": 1500,
			"passengers": 64,
			"reference_flight_minutes": 11.0,
			"timer_factor": 0.411,
			"resource_drop_modifier": 0.20,
			"taxi_speed": 92.0,
			"deboard_seconds": 14.0,
			"cargo_unload_seconds": 21.0,
			"fuel_seconds": 30.0,
			"clean_seconds": 16.0,
			"catering_seconds": 14.0,
			"board_seconds": 23.0,
			"cargo_load_seconds": 27.0,
			"pushback_seconds": 6.0
		},
		{
			"id": "falcon_f72",
			"name": "Falcon F72",
			"size": "M",
			"unlock_level": 15,
			"catalog_role": "Higher-performance regional aircraft",
			"cruise_speed_kph": 680.0,
			"range_km": 1900,
			"passengers": 72,
			"reference_flight_minutes": 10.0,
			"timer_factor": 0.358,
			"resource_drop_modifier": 0.00,
			"taxi_speed": 102.0,
			"deboard_seconds": 14.0,
			"cargo_unload_seconds": 20.0,
			"fuel_seconds": 28.0,
			"clean_seconds": 15.0,
			"catering_seconds": 13.0,
			"board_seconds": 22.0,
			"cargo_load_seconds": 25.0,
			"pushback_seconds": 6.0
		},
		{
			"id": "horizon_h88",
			"name": "Horizon H88",
			"size": "M",
			"unlock_level": 17,
			"catalog_role": "V1 flagship",
			"cruise_speed_kph": 720.0,
			"range_km": 2350,
			"passengers": 88,
			"reference_flight_minutes": 13.0,
			"timer_factor": 0.398,
			"resource_drop_modifier": 0.15,
			"taxi_speed": 94.0,
			"deboard_seconds": 16.0,
			"cargo_unload_seconds": 24.0,
			"fuel_seconds": 36.0,
			"clean_seconds": 18.0,
			"catering_seconds": 16.0,
			"board_seconds": 26.0,
			"cargo_load_seconds": 32.0,
			"pushback_seconds": 7.0
		}
	]


static func get_profile(aircraft_id: String) -> Dictionary:
	for profile in all():
		if String(profile["id"]) == aircraft_id:
			return profile.duplicate(true)
	return {}


static func unlocked_for_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in all():
		if level >= int(profile.get("unlock_level", 1)):
			result.append(profile.duplicate(true))
	return result


static func supports_destination(
	aircraft_id: String,
	distance_km: float
) -> bool:
	var profile := get_profile(aircraft_id)
	if profile.is_empty():
		return false
	return distance_km <= float(profile.get("range_km", 0.0))
