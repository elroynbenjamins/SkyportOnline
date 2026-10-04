extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pico := AircraftPrototype.new()
	var nimbus := AircraftPrototype.new()
	root.add_child(pico)
	root.add_child(nimbus)
	pico.configure_aircraft_type("pico_p8")
	nimbus.configure_aircraft_type("nimbus_n40")
	pico.position = Vector2(500, 320)
	nimbus.position = Vector2(800, 320)

	var service_types := [
		"passenger",
		"cargo",
		"cleaning",
		"catering",
		"fuel"
	]
	var pico_positions: Array[Vector2] = []
	for service_type in service_types:
		var docking := pico.get_service_docking_position(
			service_type,
			service_type
		)
		if docking.distance_to(pico.global_position) < 20.0:
			_fail(
				"%s docking point should sit outside the aircraft center."
				% service_type
			)
			return
		pico_positions.append(docking)

	for a in range(pico_positions.size()):
		for b in range(a + 1, pico_positions.size()):
			if pico_positions[a].distance_to(
				pico_positions[b]
			) < 12.0:
				_fail(
					"Different service types should use distinct docking positions."
				)
				return

	var pico_pax_distance := pico.get_service_docking_position(
		"passenger",
		"passenger_in"
	).distance_to(pico.global_position)
	var nimbus_pax_distance := nimbus.get_service_docking_position(
		"passenger",
		"passenger_in"
	).distance_to(nimbus.global_position)
	if nimbus_pax_distance <= pico_pax_distance:
		_fail(
			"M-class aircraft should widen ground-service docking offsets."
		)
		return

	var before_rotation := pico.get_service_docking_position(
		"catering",
		"catering"
	) - pico.global_position
	pico.rotation = PI * 0.5
	var after_rotation := pico.get_service_docking_position(
		"catering",
		"catering"
	) - pico.global_position
	if absf(before_rotation.length() - after_rotation.length()) > 0.001:
		_fail("Rotating aircraft should preserve docking distance.")
		return
	if before_rotation.distance_to(after_rotation) < 10.0:
		_fail("Docking positions should rotate with the aircraft.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a departure route.")
		return

	var route_info: Dictionary = routes[0]
	pico.rotation = 0.0
	pico.set_departure_route(
		route_info["route"],
		"S",
		int(route_info["stand_uid"]),
		int(route_info["runway_uid"])
	)

	var fuel_station := grid.get_best_service_building(
		"fuel",
		"S"
	)
	var base_route := grid.get_service_route(
		int(fuel_station.get("uid", -1)),
		int(route_info["stand_uid"])
	)
	if base_route.size() < 2:
		_fail("Fuel station should have a route to the starter stand.")
		return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var fuel_route := dispatcher._route_to_aircraft_service_anchor(
		base_route,
		pico,
		"fuel",
		"fuel"
	)
	var passenger_route := dispatcher._route_to_aircraft_service_anchor(
		base_route,
		pico,
		"passenger",
		"passenger_in"
	)

	var expected_fuel := pico.get_service_docking_position(
		"fuel",
		"fuel"
	)
	if fuel_route[fuel_route.size() - 1].distance_to(
		expected_fuel
	) > 0.01:
		_fail("Service route should terminate at the aircraft fuel anchor.")
		return

	if fuel_route[fuel_route.size() - 1].distance_to(
		passenger_route[passenger_route.size() - 1]
	) < 12.0:
		_fail(
			"Passenger and fuel vehicles should not share the same final parking point."
		)
		return

	var passenger_vehicle := GroundServiceVehiclePrototype.new()
	root.add_child(passenger_vehicle)
	passenger_vehicle.set_service_pose_rotation(0.25)
	passenger_vehicle.set_service_connection_target(
		pico.global_position
	)
	if not passenger_vehicle.has_service_connection_target:
		_fail("Service vehicle should retain its aircraft connection target.")
		return

	var fuel_vehicle := FuelTruckPrototype.new()
	root.add_child(fuel_vehicle)
	fuel_vehicle.set_service_connection_target(
		pico.global_position
	)
	if not fuel_vehicle.has_service_connection_target:
		_fail("Fuel truck should retain its aircraft hose target.")
		return

	print(
		"Service docking passed: distinct scalable aircraft anchors, "
		+ "routed parking positions, and visual service connections."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
