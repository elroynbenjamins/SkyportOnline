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

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)
	plane_a.set_departure_route(starter_routes[0]["route"], "S")
	plane_b.set_departure_route(starter_routes[1]["route"], "S")
	dispatcher.request_fuel(plane_a, "Test A")
	dispatcher.request_fuel(plane_b, "Test B")

	if dispatcher.get_active_count() != 1:
		_fail("Basic fuel station should dispatch only one active truck.")
		return
	if dispatcher.get_waiting_count() != 1:
		_fail("Second aircraft should wait when the only fuel truck is busy.")
		return

	dispatcher.queue_free()
	plane_a.queue_free()
	plane_b.queue_free()

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

	var rapid_position := grid.tile_to_world(Vector2(11, 13))
	var rapid_preview := grid.set_build_preview("rapid_small_fuel", rapid_position, 0)
	if not bool(rapid_preview.get("valid", false)):
		_fail("Rapid fuel station test placement should be valid.")
		return
	grid.confirm_build_preview()

	var preferred_fuel := grid.get_best_service_building("fuel", "S")
	if String(preferred_fuel.get("definition_id", "")) != "rapid_small_fuel":
		_fail("Service assignment should prefer the faster compatible fuel station.")
		return
	if absf(float(preferred_fuel.get("service_speed", 0.0)) - 1.6) > 0.001:
		_fail("Rapid small fuel station should use x1.6 service speed.")
		return

	print("Airside connectivity and service selection test passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
