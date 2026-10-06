extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var starter_setup := grid.get_starter_construction_snapshot()
	if int(starter_setup.get("starter_width_tiles", 0)) != 16:
		_fail("Starter construction area should be 16 tiles wide.")
		return
	if int(starter_setup.get("starter_height_tiles", 0)) != 16:
		_fail("Starter construction area should be 16 tiles tall.")
		return
	if bool(starter_setup.get("ready_for_first_departure", true)):
		_fail("Player should need to build the initial airport network.")
		return
	if int(grid.get_airside_status().get("runways", 0)) != 0:
		_fail("Starter runway must be player-placed.")
		return

	_build_player_starter_network(grid)

	if not grid.building_labels.is_empty():
		_fail(
			"Connected starter airport should keep detailed building art free of generic floating labels."
		)
		return

	var starter := grid.get_airside_status()
	if int(starter.get("runways", 0)) != 1:
		_fail("Player-built starter network should have one runway.")
		return
	if int(starter.get("stands_total", 0)) != 2:
		_fail("Starter airport should have two stands.")
		return
	if int(starter.get("stands_connected", 0)) != 2:
		_fail("Both starter stands should connect to the runway through taxiway.")
		return
	if int(starter.get("hangars_connected", 0)) != 1:
		_fail("Starter hangar should connect to the stand taxi network.")
		return

	starter_setup = grid.get_starter_construction_snapshot()
	if not bool(starter_setup.get("ready_for_first_departure", false)):
		_fail("Completed starter networks should unlock first aircraft operations.")
		return
	var hangar_route: PackedVector2Array = starter_setup.get(
		"hangar_to_stand_route",
		PackedVector2Array()
	)
	if hangar_route.size() < 3:
		_fail("Hangar should expose a taxi route to the loading stand.")
		return

	var starter_routes := grid.get_departure_routes("S")
	if starter_routes.size() != 2:
		_fail("Starter airport should expose two S-class departure routes.")
		return

	for route_info in starter_routes:
		var route: PackedVector2Array = route_info.get("route", PackedVector2Array())
		if route.size() < 4:
			_fail("Each starter stand should expose a stand-to-runway departure route.")
			return
		if int(route_info.get("runway_uid", -1)) < 0:
			_fail("Departure route should identify its runway.")
			return

	var starter_fuel := grid.get_best_service_building("fuel", "S")
	if starter_fuel.is_empty():
		_fail("Starter airport should expose a compatible fuel station.")
		return
	if String(starter_fuel.get("definition_id", "")) != "basic_fuel":
		_fail("Starter service assignment should use the basic fuel station.")
		return
	if absf(float(starter_fuel.get("service_speed", 0.0)) - 1.0) > 0.001:
		_fail("Basic fuel station should use x1.0 service speed.")
		return

	for route_info in starter_routes:
		var service_route := grid.get_service_route(
			int(starter_fuel.get("uid", -1)),
			int(route_info.get("stand_uid", -1))
		)
		if service_route.size() < 3:
			_fail("Fuel truck should have a service-road route to each starter stand.")
			return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)

	plane_a.set_departure_route(
		starter_routes[0]["route"],
		"S",
		int(starter_routes[0]["stand_uid"]),
		int(starter_routes[0]["runway_uid"])
	)
	plane_b.set_departure_route(
		starter_routes[1]["route"],
		"S",
		int(starter_routes[1]["stand_uid"]),
		int(starter_routes[1]["runway_uid"])
	)

	dispatcher.request_fuel(plane_a, "Test A")
	dispatcher.request_fuel(plane_b, "Test B")

	if dispatcher.get_active_count() != 1:
		_fail("Basic fuel station should dispatch only one active truck.")
		return
	if dispatcher.get_waiting_count() != 1:
		_fail("Second aircraft should wait when the only fuel truck is busy.")
		return

	var runway_dispatcher := RunwayDispatcher.new()
	root.add_child(runway_dispatcher)

	plane_a.configure_aircraft_type("pico_p8")
	plane_b.configure_aircraft_type("swift_s14")
	plane_a.assign_flight_plan({
		"destination_id": "test-a",
		"city": "Test A",
		"duration_seconds": 1.0
	})
	plane_b.assign_flight_plan({
		"destination_id": "test-b",
		"city": "Test B",
		"duration_seconds": 1.0
	})
	plane_a.mark_service_complete()
	plane_b.mark_service_complete()
	runway_dispatcher.request_departure(plane_a, "Test A")
	runway_dispatcher.request_departure(plane_b, "Test B")

	if runway_dispatcher.get_active_count() != 0:
		_fail("Taxi-to-hold aircraft should not reserve the runway yet.")
		return
	if runway_dispatcher.get_waiting_count() != 0:
		_fail("Departure runway queue should begin only at hold short.")
		return
	if runway_dispatcher.get_taxiing_to_hold_count() != 2:
		_fail("Both departures should initially taxi toward hold short.")
		return

	plane_a.hold_short_reached.emit()
	if runway_dispatcher.get_active_count() != 1:
		_fail("First aircraft at hold short should receive free runway clearance.")
		return

	plane_b.hold_short_reached.emit()
	if runway_dispatcher.get_waiting_count() != 1:
		_fail("Second hold-short aircraft should queue for the occupied runway.")
		return

	plane_a.runway_cleared.emit()
	await process_frame

	if runway_dispatcher.get_active_count() != 0:
		_fail("Runway should remain idle during departure separation.")
		return
	if runway_dispatcher.get_waiting_count() != 1:
		_fail("Second departure should remain queued during separation.")
		return
	if runway_dispatcher.get_separation_remaining(
		int(starter_routes[0]["runway_uid"])
	) <= 0.0:
		_fail("Departure-to-departure movement should enforce separation.")
		return

	runway_dispatcher._process(
		RunwayPacingRules.DEPARTURE_TO_DEPARTURE + 0.1
	)
	if runway_dispatcher.get_active_count() != 1:
		_fail("Second aircraft should receive clearance after separation.")
		return
	if runway_dispatcher.get_waiting_count() != 0:
		_fail("Departure queue should empty after paced clearance.")
		return
	if plane_b.state != "CLEARED":
		_fail("Second aircraft should enter CLEARED after paced release.")
		return


	var arrival_routes: Array[Dictionary] = grid.get_arrival_routes("S")
	if arrival_routes.size() != 2:
		_fail("Starter airport should expose two S-class arrival routes.")
		return

	for arrival_info in arrival_routes:
		var arrival_route: PackedVector2Array = arrival_info.get(
			"route",
			PackedVector2Array()
		)
		if arrival_route.size() < 4:
			_fail("Arrival route should include runway, taxiway, and stand.")
			return
		if int(arrival_info.get("runway_uid", -1)) < 0:
			_fail("Arrival route should identify its runway.")
			return

	var arrival_a := AircraftPrototype.new()
	var arrival_b := AircraftPrototype.new()
	root.add_child(arrival_a)
	root.add_child(arrival_b)

	arrival_a.set_arrival_route(
		arrival_routes[0]["route"],
		int(arrival_routes[0]["stand_uid"]),
		int(arrival_routes[0]["runway_uid"])
	)
	arrival_b.set_arrival_route(
		arrival_routes[1]["route"],
		int(arrival_routes[1]["stand_uid"]),
		int(arrival_routes[1]["runway_uid"])
	)

	var arrival_runway := RunwayDispatcher.new()
	root.add_child(arrival_runway)
	arrival_runway.request_arrival(arrival_a, "Arrival A")
	arrival_runway.request_arrival(arrival_b, "Arrival B")

	if arrival_runway.get_active_count() != 1:
		_fail("Only one arrival should occupy the runway at a time.")
		return
	if arrival_runway.get_waiting_count() != 1:
		_fail("Second arrival should wait while runway is occupied.")
		return
	if arrival_a.state != "APPROACH":
		_fail("Cleared arrival should enter APPROACH state.")
		return

	arrival_a.runway_cleared.emit()
	await process_frame

	if arrival_runway.get_waiting_count() != 1:
		_fail("Second arrival should remain queued during landing separation.")
		return
	if arrival_b.state == "APPROACH":
		_fail("Second arrival should not receive instant back-to-back clearance.")
		return

	arrival_runway._process(
		RunwayPacingRules.ARRIVAL_TO_ARRIVAL + 0.1
	)
	if arrival_runway.get_waiting_count() != 0:
		_fail("Second arrival should clear after landing separation.")
		return
	if arrival_b.state != "APPROACH":
		_fail("Second arrival should enter APPROACH after paced clearance.")
		return


	var lifecycle_plane := AircraftPrototype.new()
	root.add_child(lifecycle_plane)
	lifecycle_plane.configure_aircraft_type("pico_p8")
	lifecycle_plane.set_departure_route(
		starter_routes[0]["route"],
		"S",
		int(starter_routes[0]["stand_uid"]),
		int(starter_routes[0]["runway_uid"])
	)
	lifecycle_plane.assign_flight_plan({
		"destination_id": "test-flight",
		"city": "Test Flight",
		"duration_seconds": 0.5
	})
	lifecycle_plane.mark_service_complete()
	lifecycle_plane.begin_departure_after_clearance()

	for _step in range(160):
		lifecycle_plane._process(0.2)
		if lifecycle_plane.state == "EN_ROUTE":
			break

	if lifecycle_plane.state != "EN_ROUTE":
		_fail("Aircraft should complete taxi, lineup, takeoff roll, and climb.")
		return
	if lifecycle_plane.visible:
		_fail("En-route aircraft should leave the local airport view.")
		return

	lifecycle_plane.set_arrival_route(
		arrival_routes[0]["route"],
		int(arrival_routes[0]["stand_uid"]),
		int(arrival_routes[0]["runway_uid"])
	)
	var assigned_duration := lifecycle_plane.get_flight_remaining_seconds()
	lifecycle_plane._process(assigned_duration + 0.1)
	if lifecycle_plane.state != "HOLDING_FOR_ARRIVAL":
		_fail("Finished assigned flight should request an arrival.")
		return

	lifecycle_plane.begin_arrival_after_clearance()
	for _step in range(180):
		lifecycle_plane._process(0.2)
		if lifecycle_plane.state == "PARKED":
			break

	if lifecycle_plane.state != "PARKED":
		_fail("Aircraft should complete approach, landing, taxi-in, and parking.")
		return
	if not lifecycle_plane.visible:
		_fail("Parked aircraft should be visible at the airport.")
		return

	grid.select_parcel("east")
	grid.purchase_selected()

	var disconnected_position := grid.tile_to_world(Vector2(15, 10))
	var preview := grid.set_build_preview("small_stand", disconnected_position, 0)
	if not bool(preview.get("valid", false)):
		_fail("Disconnected stand test placement should be buildable.")
		return
	if String(preview.get("warning", "")).is_empty():
		_fail("Disconnected stand preview should show a taxiway warning.")
		return

	grid.confirm_build_preview()
	var disconnected := grid.get_airside_status()
	if int(disconnected.get("stands_total", 0)) != 3:
		_fail("Expected three stands after test placement.")
		return
	if int(disconnected.get("stands_connected", 0)) != 2:
		_fail("Third stand should remain disconnected before adding taxiway.")
		return

	var connector_position := grid.tile_to_world(Vector2(14, 10))
	var connector_preview := grid.set_build_preview("taxiway", connector_position, 0)
	if not bool(connector_preview.get("valid", false)):
		_fail("Connector taxiway test placement should be valid.")
		return

	grid.confirm_build_preview()
	var connected := grid.get_airside_status()
	if int(connected.get("stands_connected", 0)) != 3:
		_fail("All three stands should connect after extending the taxiway.")
		return

	var rapid_grid := AirportGrid.new()
	root.add_child(rapid_grid)
	await process_frame
	rapid_grid.select_parcel("east")
	rapid_grid.purchase_selected()

	var rapid_position := rapid_grid.tile_to_world(Vector2(16, 13))
	var rapid_preview := rapid_grid.set_build_preview("rapid_small_fuel", rapid_position, 0)
	if not bool(rapid_preview.get("valid", false)):
		_fail("Rapid fuel station test placement should be valid on expanded land.")
		return
	rapid_grid.confirm_build_preview()

	var preferred_fuel := rapid_grid.get_best_service_building("fuel", "S")
	if String(preferred_fuel.get("definition_id", "")) != "rapid_small_fuel":
		_fail("Service assignment should prefer the faster compatible fuel station.")
		return
	if absf(float(preferred_fuel.get("service_speed", 0.0)) - 1.6) > 0.001:
		_fail("Rapid small fuel station should use x1.6 service speed.")
		return

	var rapid_routes := rapid_grid.get_departure_routes("S")
	if rapid_routes.size() < 2:
		_fail("Rapid-fuel test airport should still expose two departure routes.")
		return

	for route_info in rapid_routes.slice(0, 2):
		var service_route := rapid_grid.get_service_route(
			int(preferred_fuel.get("uid", -1)),
			int(route_info.get("stand_uid", -1))
		)
		if service_route.size() < 3:
			_fail("Rapid fuel station should reach both starter stands by service road.")
			return

	var rapid_dispatcher := GroundServiceDispatcher.new()
	root.add_child(rapid_dispatcher)
	rapid_dispatcher.configure(rapid_grid)

	var rapid_plane_a := AircraftPrototype.new()
	var rapid_plane_b := AircraftPrototype.new()
	root.add_child(rapid_plane_a)
	root.add_child(rapid_plane_b)

	rapid_plane_a.set_departure_route(
		rapid_routes[0]["route"],
		"S",
		int(rapid_routes[0]["stand_uid"]),
		int(rapid_routes[0]["runway_uid"])
	)
	rapid_plane_b.set_departure_route(
		rapid_routes[1]["route"],
		"S",
		int(rapid_routes[1]["stand_uid"]),
		int(rapid_routes[1]["runway_uid"])
	)

	rapid_dispatcher.request_fuel(rapid_plane_a, "Rapid A")
	rapid_dispatcher.request_fuel(rapid_plane_b, "Rapid B")

	if rapid_dispatcher.get_active_count() != 2:
		_fail("Two-truck rapid fuel station should service two aircraft in parallel.")
		return
	if rapid_dispatcher.get_waiting_count() != 0:
		_fail("No aircraft should queue when rapid fuel has two free trucks.")
		return

	print("Landscape airport operations and full aircraft lifecycle tests passed.")
	quit(0)


