extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		_fail("Starter airport should expose two small-aircraft stands.")
		return

	for service_type in [
		"passenger",
		"cargo",
		"cleaning",
		"catering"
	]:
		var station := grid.get_best_service_building(
			service_type,
			"S"
		)
		if station.is_empty():
			_fail(
				"Starter airport needs a %s service fleet."
				% service_type
			)
			return
		if String(
			station.get("definition_id", "")
		) != "ground_ops_depot":
			_fail(
				"Starter %s service should come from Ground Operations Depot."
				% service_type
			)
			return

		for route_info in routes.slice(0, 2):
			var service_route := grid.get_service_route(
				int(station.get("uid", -1)),
				int(route_info.get("stand_uid", -1))
			)
			if service_route.size() < 3:
				_fail(
					"Ground Operations Depot should reach both stands for %s."
					% service_type
				)
				return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)
	plane_a.configure_aircraft_type("pico_p8")
	plane_b.configure_aircraft_type("pico_p8")

	var planes: Array[AircraftPrototype] = [plane_a, plane_b]
	var labels := ["Ops A", "Ops B"]
	for index in range(2):
		var plane := planes[index]
		var route_info: Dictionary = routes[index]
		plane.set_departure_route(
			route_info["route"],
			"S",
			int(route_info["stand_uid"]),
			int(route_info["runway_uid"])
		)
		plane.assign_flight_plan({
			"destination_id": "test",
			"city": "Test",
			"country_code": "BE",
			"duration_seconds": 1.0
		})
		dispatcher.request_turnaround(
			plane,
			String(labels[index]),
			false
		)

	if dispatcher.get_active_count() != 3:
		_fail(
			"Two starter turnarounds should activate one fuel, "
			+ "one cleaning, and one catering vehicle."
		)
		return

	var waiting := dispatcher.get_waiting_by_service()
	if int(waiting.get("fuel", 0)) != 1:
		_fail("Second aircraft should queue for the single fuel truck.")
		return
	if int(waiting.get("cleaning", 0)) != 1:
		_fail("Second aircraft should queue for the single cleaning van.")
		return
	if int(waiting.get("catering", 0)) != 1:
		_fail("Second aircraft should queue for the single catering truck.")
		return

	var job_id := plane_a.get_instance_id()
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_id,
		"fuel",
		false
	)
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_id,
		"cleaning",
		false
	)
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_id,
		"catering",
		false
	)

	var snapshot := dispatcher.get_turnaround_snapshot(plane_a)
	if String(snapshot.get("stage", "")) != "WAITING_PASSENGERS":
		_fail(
			"Aircraft should wait for passenger stock before loading starts."
		)
		return
	if plane_a.state != "WAITING_PASSENGERS":
		_fail("Aircraft state should expose the passenger bottleneck.")
		return

	if not dispatcher.approve_passenger_loading(plane_a):
		_fail("Passenger approval should start the loading stage.")
		return

	snapshot = dispatcher.get_turnaround_snapshot(plane_a)
	if String(snapshot.get("stage", "")) != "LOADING":
		_fail("Approved aircraft should enter passenger/cargo loading.")
		return

	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_id,
		"passenger_in",
		false
	)
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_id,
		"cargo_in",
		false
	)

	snapshot = dispatcher.get_turnaround_snapshot(plane_a)
	if String(snapshot.get("stage", "")) != "PUSHBACK_PREP":
		_fail("Completed loading should advance to pushback checks.")
		return

	dispatcher._process(
		float(
			AircraftCatalog.get_profile("pico_p8").get(
				"pushback_seconds",
				0.0
			)
		) + 0.1
	)
	if plane_a.state != "READY_FOR_DEPARTURE":
		_fail(
			"Completed ground handling should release the aircraft for departure."
		)
		return

	var cleaning := BuildingCatalog.get_definition(
		"cleaning_center"
	)
	var baggage := BuildingCatalog.get_definition(
		"baggage_depot"
	)
	var catering := BuildingCatalog.get_definition(
		"catering_kitchen"
	)
	var passenger := BuildingCatalog.get_definition(
		"passenger_service_hub"
	)
	if float(cleaning.get("service_speed", 0.0)) <= 1.0:
		_fail("Cleaning Center should improve cleaning speed.")
		return
	if float(baggage.get("service_speed", 0.0)) <= 1.0:
		_fail("Baggage Depot should improve cargo speed.")
		return
	if float(catering.get("service_speed", 0.0)) <= 1.0:
		_fail("Catering Kitchen should improve catering speed.")
		return
	if float(passenger.get("service_speed", 0.0)) <= 1.0:
		_fail("Passenger Service Hub should improve passenger handling.")
		return

	print(
		"Ground service bottlenecks passed: independent fleets, "
		+ "queues, passenger gate, loading and pushback."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
