class_name StarterAirportTutorial
extends Node

signal changed(snapshot: Dictionary)
signal coin_reward_earned(amount: int, reason: String)

const TOTAL_STEPS := 12

# V1 deliberately follows the Skyrama interaction loop. Aircraft animate on
# the runway, while handling transfers between structures are instant.
const STEPS := [
	{
		"id":"runway",
		"title":"Place your first runway",
		"guidance":"Place the free Short Runway. Arriving planes land here and departing planes take off here.",
		"action":"build",
		"target":"short_runway",
		"recommended_origin":Vector2i(0,0),
		"reward":0
	},
	{
		"id":"hangar",
		"title":"Build the aircraft hangar",
		"guidance":"Place the free Small Hangar. Your own aircraft are stored here between flights.",
		"action":"build",
		"target":"small_hangar",
		"recommended_origin":Vector2i(0,10),
		"reward":0
	},
	{
		"id":"fuel_station",
		"title":"Add fuel service",
		"guidance":"Place the free Basic Fuel Station. After you choose a destination, your plane appears here and fuels automatically.",
		"action":"build",
		"target":"basic_fuel",
		"recommended_origin":Vector2i(8,5),
		"reward":0
	},
	{
		"id":"cargo_ops",
		"title":"Add cargo handling",
		"guidance":"Place the free Ground Operations Depot. For now it handles loading and de-cargo after flights.",
		"action":"build",
		"target":"ground_ops_depot",
		"recommended_origin":Vector2i(5,10),
		"reward":0
	},
	{
		"id":"destination",
		"title":"Choose your first destination",
		"guidance":"Open Fleet, select your Pico, then choose a country on the World Map. The plane will appear at the Fuel Station.",
		"action":"world",
		"target":"",
		"reward":250
	},
	{
		"id":"fuel_ready",
		"title":"Wait for fueling",
		"guidance":"Fueling runs automatically. When it reaches 100%, a LOAD bubble appears above the plane.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"load",
		"title":"Send it to cargo handling",
		"guidance":"Tap the LOAD bubble. The plane moves instantly to Cargo / Ground Ops and begins loading.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"send",
		"title":"Send the aircraft",
		"guidance":"Wait for loading to finish. When SEND appears, tap it. The plane moves to the runway start.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"takeoff",
		"title":"Watch the first takeoff",
		"guidance":"The plane accelerates along the runway and flies to its destination.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"receive",
		"title":"Receive your returning plane",
		"guidance":"When the flight returns, tap LAND. It will land and stop at the runway end. Only one aircraft may occupy a runway at a time.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"unload",
		"title":"De-cargo the plane",
		"guidance":"Tap UNLOAD above the landed plane. It moves instantly to Cargo / Ground Ops and unloads there.",
		"action":"aircraft",
		"target":"",
		"reward":250
	},
	{
		"id":"hangar_return",
		"title":"Return it to the hangar",
		"guidance":"When unloading is complete, tap HANGAR. The plane returns to your inventory ready for another route.",
		"action":"aircraft",
		"target":"",
		"reward":500
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
					String(
						completed_step.get(
							"title",
							"Tutorial"
						)
					)
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
			"guidance": (
				"You can now send, receive, load and unload your own aircraft. "
				+ "Taxiway movement can be expanded later without blocking this core loop."
			),
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
			and not String(
				step.get("target", "")
			).is_empty()
		),
		"reward": int(step.get("reward", 0)),
		"recommended_origin": step.get(
			"recommended_origin",
			Vector2i(-1, -1)
		)
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
			return _has_building("small_hangar")
		2:
			return _has_building("basic_fuel")
		3:
			return _has_building("ground_ops_depot")
		4:
			return bool(
				completed_events.get(
					"destination_selected",
					false
				)
			)
		5:
			return bool(
				completed_events.get(
					"fuel_complete",
					false
				)
			)
		6:
			return bool(
				completed_events.get(
					"load_started",
					false
				)
			)
		7:
			return bool(
				completed_events.get(
					"send_started",
					false
				)
			)
		8:
			return bool(
				completed_events.get(
					"first_departure",
					false
				)
			)
		9:
			return bool(
				completed_events.get(
					"first_landing",
					false
				)
			)
		10:
			return bool(
				completed_events.get(
					"unload_complete",
					false
				)
			)
		11:
			return bool(
				completed_events.get(
					"hangar_returned",
					false
				)
			)
		_:
			return false


func _has_building(building_id: String) -> bool:
	for building_variant in airport_grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get(
				"definition_id",
				""
			)
		) == building_id:
			return true
	return false