func _build_player_starter_network(grid: AirportGrid) -> void:
	grid._place_building_internal(
		"short_runway",
		Vector2i(4, 1),
		0
	)

	var taxi_cells: Array[Vector2i] = [
		Vector2i(4, 3),
		Vector2i(5, 3),
		Vector2i(6, 3),
		Vector2i(7, 3),
		Vector2i(8, 3),
		Vector2i(9, 3),
		Vector2i(10, 3),
		Vector2i(4, 4),
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(6, 4),
		Vector2i(6, 5),
		Vector2i(10, 4),
		Vector2i(10, 5)
	]
	for cell in taxi_cells:
		grid._place_building_internal(
			"taxiway",
			cell,
			0
		)

	var service_cells: Array[Vector2i] = [
		Vector2i(12, 11),
		Vector2i(12, 10),
		Vector2i(12, 9),
		Vector2i(12, 8),
		Vector2i(12, 7),
		Vector2i(11, 8),
		Vector2i(10, 8),
		Vector2i(9, 8),
		Vector2i(8, 8),
		Vector2i(7, 8)
	]
	for cell in service_cells:
		grid._place_building_internal(
			"service_road",
			cell,
			0
		)

	grid._rebuild_occupied_cells()
	grid._recalculate_airside_network()
	grid._refresh_building_labels()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
