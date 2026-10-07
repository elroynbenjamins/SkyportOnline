class_name StarterAirportTutorial
extends Node

signal changed(snapshot: Dictionary)
signal coin_reward_earned(amount: int, reason: String)

const TOTAL_STEPS := 15

const STEPS := [
	{"id":"runway","title":"Place your first runway","guidance":"Your Main Airport Building is ready. Place the free Short Runway on the open airside land.","action":"build","target":"short_runway","recommended_origin":Vector2i(0,0),"reward":0},
	{"id":"stand","title":"Add a Small Stand","guidance":"Place the free Small Stand. Aircraft stop here for fuel, handling and loading.","action":"build","target":"small_stand","recommended_origin":Vector2i(4,6),"reward":0},
	{"id":"runway_taxi","title":"Connect Stand to Runway","guidance":"Lay free Taxiway tiles from the stand to the runway. Aircraft can only move through connected Taxiways.","action":"build","target":"taxiway","recommended_origin":Vector2i(3,2),"reward":0},
	{"id":"hangar","title":"Build the aircraft hangar","guidance":"Place the free Small Hangar. Your first aircraft starts here before taxiing to the stand.","action":"build","target":"small_hangar","recommended_origin":Vector2i(0,10),"reward":0},
	{"id":"hangar_taxi_network","title":"Connect Hangar to Stand","guidance":"Extend the free Taxiway network from the stand to the hangar. The full aircraft route is Hangar → Stand → Runway.","action":"build","target":"taxiway","recommended_origin":Vector2i(3,7),"reward":0},
	{"id":"fuel_station","title":"Add fuel service","guidance":"Place the free Basic Fuel Station. Its fuel truck will need a Service Road to reach the stand.","action":"build","target":"basic_fuel","recommended_origin":Vector2i(8,5),"reward":0},
	{"id":"ground_ops","title":"Add Ground Operations","guidance":"Place the free Ground Operations Depot for cleaning, catering, baggage, passenger vehicles and pushback.","action":"build","target":"ground_ops_depot","recommended_origin":Vector2i(5,10),"reward":0},
	{"id":"service_road","title":"Connect ground service","guidance":"Lay free Service Road tiles so Fuel and Ground Ops can drive to the stand. Aircraft use Taxiways; vehicles use Service Roads.","action":"build","target":"service_road","recommended_origin":Vector2i(7,6),"reward":0},
	{"id":"terminal","title":"Place the terminal","guidance":"Place the free Small Terminal to establish the passenger side of your airport.","action":"build","target":"small_terminal","recommended_origin":Vector2i(9,11),"reward":0},
	{"id":"hangar_taxi","title":"Watch the first taxi","guidance":"Your Pico is ready. Watch it leave the hangar and follow the Taxiways you built to the stand.","action":"aircraft","target":"","reward":250},
	{"id":"service","title":"Start ground service","guidance":"When the plane shows SERVICE, tap it. Fuel and service vehicles will use the Service Roads you built.","action":"aircraft","target":"","reward":250},
	{"id":"destination","title":"Choose the first route","guidance":"Open the World Map and choose a nearby unlocked destination.","action":"world","target":"","reward":250},
	{"id":"load","title":"Load the aircraft","guidance":"When LOAD appears, tap it. Passenger stock is moved onto the aircraft before departure.","action":"aircraft","target":"","reward":250},
	{"id":"send","title":"Send the aircraft","guidance":"When SEND appears, tap it. The tug pushes the plane back and it taxis toward your runway.","action":"aircraft","target":"","reward":250},
	{"id":"takeoff","title":"First takeoff","guidance":"Watch the Pico depart. You built and operated your first complete airport flow.","action":"aircraft","target":"","reward":1000}
]

var airport_grid
var active := false
var step_index := 0
var completed_events: Dictionary = {}
var rewarded_steps: Dictionary = {}
var last_snapshot: Dictionary = {}


func configure(grid, enabled: bool = true) -> void:
	airport_grid = grid
	active = enabled
	step_index = 0
	completed_events.clear()
	rewarded_steps.clear()
	last_snapshot = {}
	refresh()


func disable() -> void:
	active = false
	last_snapshot = {"active": false, "complete": true}
	changed.emit(last_snapshot.duplicate(true))


func notify_event(event_id: String) -> void:
	if not active or event_id.is_empty():
		return
	completed_events[event_id] = true
	refresh()


