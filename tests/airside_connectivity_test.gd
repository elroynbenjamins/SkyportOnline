extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var starter := grid.get_airside_status()
	if int(starter.get("runways", 0)) != 1:
		_fail("Starter airport should have one runway.")
		return
	if int(starter.get("stands_total", 0)) != 2:
		_fail("Starter airport should have two stands.")
		return
	if int(starter.get("stands_connected", 0)) != 2:
		_fail("Both starter stands should connect to the runway through taxiway.")
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

	plane_a.mark_service_complete()
	plane_b.mark_service_complete()
	runway_dispatcher.request_departure(plane_a, "Test A")
	runway_dispatcher.request_departure(plane_b, "Test B")

	if runway_dispatcher.get_active_count() != 1:
		_fail("Only one aircraft should hold a runway clearance at a time.")
		return
	if runway_dispatcher.get_waiting_count() != 1:
		_fail("Second aircraft should queue for the occupied runway.")
		return

	plane_a.route_completed.emit()
	await process_frame

	if runway_dispatcher.get_active_count() != 1:
		_fail("Second aircraft should receive runway clearance after the first clears.")
		return
	if runway_dispatcher.get_waiting_count() != 0:
		_fail("Departure queue should empty after granting the second clearance.")
		return
	if plane_b.state != "CLEARED":
		_fail("Second aircraft should enter CLEARED state after runway release.")
		return

	var disconnected_position := grid.tile_to_world(Vector2(8, 10))
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

	var connector_position := grid.tile_to_world(Vector2(10, 10))
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

	print("Landscape airside, service-road, fuel capacity, and runway queue tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
