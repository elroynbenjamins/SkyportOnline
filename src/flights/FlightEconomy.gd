class_name FlightEconomy
extends RefCounted


static func is_route_compatible(
	aircraft: Dictionary,
	route: Dictionary,
	player_level: int
) -> bool:
	if aircraft.is_empty() or route.is_empty():
		return false

	if player_level < int(route.get("unlock_level", 1)):
		return false

	if int(route.get("distance_km", 0)) > int(aircraft.get("range_km", 0)):
		return false

	var aircraft_rank := AircraftCatalog.size_rank(
		String(aircraft.get("size_class", "S"))
	)
	var max_route_rank := AircraftCatalog.size_rank(
		String(route.get("max_aircraft_size", "XL"))
	)
	return aircraft_rank <= max_route_rank


static func calculate_manifest(
	aircraft: Dictionary,
	route: Dictionary,
	player_level: int
) -> Dictionary:
	if not is_route_compatible(aircraft, route, player_level):
		return {}

	var capacity := maxi(int(aircraft.get("capacity", 0)), 1)
	var demand := maxi(int(route.get("demand", 0)), 0)
	var passengers := mini(capacity, demand)
	var distance_km := maxi(int(route.get("distance_km", 0)), 0)
	var speed_kmh := maxf(float(aircraft.get("cruise_speed_kmh", 1.0)), 1.0)

	var ticket_revenue := passengers * int(route.get("ticket_yield", 0))
	var completion_bonus := int(route.get("completion_bonus", 0))
	var gross_revenue := ticket_revenue + completion_bonus

	var fuel_cost := int(round(
		float(distance_km) * float(aircraft.get("fuel_cost_per_km", 0.0))
	))
	var fixed_cost := int(aircraft.get("fixed_operating_cost", 0))
	var passenger_service_cost := int(round(
		float(passengers) * float(
			aircraft.get("service_cost_per_passenger", 0.0)
		)
	))
	var operating_cost := fuel_cost + fixed_cost + passenger_service_cost
	var net_profit := gross_revenue - operating_cost

	var duration_minutes := int(ceil(
		(float(distance_km) / speed_kmh) * 60.0 + 8.0
	))
	var simulation_seconds := clampf(
		float(duration_minutes) * 0.15,
		6.0,
		45.0
	)
	var load_factor := float(passengers) / float(capacity)
	var xp_reward := int(route.get("xp_reward", 0)) + int(round(passengers / 4.0))
	var profit_per_minute := 0.0
	if duration_minutes > 0:
		profit_per_minute = float(net_profit) / float(duration_minutes)

	return {
		"aircraft_id": String(aircraft.get("id", "")),
		"aircraft_name": String(aircraft.get("name", "Aircraft")),
		"route_id": String(route.get("id", "")),
		"route_name": String(route.get("name", "Route")),
		"destination_name": String(route.get("destination_name", "Destination")),
		"country_code": String(route.get("country_code", "")),
		"distance_km": distance_km,
		"passengers": passengers,
		"capacity": capacity,
		"load_factor": load_factor,
		"gross_revenue": gross_revenue,
		"operating_cost": operating_cost,
		"net_profit": net_profit,
		"xp_reward": xp_reward,
		"duration_minutes": duration_minutes,
		"simulation_seconds": simulation_seconds,
		"resource_pool_key": String(route.get("resource_pool_key", "")),
		"resource_drop_chance": float(route.get("resource_drop_chance", 0.0)),
		"profit_per_minute": profit_per_minute
	}


static func best_manifest_for_aircraft(
	aircraft: Dictionary,
	player_level: int
) -> Dictionary:
	var best: Dictionary = {}
	for route in RouteCatalog.get_available(player_level):
		var manifest := calculate_manifest(aircraft, route, player_level)
		if manifest.is_empty():
			continue
		if best.is_empty() or float(manifest.get("profit_per_minute", -INF)) > float(
			best.get("profit_per_minute", -INF)
		):
			best = manifest
	return best
