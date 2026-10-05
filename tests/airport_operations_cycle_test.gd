extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var departures := grid.get_departure_routes("S")
	var arrivals := grid.get_arrival_routes("S")
	if departures.is_empty() or arrivals.is_empty():
		_fail("Starter airport should expose operational S-class routes.")
		return

	var departure_info: Dictionary = departures[0]
	var stand_uid := int(departure_info.get("stand_uid", -1))
	var runway_uid := int(departure_info.get("runway_uid", -1))
	var arrival_info: Dictionary = {}
	for option in arrivals:
		if (
			int(option.get("stand_uid", -1)) == stand_uid
			and int(option.get("runway_uid", -1)) == runway_uid
		):
			arrival_info = option
			break
	if arrival_info.is_empty():
		_fail("Cycle test needs matching arrival/departure route for one stand.")
		return

	var traffic := TaxiTrafficController.new()
	var ground := GroundServiceDispatcher.new()
	var runway := RunwayDispatcher.new()
	root.add_child(traffic)
	root.add_child(ground)
	root.add_child(runway)
	ground.configure(grid)
	runway.configure(grid)

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.name = "OPS-001"
	plane.configure_aircraft_type("pico_p8")
	plane.configure_taxi_traffic(traffic)
	plane.set_departure_route(
		departure_info["route"],
		"S",
		stand_uid,
		runway_uid
	)
	plane.assign_flight_plan({
		"destination_id": "operations-cycle",
		"city": "Operations Cycle",
		"country": "Test",
		"duration_seconds": 0.25,
		"passengers_required": 1
	})

	ground.request_turnaround(plane, "OPS-001", false)
	var snapshot := ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "SERVICING":
		_fail("Parked outbound aircraft should start in service stage.")
		return
	if not snapshot.has("stage_progress"):
		_fail("Turnaround snapshot should expose live phase progress.")
		return

	var job_id := plane.get_instance_id()
	for key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			plane,
			"OPS-001",
			job_id,
			key,
			false
		)

	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "WAITING_PASSENGERS":
		_fail("Serviced aircraft should wait for passenger approval before loading.")
		return

	if not ground.approve_passenger_loading(plane):
		_fail("Passenger approval should advance the turnaround.")
		return
	for key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			plane,
			"OPS-001",
			job_id,
			key,
			false
		)

	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "PUSHBACK_PREP":
		_fail("Completed loading should request tug pushback.")
		return
	if not traffic.has_reservation(plane):
		_fail("Dispatched pushback should reserve the aircraft movement corridor.")
		return

	ground._on_service_completed(
		plane,
		"OPS-001",
		job_id,
		"pushback",
		false
	)
	if plane.state != "READY_FOR_DEPARTURE":
		_fail("Tow completion should make aircraft ready for runway dispatch.")
		return
	if traffic.has_reservation(plane):
		_fail("Pushback corridor should release when towing completes.")
		return

	runway.request_departure(plane, "OPS-001")
	var departure_guard := 0
	while (
		plane.state not in [
			"CLEARED",
			"ENTERING_RUNWAY",
			"LINE_UP",
			"TAKEOFF_ROLL",
			"CLIMBING",
			"EN_ROUTE"
		]
		and departure_guard < 600
	):
		plane._process(0.05)
		runway._process(0.05)
		departure_guard += 1

	if departure_guard >= 600:
		_fail("Aircraft should taxi to hold-short and receive departure clearance.")
		return

	var airborne_guard := 0
	while plane.state != "EN_ROUTE" and airborne_guard < 600:
		plane._process(0.05)
		runway._process(0.05)
		airborne_guard += 1
	if plane.state != "EN_ROUTE":
		_fail("Cleared departure should complete runway entry, takeoff and climb.")
		return

	plane._process(1.05)
	if plane.state != "HOLDING_FOR_ARRIVAL":
		_fail("Completed flight timer should transition to inbound holding.")
		return

	plane.set_arrival_route(
		arrival_info["route"],
		stand_uid,
		runway_uid
	)
	runway.request_arrival(plane, "OPS-001")
	var arrival_guard := 0
	while plane.state != "APPROACH" and arrival_guard < 600:
		runway._process(0.05)
		arrival_guard += 1
	if plane.state != "APPROACH":
		_fail("Inbound aircraft should clear after runway separation.")
		return

	var parked_guard := 0
	while plane.state != "PARKED" and parked_guard < 1000:
		plane._process(0.05)
		runway._process(0.05)
		parked_guard += 1
	if plane.state != "PARKED":
		_fail("Arrival should land, vacate the runway, taxi in and park.")
		return

	plane.set_departure_route(
		departure_info["route"],
		"S",
		stand_uid,
		runway_uid
	)
	ground.request_turnaround(plane, "OPS-001", true)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "UNLOADING":
		_fail("Returned aircraft should begin with deboarding and baggage unload.")
		return

	for key in ["passenger_out", "cargo_out"]:
		ground._on_service_completed(
			plane,
			"OPS-001",
			job_id,
			key,
			false
		)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "SERVICING":
		_fail("Arrival unload should advance into fuel/clean/catering service.")
		return

	print(
		"Airport operations cycle passed: turnaround, passenger gate, pushback, "
		+ "taxi/hold-short, takeoff, flight, arrival, taxi-in and unload."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
