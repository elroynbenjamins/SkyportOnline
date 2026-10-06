extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var area := grid.get_starter_build_area_snapshot()
	if (
		int(area.get("width_tiles", 0)) != 16
		or int(area.get("height_tiles", 0)) != 16
		or int(area.get("tile_count", 0)) != 256
	):
		_fail("Starter airfield should expose a 16x16 / 256-tile build area.")
		return

	var airside := grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Reference starter layout should contain one runway.")
		return
	if int(airside.get("hangars_connected", 0)) != 1:
		_fail("Reference starter hangar should connect to the taxi network.")
		return

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Reference starter layout should expose an S-class departure route.")
		return

	var stand_uid := int(routes[0].get("stand_uid", -1))
	var flow := grid.get_departure_ground_flow_for_stand(stand_uid, "S")
	var hangar_route: PackedVector2Array = flow.get(
		"hangar_to_stand_route",
		PackedVector2Array()
	)
	var fuel_route: PackedVector2Array = flow.get(
		"fuel_service_route",
		PackedVector2Array()
	)
	if hangar_route.size() < 3:
		_fail("Departure flow should physically taxi Hangar -> Stand.")
		return
	if fuel_route.size() < 3:
		_fail("Fuel truck should physically reach the stand by service road.")
		return
	if String(flow.get("fuel_mode", "")) != "truck_to_stand":
		_fail("Early-game fueling should happen at the stand by truck.")
		return

	var stages: Array = flow.get("stages", [])
	var expected_stages := [
		"HANGAR",
		"TAXI_TO_STAND",
		"LOAD",
		"SERVICE_AT_STAND",
		"TAXI_TO_RUNWAY",
		"TAKEOFF"
	]
	if stages != expected_stages:
		_fail("Departure flow should use Hangar -> Load -> Service -> Runway.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.configure_handling_mode(true, false)
	plane.assign_flight_plan({
		"destination_id": "starter-test",
		"city": "Starter Test",
		"duration_seconds": 60.0
	})
	plane.set_departure_route(
		routes[0].get("route", PackedVector2Array()),
		"S",
		stand_uid,
		int(routes[0].get("runway_uid", -1))
	)
	if not plane.stage_for_hangar_departure(hangar_route, stand_uid):
		_fail("Aircraft should stage inside the connected starter hangar.")
		return
	if plane.state != "WAITING_HANGAR_TAXI":
		_fail("Staged hangar aircraft should wait for player TAXI input.")
		return
	if plane.get_handling_action() != "TAXI":
		_fail("Hangar aircraft should expose a Skyrama-style TAXI bubble.")
		return
	if not plane.continue_manual_hangar_taxi():
		_fail("TAXI input should start physical hangar-to-stand movement.")
		return

	for _step in range(360):
		plane._process(0.2)
		if plane.state == "PARKED":
			break
	if plane.state != "PARKED":
		_fail("Hangar aircraft should physically arrive at its loading stand.")
		return

	var services := GroundServiceDispatcher.new()
	root.add_child(services)
	services.configure(grid)
	services.request_turnaround(plane, "Starter", false, true)
	var turnaround := services.get_turnaround_snapshot(plane)
	if String(turnaround.get("stage", "")) != "WAITING_PASSENGERS":
		_fail("Outbound aircraft should LOAD before stand service/fueling.")
		return
	if plane.get_handling_action() != "LOAD":
		_fail("Outbound aircraft should expose LOAD after hangar taxi.")
		return
	if not services.approve_passenger_loading(plane):
		_fail("Approved LOAD should begin the loading stage.")
		return
	turnaround = services.get_turnaround_snapshot(plane)
	if String(turnaround.get("stage", "")) != "LOADING":
		_fail("Outbound turnaround should enter LOADING before SERVICING.")
		return

	var new_player_grid := AirportGrid.new()
	root.add_child(new_player_grid)
	await process_frame
	var shell := new_player_grid.prepare_new_player_airfield()
	var removed: Dictionary = shell.get("removed", {})
	if int(removed.get("runway", 0)) != 1:
		_fail("New player should place the starter runway themselves.")
		return
	if int(removed.get("taxiway", 0)) != 15:
		_fail("New player should place the taxi network themselves.")
		return
	if int(removed.get("stand", 0)) != 2:
		_fail("New player should place aircraft stands themselves.")
		return
	if int(removed.get("service_road", 0)) != 12:
		_fail("New player should place service roads themselves.")
		return

	var shell_airside := new_player_grid.get_airside_status()
	if int(shell_airside.get("runways", -1)) != 0:
		_fail("Fresh player shell should begin without a prebuilt runway.")
		return
	if int(shell_airside.get("stands_total", -1)) != 0:
		_fail("Fresh player shell should begin without prebuilt stands.")
		return
	if int(shell_airside.get("hangars_total", 0)) != 1:
		_fail("Starter shell should retain the owned hangar building.")
		return
	if int(shell_airside.get("hangars_connected", -1)) != 0:
		_fail("Hangar should require the player to connect a taxiway.")
		return

	for starter_id in ["north_west", "north", "west", "home"]:
		if not new_player_grid.export_owned_parcels().has(starter_id):
			_fail("Fresh player should own the full 16x16 starter land.")
			return

	print(
		"STARTER_AIRFIELD_FLOW_OK area=16x16 player_builds_network=true "
		+ "flow=hangar>stand>load>service>runway fuel=truck_to_stand"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
