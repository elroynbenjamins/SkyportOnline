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

	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.name = "Pico Golden Path"
	plane.configure_aircraft_type("pico_p8")
	plane.configure_taxi_traffic(traffic)
	plane.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0,
		"passengers_boarded": 8
	})

	var state_history: Array[String] = []
	plane.state_changed.connect(
		func(next_state: String) -> void:
			state_history.append(next_state)
	)

	var profile := plane.get_flight_presentation_snapshot()
	if float(profile.get("approach_spawn_distance", 0.0)) < 500.0:
		_fail("Pico P8 should use a long visible final approach.")
		return
	if float(profile.get("climb_out_distance", 0.0)) < 500.0:
		_fail("Pico P8 should remain visible through a real climb-out.")
		return
	if float(profile.get("approach_speed", 0.0)) <= float(
		profile.get("landing_speed", 0.0)
	):
		_fail("Pico final approach should ease down toward landing speed.")
		return

	var arrivals := grid.get_arrival_routes("S")
	if arrivals.is_empty():
		_fail("Starter airport should expose an S arrival route.")
		return
	var arrival: Dictionary = arrivals[0]
	var stand_uid := int(arrival.get("stand_uid", -1))
	var runway_uid := int(arrival.get("runway_uid", -1))
	plane.set_arrival_route(
		arrival.get("route", PackedVector2Array()),
		stand_uid,
		runway_uid
	)
	plane.visible = false
	plane._set_state("HOLDING_FOR_ARRIVAL")
	runway.request_arrival(
		plane,
		"Pico P8"
	)

	if plane.state != "APPROACH" or not plane.visible:
		_fail("Arrival clearance should make the Pico visibly fly into the airport.")
		return

	var threshold: Vector2 = plane.arrival_route[0]
	var initial_distance := plane.position.distance_to(
		threshold
	)
	if initial_distance < 500.0:
		_fail("Pico should spawn well outside the runway threshold for approach.")
		return

	var arrival_visual := plane.get_flight_presentation_snapshot()
	var initial_lift := float(
		arrival_visual.get("visual_lift", 0.0)
	)
	if initial_lift < 65.0:
		_fail("Inbound Pico should visibly read as airborne above its shadow.")
		return
	var initial_shadow := float(
		arrival_visual.get("airborne_factor", 0.0)
	)
	if initial_shadow < 0.95:
		_fail("Inbound Pico should begin near maximum approach altitude.")
		return

	plane._process(0.65)
	var closer_distance := plane.position.distance_to(
		threshold
	)
	var closer_lift := plane.get_airborne_visual_lift()
	if closer_distance >= initial_distance:
		_fail("Approach should visibly advance toward the runway.")
		return
	if closer_lift >= initial_lift:
		_fail("Pico should descend as it advances on final approach.")
		return

	var arrival_guard := 0
	while plane.state != "PARKED" and arrival_guard < 1600:
		plane._process(0.05)
		runway._process(0.05)
		arrival_guard += 1
	if plane.state != "PARKED":
		_fail("Pico should touch down, roll out, taxi in and stop at its stand.")
		return
	if plane.position.distance_to(
		plane.arrival_route[plane.arrival_route.size() - 1]
	) > 0.1:
		_fail("Pico should finish arrival exactly on the assigned stand.")
		return
	if plane.get_airborne_visual_lift() > 0.01:
		_fail("Parked Pico should return fully to ground level.")
		return

	var departure := grid.get_departure_route_for_stand(
		stand_uid,
		"S"
	)
	if departure.is_empty():
		_fail("Pico arrival stand should expose a matching departure route.")
		return
	plane.set_departure_route(
		departure.get("route", PackedVector2Array()),
		"S",
		stand_uid,
		int(departure.get("runway_uid", -1))
	)

	ground.request_turnaround(
		plane,
		"Pico P8",
		true
	)
	var job_id := plane.get_instance_id()
	var turnaround := ground.get_turnaround_snapshot(
		plane
	)
	if String(turnaround.get("stage", "")) != "UNLOADING":
		_fail("Returned Pico should begin with visible unloading.")
		return

	for service_key in ["passenger_out", "cargo_out"]:
		ground._on_service_completed(
			plane,
			"Pico P8",
			job_id,
			service_key,
			false
		)
	turnaround = ground.get_turnaround_snapshot(
		plane
	)
	if String(turnaround.get("stage", "")) != "SERVICING":
		_fail("Pico unload should flow into ground service.")
		return

	for service_key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			plane,
			"Pico P8",
			job_id,
			service_key,
			false
		)
	turnaround = ground.get_turnaround_snapshot(
		plane
	)
	if String(turnaround.get("stage", "")) != "WAITING_PASSENGERS":
		_fail("Owned Pico should visibly wait for its outbound passengers.")
		return
	if not ground.approve_passenger_loading(plane):
		_fail("Pico passenger gate should resume into loading.")
		return

	for service_key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			plane,
			"Pico P8",
			job_id,
			service_key,
			false
		)
	turnaround = ground.get_turnaround_snapshot(
		plane
	)
	if String(turnaround.get("stage", "")) != "PUSHBACK_PREP":
		_fail("Pico loading should advance to pushback preparation.")
		return

	ground._on_service_completed(
		plane,
		"Pico P8",
		job_id,
		"pushback",
		false
	)
	if plane.state != "READY_FOR_DEPARTURE":
		_fail("Completed Pico turnaround should become departure-ready.")
		return

	runway.request_departure(
		plane,
		"Pico P8"
	)
	var reached_takeoff := false
	var reached_climb := false
	var climb_lift_sample := 0.0
	var departure_guard := 0
	while plane.state != "EN_ROUTE" and departure_guard < 1900:
		plane._process(0.05)
		runway._process(0.05)
		if plane.state == "TAKEOFF_ROLL":
			reached_takeoff = true
		if plane.state == "CLIMBING":
			reached_climb = true
			if climb_lift_sample <= 0.0:
				plane._process(0.35)
				climb_lift_sample = plane.get_airborne_visual_lift()
		departure_guard += 1

	if not reached_takeoff:
		_fail("Pico should visibly accelerate through a takeoff roll.")
		return
	if not reached_climb:
		_fail("Pico should visibly rotate into a climb before disappearing.")
		return
	if climb_lift_sample <= 5.0:
		_fail("Pico climb-out should separate the aircraft sprite from its ground shadow.")
		return
	if plane.state != "EN_ROUTE":
		_fail("Pico should complete climb-out before entering the route timer.")
		return
	if plane.visible:
		_fail("Pico should disappear only after the visible climb-out is complete.")
		return

	var required_sequence := [
		"APPROACH",
		"LANDING_ROLL",
		"TAXIING_IN",
		"PARKED",
		"UNLOADING",
		"SERVICING",
		"WAITING_PASSENGERS",
		"LOADING",
		"PUSHBACK_PREP",
		"READY_FOR_DEPARTURE",
		"TAXIING_OUT",
		"HOLD_SHORT",
		"TAKEOFF_ROLL",
		"CLIMBING",
		"EN_ROUTE"
	]
	if not _contains_ordered_states(
		state_history,
		required_sequence
	):
		_fail(
			"Pico golden path should preserve the full arrival-turnaround-departure sequence. Got: %s"
			% str(state_history)
		)
		return

	print(
		"PICO_FULL_FLIGHT_CYCLE_OK approach=visible descent=true landing=true "
		+ "taxi_in=true turnaround=true pushback=true taxi_out=true "
		+ "takeoff=true climb_out=true"
	)
	quit(0)


func _contains_ordered_states(
	history: Array[String],
	required: Array
) -> bool:
	var cursor := 0
	for state_variant in history:
		if cursor >= required.size():
			break
		if state_variant == String(required[cursor]):
			cursor += 1
	return cursor == required.size()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
