class_name NpcTrafficDirector
extends RefCounted

const FIRST_VISIT_SECONDS := 90.0
const MIN_INTERVAL_SECONDS := 180.0
const MAX_INTERVAL_SECONDS := 360.0
const RETRY_SECONDS := 30.0
const SERVICES := ["fuel", "passenger", "cargo", "cleaning", "catering", "pushback"]
var remaining := FIRST_VISIT_SECONDS
var last_npc := ""
var enabled := true
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

static func catalog() -> Array[Dictionary]:
	var rows := [
		["tess", "Captain Tess", "Meadow Air", "MDW", "BE", "pico_p8"],
		["miles", "Captain Miles", "Channel Commuter", "CHN", "GB", "swift_s14"],
		["elise", "Captain Elise", "Lumiere Air", "LUM", "FR", "comet_c22"],
		["freja", "Captain Freja", "Nordic Hopper", "NRD", "DK", "voyager_v32"],
		["nico", "Captain Nico", "Rhine Regional", "RHN", "DE", "nimbus_n40"],
		["sofia", "Captain Sofia", "Coastal Express", "CST", "FR", "arrow_a52"],
		["mateo", "Captain Mateo", "Atlas Regional", "ATL", "BE", "atlas_a64"],
		["keiko", "Captain Keiko", "Falcon Connect", "FLC", "GB", "falcon_f72"],
		["amara", "Captain Amara", "Horizon Airways", "HRZ", "DK", "horizon_h88"]
	]
	var result: Array[Dictionary] = []
	for row in rows:
		var profile := AircraftCatalog.get_profile(String(row[5]))
		result.append({"id": "npc_" + String(row[0]), "display_name": row[1],
			"airport_name": row[2], "airport_code": row[3], "country_id": row[4],
			"aircraft_type_id": row[5], "relationship": "npc", "system_contact": true,
			"unlock_level": int(profile.get("unlock_level", 1)), "size": profile.get("size", "S")})
	return result

static func stand_ready(grid: AirportGrid, stand_uid: int, size: String) -> bool:
	if grid == null or grid.get_departure_route_options_for_stand(stand_uid, size).is_empty():
		return false
	for service in SERVICES:
		var connected := false
		for station in grid.get_compatible_service_buildings(String(service), size):
			if grid.get_service_route(int(station.get("uid", -1)), stand_uid).size() >= 2:
				connected = true
				break
		if not connected:
			return false
	return true

