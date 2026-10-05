extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var traffic := TaxiTrafficController.new()
	var ground := GroundServiceDispatcher.new()
	var runway := RunwayDispatcher.new()
	root.add_child(traffic)
	root.add_child(ground)
	root.add_child(runway)
	ground.configure(grid)
	runway.configure(grid)

	var contact := SocialContactCatalog.get_contact(
		"system_brussels"
	)
	var request := SocialFlightRules.create_visit_request(
		contact,
		1
	)
	if request.is_empty():
		_fail("Social visitor request should be creatable.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.name = "FR-BRU"
	plane.configure_aircraft_type(
		String(request.get("aircraft_type_id", "pico_p8"))
	)
	plane.configure_taxi_traffic(traffic)
	plane.configure_social_visit(request)
	plane.assign_flight_plan(
		SocialFlightRules.create_social_flight_plan(request)
	)
	plane.prepare_social_inbound()

	if not plane.is_social_visitor():
		_fail("Visitor aircraft should retain social metadata.")
		return
	if plane.state != "HOLDING_FOR_ARRIVAL":
		_fail("Social visitor should begin inbound, not parked on the host airport.")
		return

	var arrivals := grid.get_arrival_routes("S")
	if arrivals.is_empty():
		_fail("Starter airport should expose an S arrival route.")
		return
	var arrival: Dictionary = arrivals[0]
	var stand_uid := int(arrival.get("stand_uid", -1))
	var runway_uid := int(arrival.get("runway_uid", -1))
	plane.set_arrival_route(
		arrival["route"],
		stand_uid,
		runway_uid
	)
	runway.request_arrival(plane, "FR-BRU")

	var arrival_guard := 0
	while plane.state != "PARKED" and arrival_guard < 1200:
		plane._process(0.05)
		runway._process(0.05)
		arrival_guard += 1
	if plane.state != "PARKED":
		_fail("Social visitor should land, vacate and taxi to a real stand.")
		return

	var departure := grid.get_departure_route_for_stand(
		stand_uid,
		"S"
	)
	if departure.is_empty():
		_fail("Visitor stand should expose a departure route.")
		return
	plane.set_departure_route(
		departure["route"],
		"S",
		stand_uid,
		int(departure.get("runway_uid", -1))
	)

	ground.request_turnaround(
		plane,
		"FR-BRU",
		true
	)
	var snapshot := ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "UNLOADING":
		_fail("Visiting aircraft should start with unload service.")
		return

	var job_id := plane.get_instance_id()
	for key in ["passenger_out", "cargo_out"]:
		ground._on_service_completed(
			plane,
			"FR-BRU",
			job_id,
			key,
			false
		)

	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "SERVICING":
		_fail("Visitor unload should advance to ground servicing.")
		return

	for key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			plane,
			"FR-BRU",
			job_id,
			key,
			false
		)

	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "LOADING":
		_fail(
			"Social visitor must load directly after service without a host passenger-stock gate."
		)
		return
	if plane.state == "WAITING_PASSENGERS":
		_fail("Social visitor must never consume or wait for host passengers.")
		return

	for key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			plane,
			"FR-BRU",
			job_id,
			key,
			false
		)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "PUSHBACK_PREP":
		_fail("Visitor loading should advance to real tug pushback.")
		return

	ground._on_service_completed(
		plane,
		"FR-BRU",
		job_id,
		"pushback",
		false
	)
	if plane.state != "READY_FOR_DEPARTURE":
		_fail("Completed visitor turnaround should become departure-ready.")
		return

	runway.request_departure(plane, "FR-BRU")
	var departure_guard := 0
	while plane.state != "EN_ROUTE" and departure_guard < 1400:
		plane._process(0.05)
		runway._process(0.05)
		departure_guard += 1
	if plane.state != "EN_ROUTE":
		_fail("Social visitor should taxi, hold-short, take off and depart normally.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var reward := SocialFlightRules.create_host_reward(
		plane.get_aircraft_profile(),
		request,
		rng
	)
	if String(reward.get("country_id", "")) != "BE":
		_fail("Host social reward should source imports from the visitor country.")
		return
	if (reward.get("resource_rolls", []) as Array).size() != 3:
		_fail("Completed visitor should roll Belgium's three resources.")
		return

	print(
		"Social aircraft cycle passed: real arrival, stand turnaround, "
		+ "host-passenger independence, pushback, runway departure and imports."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
