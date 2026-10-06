class_name DestinationCatalog
extends RefCounted

const DEFAULT_HOME_COUNTRY_ID := "NL"
const DOMESTIC_DISTANCE_KM := 180.0
const EARTH_RADIUS_KM := 6371.0

# Keep a small number of legacy/secondary hubs because events and old saves
# reference these stable IDs. Country resources still come from country_code.
const SECONDARY_HUBS := [
	{
		"id": "berlin",
		"city": "Berlin",
		"country_code": "DE",
		"lat": 52.5200,
		"lon": 13.4050,
		"map_position": Vector2(0.57, 0.20),
		"domestic_distance_km": 420.0
	}
]

static var _home_country_id := DEFAULT_HOME_COUNTRY_ID


static func configure_home_country(country_id: String) -> void:
	if CountryCatalog.get_country(country_id).is_empty():
		_home_country_id = DEFAULT_HOME_COUNTRY_ID
	else:
		_home_country_id = country_id


static func get_home_country_id() -> String:
	return _home_country_id


static func home_country() -> Dictionary:
	var country := CountryCatalog.get_country(_home_country_id)
	if country.is_empty():
		country = CountryCatalog.get_country(
			DEFAULT_HOME_COUNTRY_ID
		)
	return country


static func home_hub_name() -> String:
	var home := home_country()
	return String(
		home.get(
			"hub_city",
			home.get("name", "Home")
		)
	)


static func all() -> Array[Dictionary]:
	var home := home_country()
	var result: Array[Dictionary] = []
	for country_variant in CountryCatalog.get_countries():
		var country: Dictionary = country_variant
		result.append(
			_destination_from_country(home, country)
		)

	for hub_variant in SECONDARY_HUBS:
		var hub: Dictionary = hub_variant
		result.append(
			_destination_from_secondary_hub(home, hub)
		)

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_distance := float(
				a.get("effective_distance_km", 0.0)
			)
			var b_distance := float(
				b.get("effective_distance_km", 0.0)
			)
			if absf(a_distance - b_distance) > 0.01:
				return a_distance < b_distance
			return String(a.get("id", "")) < String(
				b.get("id", "")
			)
	)
	return result


static func get_destination(destination_id: String) -> Dictionary:
	for destination in all():
		if String(destination.get("id", "")) == destination_id:
			return destination.duplicate(true)
	return {}


static func unlocked_for_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination in all():
		if level >= int(destination.get("unlock_level", 1)):
			result.append(destination.duplicate(true))
	return result


static func starter_destination(
	aircraft_profile: Dictionary = {}
) -> Dictionary:
	var profile := aircraft_profile
	if profile.is_empty():
		profile = AircraftCatalog.get_profile("pico_p8")

	for destination in unlocked_for_level(1):
		if FlightRules.can_fly(profile, destination):
			return destination
	return {}


static func career_destination(
	aircraft_id: String,
	level: int,
	route_rank: int = 0
) -> Dictionary:
	var profile := AircraftCatalog.get_profile(aircraft_id)
	if profile.is_empty():
		return {}

	var candidates: Array[Dictionary] = []
	for destination in unlocked_for_level(level):
		if FlightRules.can_fly(profile, destination):
			candidates.append(destination)

	if candidates.is_empty():
		return {}
	var index := posmod(route_rank, candidates.size())
	return candidates[index].duplicate(true)


static func actual_distance_km(
	home_country_id: String,
	destination_country_id: String
) -> float:
	var origin := CountryCatalog.get_country(home_country_id)
	var target := CountryCatalog.get_country(
		destination_country_id
	)
	if origin.is_empty() or target.is_empty():
		return 0.0
	if home_country_id == destination_country_id:
		return DOMESTIC_DISTANCE_KM
	return _haversine_km(
		float(origin.get("hub_lat", 0.0)),
		float(origin.get("hub_lon", 0.0)),
		float(target.get("hub_lat", 0.0)),
		float(target.get("hub_lon", 0.0))
	)


static func effective_distance_km(real_distance_km: float) -> float:
	var distance := maxf(real_distance_km, 1.0)
	# Preserve short-route scale while compressing intercontinental geography
	# into a mobile-game progression range. True distance is still retained for
	# UI/context; this value controls aircraft fit, timer and economy.
	var compressed := (
		175.0
		* pow(distance / 175.0, 0.60)
	)
	return maxf(compressed, DOMESTIC_DISTANCE_KM)


