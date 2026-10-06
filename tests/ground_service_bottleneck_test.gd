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

	# Outbound aircraft now LOAD before fuel/cleaning/catering service.
	for plane in planes:
		var waiting_snapshot := dispatcher.get_turnaround_snapshot(plane)
		if String(waiting_snapshot.get("stage", "")) != "WAITING_PASSENGERS":
			_fail("Outbound turnaround should wait for LOAD before service.")
			return

	var ops_station := grid.get_best_service_building(
		"passenger",
		"S"
	)
	var ops_uid := int(ops_station.get("uid", -1))
	if ops_uid < 0:
		_fail("Starter Ground Operations Depot should be available.")
		return

	# Load aircraft A first, then release its passenger/cargo vehicles.
	if not dispatcher.approve_passenger_loading(plane_a):
		_fail("First outbound aircraft should accept passenger loading.")
		return
	var job_a := plane_a.get_instance_id()
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_a,
		"passenger_in",
		false
	)
	dispatcher._on_vehicle_returned(
		ops_uid,
		"passenger"
	)
	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_a,
		"cargo_in",
		false
	)
	dispatcher._on_vehicle_returned(
		ops_uid,
		"cargo"
	)

	var snapshot_a := dispatcher.get_turnaround_snapshot(plane_a)
	if String(snapshot_a.get("stage", "")) != "SERVICING":
		_fail("Loaded outbound aircraft should enter stand service next.")
		return
	var status_a: Dictionary = snapshot_a.get(
		"service_status",
		{}
	)
	for service_key in ["fuel", "cleaning", "catering"]:
		if String(
			(status_a.get(service_key, {}) as Dictionary).get(
				"state",
				""
			)
		) != "en_route":
			_fail(
				"First aircraft should dispatch %s service after loading."
				% service_key
			)
			return

	# Aircraft B can load using the passenger/cargo fleets while A is being
	# serviced. Once B reaches service, the single starter fuel/clean/catering
	# vehicles should expose the intended bottleneck queue.
	if not dispatcher.approve_passenger_loading(plane_b):
		_fail("Second outbound aircraft should accept passenger loading.")
		return
	var job_b := plane_b.get_instance_id()
	dispatcher._on_service_completed(
		plane_b,
		"Ops B",
		job_b,
		"passenger_in",
		false
	)
	dispatcher._on_vehicle_returned(
		ops_uid,
		"passenger"
	)
	dispatcher._on_service_completed(
		plane_b,
		"Ops B",
		job_b,
		"cargo_in",
		false
	)
	dispatcher._on_vehicle_returned(
		ops_uid,
		"cargo"
	)

	var snapshot_b := dispatcher.get_turnaround_snapshot(plane_b)
	if String(snapshot_b.get("stage", "")) != "SERVICING":
		_fail("Second loaded aircraft should enter stand service.")
		return
	var status_b: Dictionary = snapshot_b.get(
		"service_status",
		{}
	)
	for service_key in ["fuel", "cleaning", "catering"]:
		if String(
			(status_b.get(service_key, {}) as Dictionary).get(
				"state",
				""
			)
		) != "queued":
			_fail(
				"Second aircraft should queue for starter %s capacity."
				% service_key
			)
			return

	var waiting := dispatcher.get_waiting_by_service()
	for service_type in ["fuel", "cleaning", "catering"]:
		if int(waiting.get(service_type, 0)) != 1:
			_fail(
				"Second aircraft should queue for the single %s vehicle."
				% service_type
			)
			return

	# Complete A's service stage. Outbound load has already happened, so the
	# next stage is pushback rather than the old WAITING_PASSENGERS step.
	for service_key in ["fuel", "cleaning", "catering"]:
		dispatcher._on_service_completed(
			plane_a,
			"Ops A",
			job_a,
			service_key,
			false
		)
		dispatcher._on_vehicle_returned(
			int(
				grid.get_best_service_building(
					service_key if service_key != "catering" else "catering",
					"S"
				).get("uid", -1)
			),
			service_key
		)

	var snapshot := dispatcher.get_turnaround_snapshot(plane_a)
	if String(snapshot.get("stage", "")) != "PUSHBACK_PREP":
		_fail("Completed outbound service should advance directly to pushback.")
		return

	var pushback_status: Dictionary = (
		snapshot.get("service_status", {}) as Dictionary
	)
	if String(
		(pushback_status.get("pushback", {}) as Dictionary).get(
			"state",
			""
		)
	) != "en_route":
		_fail("Available starter tug should dispatch for pushback.")
		return

	dispatcher._process(
		float(
			AircraftCatalog.get_profile("pico_p8").get(
				"pushback_seconds",
				0.0
			)
		) + 0.1
	)
	if plane_a.state == "READY_FOR_DEPARTURE":
		_fail(
			"Pushback should not finish from dispatcher time alone."
		)
		return

	dispatcher._on_service_completed(
		plane_a,
		"Ops A",
		job_a,
		"pushback",
		false
	)
	if plane_a.state != "READY_FOR_DEPARTURE":
		_fail(
			"Completed tow service should release the aircraft for departure."
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