static func free_ready_stands(grid: AirportGrid, size: String, occupied: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if grid == null:
		return result
	for route in grid.get_arrival_route_options(size):
		var uid := int(route.get("stand_uid", -1))
		if uid < 0 or occupied.has(uid) or result.has(uid):
			continue
		if stand_ready(grid, uid, size):
			result.append(uid)
	return result

static func behavior_profile_for_aircraft(
	type_id: String
) -> Dictionary:
	var aircraft_profile := AircraftCatalog.get_profile(type_id)
	var size := String(aircraft_profile.get("size", "S"))
	var passengers := int(aircraft_profile.get("passengers", 0))

	if size in ["L", "XL"]:
		return {
			"tier": "heavy",
			"taxi_speed_scale": 0.86,
			"taxi_accel_scale": 0.82,
			"turn_rate_deg": 112.0,
			"lineup_delay": 0.62,
			"ground_activity_scale": 0.80,
			"crew_bonus": 1
		}
	if size == "M":
		return {
			"tier": "regional",
			"taxi_speed_scale": 0.92,
			"taxi_accel_scale": 0.88,
			"turn_rate_deg": 126.0,
			"lineup_delay": 0.54,
			"ground_activity_scale": 0.88,
			"crew_bonus": 1
		}
	if passengers >= 24:
		return {
			"tier": "commuter",
			"taxi_speed_scale": 0.99,
			"taxi_accel_scale": 1.00,
			"turn_rate_deg": 145.0,
			"lineup_delay": 0.44,
			"ground_activity_scale": 1.00,
			"crew_bonus": 0
		}

	return {
		"tier": "hopper",
		"taxi_speed_scale": 1.06,
		"taxi_accel_scale": 1.10,
		"turn_rate_deg": 160.0,
		"lineup_delay": 0.36,
		"ground_activity_scale": 1.12,
		"crew_bonus": 0
	}


static func apply_behavior(
	aircraft: AircraftPrototype
) -> Dictionary:
	if aircraft == null or not is_instance_valid(aircraft):
		return {}

	var profile := behavior_profile_for_aircraft(
		aircraft.aircraft_type_id
	)
	var base_taxi_speed := float(
		aircraft.get_meta(
			"npc_base_taxi_speed",
			aircraft.taxi_speed
		)
	)
	var base_taxi_acceleration := float(
		aircraft.get_meta(
			"npc_base_taxi_acceleration",
			aircraft.taxi_acceleration
		)
	)
	if not aircraft.has_meta("npc_base_taxi_speed"):
		aircraft.set_meta(
			"npc_base_taxi_speed",
			base_taxi_speed
		)
	if not aircraft.has_meta("npc_base_taxi_acceleration"):
		aircraft.set_meta(
			"npc_base_taxi_acceleration",
			base_taxi_acceleration
		)

	aircraft.taxi_speed = base_taxi_speed * float(
		profile.get("taxi_speed_scale", 1.0)
	)
	aircraft.taxi_acceleration = (
		base_taxi_acceleration
		* float(
			profile.get(
				"taxi_accel_scale",
				1.0
			)
		)
	)
	aircraft.taxi_turn_rate_deg = float(
		profile.get(
			"turn_rate_deg",
			aircraft.taxi_turn_rate_deg
		)
	)
	aircraft.lineup_delay = float(
		profile.get(
			"lineup_delay",
			aircraft.lineup_delay
		)
	)
	aircraft.set_meta(
		"npc_behavior",
		profile.duplicate(true)
	)
	return profile.duplicate(true)


func eligible(level: int, available_sizes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for contact in catalog():
		if level >= int(contact.get("unlock_level", 1)) and available_sizes.has(contact.get("size", "S")):
			result.append(contact)
	return result

func advance(delta: float, level: int, grid: AirportGrid, occupied: Dictionary,
	own_arrivals_waiting: bool, npc_active: bool, visitors_active: int) -> Dictionary:
	if not enabled or delta <= 0.0:
		return {}
	# Elapsed foreground frames only: never backfill visits from wall-clock/offline time.
	remaining = maxf(remaining - minf(delta, 1.0), 0.0)
	if remaining > 0.0:
		return {}
	if own_arrivals_waiting or npc_active or visitors_active >= SocialAirportService.MAX_ACTIVE_VISITS:
		remaining = RETRY_SECONDS
		return {}
	var sizes: Array = []
	for size in ["S", "M"]:
		if not free_ready_stands(grid, size, occupied).is_empty():
			sizes.append(size)
	var candidates := eligible(level, sizes)
	if candidates.is_empty():
		remaining = RETRY_SECONDS
		return {}
	if candidates.size() > 1:
		for index in range(candidates.size() - 1, -1, -1):
			if String(candidates[index].get("id", "")) == last_npc:
				candidates.remove_at(index)
	# Prefer recently unlocked models, without retiring early NPCs permanently.
	var weighted: Array[Dictionary] = []
	for contact in candidates:
		var weight := 3 if level - int(contact.get("unlock_level", 1)) <= 3 else 1
		for _index in range(weight):
			weighted.append(contact)
	var chosen: Dictionary = weighted[rng.randi_range(0, weighted.size() - 1)]
	last_npc = String(chosen.get("id", ""))
	remaining = rng.randf_range(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS)
	return chosen.duplicate(true)