func refresh() -> Dictionary:
	if not active or airport_grid == null:
		var inactive := {
			"active": false,
			"complete": true
		}
		_emit_if_changed(inactive)
		return inactive

	while (
		step_index < STEPS.size()
		and _step_complete(step_index)
	):
		var completed_step: Dictionary = STEPS[step_index]
		var step_id := String(completed_step.get("id", ""))
		if not rewarded_steps.has(step_id):
			rewarded_steps[step_id] = true
			var reward := int(completed_step.get("reward", 0))
			if reward > 0:
				coin_reward_earned.emit(
					reward,
					String(completed_step.get("title", "Tutorial"))
				)
		step_index += 1

	var snapshot := _snapshot()
	_emit_if_changed(snapshot)
	return snapshot


func get_snapshot() -> Dictionary:
	if last_snapshot.is_empty():
		return refresh()
	return last_snapshot.duplicate(true)


func _snapshot() -> Dictionary:
	if step_index >= STEPS.size():
		return {
			"active": false,
			"complete": true,
			"step": TOTAL_STEPS,
			"total": TOTAL_STEPS,
			"title": "Airport basics complete",
			"guidance": "Runway, stand, taxiways and service roads now work together. Keep expanding and improve the airport at your own pace.",
			"action": "",
			"target": "",
			"reward": 0
		}

	var step: Dictionary = STEPS[step_index]
	return {
		"active": true,
		"complete": false,
		"step": step_index + 1,
		"total": TOTAL_STEPS,
		"id": String(step.get("id", "")),
		"title": String(step.get("title", "")),
		"guidance": String(step.get("guidance", "")),
		"action": String(step.get("action", "")),
		"target": String(step.get("target", "")),
		"tutorial_grant": (
			String(step.get("action", "")) == "build"
			and not String(step.get("target", "")).is_empty()
		),
		"reward": int(step.get("reward", 0)),
		"recommended_origin": step.get("recommended_origin", Vector2i(-1, -1))
	}


func _emit_if_changed(snapshot: Dictionary) -> void:
	if snapshot == last_snapshot:
		return
	last_snapshot = snapshot.duplicate(true)
	changed.emit(last_snapshot.duplicate(true))


func _step_complete(index: int) -> bool:
	match index:
		0: return _has_building("short_runway")
		1: return _has_building("small_stand")
		2: return _stand_to_runway_ready()
		3: return _has_building("small_hangar")
		4: return _full_airside_taxi_network_ready()
		5: return _has_building("basic_fuel")
		6: return _has_building("ground_ops_depot")
		7: return _service_road_ready()
		8: return _has_building("small_terminal")
		9: return bool(completed_events.get("hangar_taxi_complete", false))
		10: return bool(completed_events.get("service_started", false))
		11: return bool(completed_events.get("destination_selected", false))
		12: return bool(completed_events.get("load_started", false))
		13: return bool(completed_events.get("send_started", false))
		14: return bool(completed_events.get("first_departure", false))
		_: return false

func _has_building(building_id: String) -> bool:
	for building_variant in airport_grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get("definition_id", "")
		) == building_id:
			return true
	return false


func _first_stand_uid() -> int:
	for building_variant in airport_grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get("definition_id", "")
		) == "small_stand":
			return int(building.get("uid", -1))
	return -1


func _stand_to_runway_ready() -> bool:
	var stand_uid := _first_stand_uid()
	if stand_uid < 0:
		return false
	return not airport_grid.get_departure_routes("S").is_empty()


func _full_airside_taxi_network_ready() -> bool:
	var stand_uid := _first_stand_uid()
	if stand_uid < 0 or not _stand_to_runway_ready():
		return false
	return not airport_grid.get_hangar_to_stand_routes(
		stand_uid,
		"S"
	).is_empty()


func _service_road_ready() -> bool:
	var stand_uid := _first_stand_uid()
	if stand_uid < 0:
		return false

	var fuel: Dictionary = airport_grid.get_best_service_building(
		"fuel",
		"S"
	)
	var ground_ops: Dictionary = airport_grid.get_best_service_building(
		"cleaning",
		"S"
	)
	if fuel.is_empty() or ground_ops.is_empty():
		return false

	for station_variant in [fuel, ground_ops]:
		var station: Dictionary = station_variant
		var route: PackedVector2Array = airport_grid.get_service_route(
			int(station.get("uid", -1)),
			stand_uid
		)
		if route.size() < 3:
			return false
	return true