static func _destination_from_country(
	home: Dictionary,
	country: Dictionary
) -> Dictionary:
	var home_id := String(home.get("id", DEFAULT_HOME_COUNTRY_ID))
	var country_id := String(country.get("id", ""))
	var real_distance := (
		DOMESTIC_DISTANCE_KM
		if home_id == country_id
		else _haversine_km(
			float(home.get("hub_lat", 0.0)),
			float(home.get("hub_lon", 0.0)),
			float(country.get("hub_lat", 0.0)),
			float(country.get("hub_lon", 0.0))
		)
	)
	return _build_destination(
		String(country.get("route_id", country_id.to_lower())),
		String(country.get("hub_city", country.get("name", country_id))),
		country_id,
		real_distance,
		Vector2(
			float(country.get("map_x", 0.5)),
			float(country.get("map_y", 0.5))
		),
		home_id == country_id
	)


static func _destination_from_secondary_hub(
	home: Dictionary,
	hub: Dictionary
) -> Dictionary:
	var country_id := String(hub.get("country_code", ""))
	var country := CountryCatalog.get_country(country_id)
	var home_id := String(home.get("id", DEFAULT_HOME_COUNTRY_ID))
	var real_distance := float(
		hub.get("domestic_distance_km", DOMESTIC_DISTANCE_KM)
	)
	if home_id != country_id:
		real_distance = _haversine_km(
			float(home.get("hub_lat", 0.0)),
			float(home.get("hub_lon", 0.0)),
			float(hub.get("lat", 0.0)),
			float(hub.get("lon", 0.0))
		)

	return _build_destination(
		String(hub.get("id", "route")),
		String(hub.get("city", "Destination")),
		country_id,
		real_distance,
		hub.get(
			"map_position",
			Vector2(
				float(country.get("map_x", 0.5)),
				float(country.get("map_y", 0.5))
			)
		),
		home_id == country_id
	)


static func _build_destination(
	id: String,
	city: String,
	country_code: String,
	real_distance: float,
	map_position: Vector2,
	is_domestic: bool
) -> Dictionary:
	var country := CountryCatalog.get_country(country_code)
	var effective := (
		DOMESTIC_DISTANCE_KM
		if is_domestic
		else effective_distance_km(real_distance)
	)
	var unlock_level := _unlock_level(effective, is_domestic)
	var coin_reward := int(round(100.0 + effective * 1.85))
	var xp_reward := int(round(18.0 + effective * 0.095))
	var variance := float(posmod(hash(id), 9) - 4) * 0.0125
	var load_factor := clampf(
		0.68 + effective / 2800.0 * 0.18 + variance,
		0.62,
		0.92
	)

	return {
		"id": id,
		"city": city,
		"country": String(country.get("name", country_code)),
		"country_code": country_code,
		"distance_km": round(real_distance),
		"effective_distance_km": round(effective),
		"unlock_level": unlock_level,
		"coin_reward": coin_reward,
		"xp_reward": xp_reward,
		"passenger_load_factor": load_factor,
		"demand_label": _demand_label(effective, is_domestic),
		"map_position": map_position,
		"home_route": is_domestic,
		"future_long_haul": effective > 2350.0
	}


static func _unlock_level(
	effective_distance: float,
	is_domestic: bool
) -> int:
	if is_domestic:
		return 1
	if effective_distance <= 320.0:
		return 1
	if effective_distance <= 450.0:
		return 2
	if effective_distance <= 600.0:
		return 4
	if effective_distance <= 900.0:
		return 6
	if effective_distance <= 1100.0:
		return 8
	if effective_distance <= 1300.0:
		return 10
	if effective_distance <= 1500.0:
		return 12
	if effective_distance <= 1900.0:
		return 15
	if effective_distance <= 2350.0:
		return 17
	if effective_distance <= 2800.0:
		return 22
	return 26


static func _demand_label(
	effective_distance: float,
	is_domestic: bool
) -> String:
	if is_domestic:
		return "Domestic"
	if effective_distance <= 450.0:
		return "Regional"
	if effective_distance <= 900.0:
		return "Busy"
	if effective_distance <= 1500.0:
		return "International"
	if effective_distance <= 2350.0:
		return "Long Regional"
	return "Long Haul"


static func _haversine_km(
	lat_a: float,
	lon_a: float,
	lat_b: float,
	lon_b: float
) -> float:
	var lat1 := deg_to_rad(lat_a)
	var lat2 := deg_to_rad(lat_b)
	var d_lat := deg_to_rad(lat_b - lat_a)
	var d_lon := deg_to_rad(lon_b - lon_a)
	var sin_lat := sin(d_lat * 0.5)
	var sin_lon := sin(d_lon * 0.5)
	var a := (
		sin_lat * sin_lat
		+ cos(lat1) * cos(lat2) * sin_lon * sin_lon
	)
	var c := 2.0 * atan2(sqrt(a), sqrt(maxf(1.0 - a, 0.0)))
	return EARTH_RADIUS_KM * c
