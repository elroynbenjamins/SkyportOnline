class_name FlightRules
extends RefCounted

# One real-world flight hour becomes this many gameplay timer minutes.
# This keeps nearby routes meaningful without requiring real aviation times.
const GAMEPLAY_MINUTES_PER_REAL_FLIGHT_HOUR := 10.0
const MINIMUM_FLIGHT_MINUTES := 3.0


static func can_fly(
	aircraft_profile: Dictionary,
	destination: Dictionary
) -> bool:
	if aircraft_profile.is_empty() or destination.is_empty():
		return false

	var range_km := float(aircraft_profile.get("range_km", 0.0))
	var distance_km := float(destination.get("distance_km", 0.0))
	return range_km >= distance_km


static func duration_minutes(
	aircraft_profile: Dictionary,
	destination: Dictionary
) -> float:
	if not can_fly(aircraft_profile, destination):
		return 0.0

	var speed_kph := maxf(
		float(aircraft_profile.get("cruise_speed_kph", 1.0)),
		1.0
	)
	var distance_km := float(destination.get("distance_km", 0.0))
	var timer_factor := maxf(
		float(aircraft_profile.get("timer_factor", 1.0)),
		0.1
	)

	var real_flight_hours := distance_km / speed_kph
	var gameplay_minutes := (
		real_flight_hours
		* GAMEPLAY_MINUTES_PER_REAL_FLIGHT_HOUR
		* timer_factor
	)
	return maxf(gameplay_minutes, MINIMUM_FLIGHT_MINUTES)


static func duration_seconds(
	aircraft_profile: Dictionary,
	destination: Dictionary
) -> float:
	return duration_minutes(aircraft_profile, destination) * 60.0


static func create_flight_plan(
	aircraft_profile: Dictionary,
	destination: Dictionary
) -> Dictionary:
	if not can_fly(aircraft_profile, destination):
		return {}

	return {
		"destination_id": String(destination.get("id", "")),
		"city": String(destination.get("city", "")),
		"country": String(destination.get("country", "")),
		"country_code": String(destination.get("country_code", "")),
		"distance_km": float(destination.get("distance_km", 0.0)),
		"duration_seconds": duration_seconds(aircraft_profile, destination),
		"coin_reward": int(destination.get("coin_reward", 0)),
		"xp_reward": int(destination.get("xp_reward", 0))
	}


static func format_duration(seconds: float) -> String:
	var total_seconds := maxi(int(round(seconds)), 0)
	var minutes := total_seconds / 60
	var remaining_seconds := total_seconds % 60

	if minutes >= 60:
		var hours := minutes / 60
		var remaining_minutes := minutes % 60
		return "%dh %02dm" % [hours, remaining_minutes]

	if remaining_seconds == 0:
		return "%dm" % minutes
	return "%dm %02ds" % [minutes, remaining_seconds]
