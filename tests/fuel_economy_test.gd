extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var fuel_station := grid.get_best_service_building("fuel", "S")
	if fuel_station.is_empty():
		_fail("Starter airport should contain a small-aircraft fuel station.")
		return
	if int(fuel_station.get("fuel_storage", 0)) != 240:
		_fail("Basic Fuel Station should provide 240 fuel storage.")
		return

	var economy := FuelEconomy.new()
	root.add_child(economy)
	economy.configure(grid, FuelRules.DEFAULT_STARTING_FUEL)
	if economy.get_capacity() != 240:
		_fail("Starter fuel capacity should be 240.")
		return
	if economy.get_fuel() != FuelRules.DEFAULT_STARTING_FUEL:
		_fail("New airports should start with the configured fuel reserve.")
		return
	if absf(economy.get_delivery_per_minute() - 1.0) > 0.001:
		_fail("Basic Fuel Station should passively deliver 1 fuel/min.")
		return

	var pico := AircraftCatalog.get_profile("pico_p8")
	var brussels := DestinationCatalog.get_destination("brussels")
	var pico_fuel := FuelRules.required_for_route(
		pico,
		float(brussels.get("distance_km", 0.0))
	)
	if pico_fuel < 8 or pico_fuel > 15:
		_fail("Short Pico route should use roughly 8-15 fuel.")
		return

	var nimbus := AircraftCatalog.get_profile("nimbus_n40")
	var medium_fuel := FuelRules.required_for_route(nimbus, 1000.0)
	if medium_fuel < 30 or medium_fuel > 40:
		_fail("A 1000 km medium-aircraft route should use roughly 30-40 fuel.")
		return

	if not economy.spend_fuel(pico_fuel):
		_fail("Fuel stock should be spendable by turnaround service.")
		return
	var after_spend := economy.get_fuel()
	economy._process(60.0)
	if economy.get_fuel() != after_spend + 1:
		_fail("One minute online should deliver one fuel at the starter depot.")
		return

	var added := economy.add_fuel(FuelRules.EMERGENCY_ORDER_AMOUNT)
	if added <= 0:
		_fail("Emergency fuel orders should refill available storage.")
		return

	_build_player_starter_network(grid)

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a departure route for fuel service.")
		return
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	var route_info: Dictionary = routes[0]
	plane.set_departure_route(
		route_info["route"],
		"S",
		int(route_info["stand_uid"]),
		int(route_info["runway_uid"])
	)
	plane.assign_flight_plan(FlightRules.create_flight_plan(pico, brussels))

	economy.set_fuel(0)
	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	dispatcher.configure_fuel_economy(economy)
	dispatcher.request_turnaround(plane, "Fuel Test", false)

	var blocked := dispatcher.get_turnaround_snapshot(plane)
	var blocked_status: Dictionary = blocked.get("service_status", {})
	if String(
		(blocked_status.get("fuel", {}) as Dictionary).get("state", "")
	) != "queued":
		_fail("Fuel truck should remain queued when airport fuel stock is empty.")
		return

	economy.add_fuel(pico_fuel)
	dispatcher.refresh_after_layout_change()
	var released := dispatcher.get_turnaround_snapshot(plane)
	var released_status: Dictionary = released.get("service_status", {})
	if String(
		(released_status.get("fuel", {}) as Dictionary).get("state", "")
	) != "en_route":
		_fail("Fuel truck should dispatch as soon as enough stock is available.")
		return
	if economy.get_fuel() != 0:
		_fail("Dispatching the fuel truck should reserve the route fuel immediately.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Fuel Test",
		"FUL",
		"NL"
	)
	if profile.is_empty():
		_fail("Fuel persistence test profile should be created.")
		return
	profile = ProfileStore.save_fuel_balance(73)
	if int(profile.get("fuel_balance", -1)) != 73:
		_fail("Fuel balance should persist.")
		return
	var reloaded := ProfileStore.load_profile()
	if int(reloaded.get("fuel_balance", -1)) != 73:
		_fail("Fuel balance should survive profile reload.")
		return

	var plan := FlightRules.create_flight_plan(pico, brussels)
	if int(plan.get("fuel_required", 0)) != pico_fuel:
		_fail("Flight plans should expose the route fuel requirement.")
		return

	_cleanup_profile()
	print(
		"Fuel economy passed: route use, storage, passive delivery, "
		+ "emergency refill, flight-plan exposure and persistence."
	)
	quit(0)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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
	_cleanup_profile()
	push_error(message)
	quit(1)
