class_name StarterAirportTutorial
extends Node

signal changed(snapshot: Dictionary)
signal coin_reward_earned(amount: int, reason: String)

const TOTAL_STEPS := 10

const STEPS := [
	{
		"id": "runway",
		"title": "Build your runway",
		"guidance": "Tap SHOW ME, place the Short Runway on open land, then confirm it. Every flight starts and ends here.",
		"action": "build",
		"target": "short_runway",
		"reward": 1500
	},
	{
		"id": "stand",
		"title": "Add a Small Stand",
		"guidance": "Place one Small Stand. Your aircraft stops here for loading, fuel and ground service.",
		"action": "build",
		"target": "small_stand",
		"reward": 1000
	},
	{
		"id": "taxi_network",
		"title": "Connect the airside",
		"guidance": "Lay Taxiways so there is one continuous aircraft route: Hangar → Stand → Runway. Aircraft will physically follow this path.",
		"action": "build",
		"target": "taxiway",
		"reward": 1500
	},
	{
		"id": "service_road",
		"title": "Connect ground service",
		"guidance": "Extend the Service Road to your stand. Fuel and service vehicles use roads; aircraft use taxiways.",
		"action": "build",
		"target": "service_road",
		"reward": 1000
	},
	{
		"id": "hangar_taxi",
		"title": "Watch the first taxi",
		"guidance": "Your Pico now leaves the hangar and follows the taxiway you built to the stand.",
		"action": "aircraft",
		"target": "",
		"reward": 250
	},
	{
		"id": "service",
		"title": "Start ground service",
		"guidance": "When the plane shows SERVICE, tap it. Fuel and service vehicles will drive to the stand.",
		"action": "aircraft",
		"target": "",
		"reward": 500
	},
	{
		"id": "destination",
		"title": "Choose the first route",
		"guidance": "Open the World Map and choose Brussels for your first flight. Routes decide passengers, fuel, time and country resources.",
		"action": "world",
		"target": "brussels",
		"reward": 500
	},
	{
		"id": "load",
		"title": "Load the aircraft",
		"guidance": "When LOAD appears, tap it. Passenger stock is moved onto the aircraft before departure.",
		"action": "aircraft",
		"target": "",
		"reward": 500
	},
	{
		"id": "send",
		"title": "Send the aircraft",
		"guidance": "When SEND appears, tap it. The tug pushes the plane back and it taxis toward the runway.",
		"action": "aircraft",
		"target": "",
		"reward": 500
	},
	{
		"id": "takeoff",
		"title": "First takeoff",
		"guidance": "Watch the Pico taxi to the runway and depart. Your first working airport route is complete.",
		"action": "aircraft",
		"target": "",
		"reward": 1500
	}
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
		"reward": int(step.get("reward", 0))
	}


func _emit_if_changed(snapshot: Dictionary) -> void:
	if snapshot == last_snapshot:
		return
	last_snapshot = snapshot.duplicate(true)
	changed.emit(last_snapshot.duplicate(true))


func _step_complete(index: int) -> bool:
	match index:
		0:
			return _has_building("short_runway")
		1:
			return _has_building("small_stand")
		2:
			return _airside_taxi_network_ready()
		3:
			return _service_road_ready()
		4:
			return bool(
				completed_events.get(
					"hangar_taxi_complete",
					false
				)
			)
		5:
			return bool(
				completed_events.get(
					"service_started",
					false
				)
			)
		6:
			return bool(
				completed_events.get(
					"destination_selected",
					false
				)
			)
		7:
			return bool(
				completed_events.get(
					"load_started",
					false
				)
			)
		8:
			return bool(
				completed_events.get(
					"send_started",
					false
				)
			)
		9:
			return bool(
				completed_events.get(
					"first_departure",
					false
				)
			)
		_:
			return false


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


func _airside_taxi_network_ready() -> bool:
	var stand_uid := _first_stand_uid()
	if stand_uid < 0:
		return false
	if airport_grid.get_departure_routes("S").is_empty():
		return false
	return not airport_grid.get_hangar_to_stand_routes(
		stand_uid,
		"S"
	).is_empty()


func _service_road_ready() -> bool:
	var stand_uid := _first_stand_uid()
	if stand_uid < 0:
		return false
	var fuel := airport_grid.get_best_service_building(
		"fuel",
		"S"
	)
	if fuel.is_empty():
		return false
	var route = airport_grid.get_service_route(
		int(fuel.get("uid", -1)),
		stand_uid
	)
	return route.size() >= 3
