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
	plane.name = "Manual Pico"
	plane.configure_aircraft_type("pico_p8")
	plane.configure_taxi_traffic(traffic)
	plane.configure_handling_mode(true, false)
	plane.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0,
		"passengers_boarded": 8
	})

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

	if not plane.stage_for_manual_arrival():
		_fail("Manual Pico should stage visibly before landing.")
		return
	if plane.state != "HOLDING_FOR_ARRIVAL":
		_fail("Manual inbound aircraft should wait for the LAND action.")
		return
	if plane.get_handling_action() != "LAND":
		_fail("Inbound manual aircraft should expose a LAND action.")
		return
	if not bool(
		plane.get_handling_action_snapshot().get(
			"visible",
			false
		)
	):
		_fail("LAND action bubble should be visible above the inbound aircraft.")
		return
	if plane.get_airborne_visual_lift() <= 0.0:
		_fail("Inbound LAND gate should still render the aircraft airborne.")
		return

	# LAND remains manual even when future handling automation is enabled.
	var automation_probe := CareerAircraft.new()
	root.add_child(automation_probe)
	await process_frame
	automation_probe.configure_aircraft_type("pico_p8")
	automation_probe.configure_handling_mode(true, true)
	automation_probe.set_arrival_route(
		arrival.get("route", PackedVector2Array()),
		stand_uid,
		runway_uid
	)
	if not automation_probe.stage_for_manual_arrival():
		_fail("Automated handling should still stage a manual LAND action.")
		return
	if automation_probe.get_handling_action() != "LAND":
		_fail("Paid handling automation must never automate LAND.")
		return
	automation_probe.queue_free()

	plane.clear_handling_action()
	runway.request_arrival(
		plane,
		"Manual Pico"
	)
	if plane.state != "APPROACH":
		_fail("LAND action should enter the visible approach.")
		return

	var arrival_guard := 0
	while (
		plane.state != "WAITING_TAXI_IN"
		and arrival_guard < 1600
	):
		plane._process(0.05)
		runway._process(0.05)
		arrival_guard += 1
	if plane.state != "WAITING_TAXI_IN":
		_fail("Landing rollout should stop after clearing the runway for a TAXI tap.")
		return
	if plane.get_handling_action() != "TAXI":
		_fail("Runway exit should expose a TAXI action.")
		return
	if runway.get_active_count() != 0:
		_fail("Runway must be released before the player taps TAXI.")
		return

	if not plane.continue_manual_taxi_in():
		_fail("TAXI action should resume movement to the assigned stand.")
		return
	var taxi_guard := 0
	while plane.state != "PARKED" and taxi_guard < 1200:
		plane._process(0.05)
		taxi_guard += 1
	if plane.state != "PARKED":
		_fail("TAXI action should end with the aircraft parked at its stand.")
		return

	var departure := grid.get_departure_route_for_stand(
		stand_uid,
		"S"
	)
	if departure.is_empty():
		_fail("Manual aircraft stand should expose a departure route.")
		return
	plane.set_departure_route(
		departure.get("route", PackedVector2Array()),
		"S",
		stand_uid,
		int(departure.get("runway_uid", -1))
	)

	ground.request_turnaround(
		plane,
		"Manual Pico",
		true,
		true
	)
	var job_id := plane.get_instance_id()
	var snapshot := ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "READY_UNLOAD":
		_fail("Manual turnaround should wait before unloading.")
		return
	if plane.state != "WAITING_UNLOAD" or plane.get_handling_action() != "UNLOAD":
		_fail("Parked returned aircraft should expose UNLOAD.")
		return

	if not ground.advance_manual_handling(plane, "UNLOAD"):
		_fail("UNLOAD tap should start unloading.")
		return
	for service_key in ["passenger_out", "cargo_out"]:
		ground._on_service_completed(
			plane,
			"Manual Pico",
			job_id,
			service_key,
			false
		)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "READY_SERVICE":
		_fail("Completed unload should stop at the SERVICE action.")
		return
	if plane.state != "WAITING_SERVICE" or plane.get_handling_action() != "SERVICE":
		_fail("Manual aircraft should expose SERVICE after unloading.")
		return

	if not ground.advance_manual_handling(plane, "SERVICE"):
		_fail("SERVICE tap should dispatch ground servicing.")
		return
	for service_key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			plane,
			"Manual Pico",
			job_id,
			service_key,
			false
		)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "WAITING_PASSENGERS":
		_fail("Completed service should stop at the passenger/load gate.")
		return
	if plane.state != "WAITING_PASSENGERS" or plane.get_handling_action() != "LOAD":
		_fail("Manual aircraft should expose LOAD after service.")
		return

	# Main owns passenger stock spending; emulate a successful LOAD tap here.
	plane.clear_handling_action()
	if not ground.approve_passenger_loading(plane):
		_fail("Successful LOAD tap should start loading.")
		return
	for service_key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			plane,
			"Manual Pico",
			job_id,
			service_key,
			false
		)
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "READY_SEND":
		_fail("Completed loading should stop before pushback at SEND.")
		return
	if plane.state != "READY_FOR_DEPARTURE" or plane.get_handling_action() != "SEND":
		_fail("SEND must remain the final manual action.")
		return

	if not ground.advance_manual_handling(plane, "SEND"):
		_fail("SEND tap should begin pushback.")
		return
	snapshot = ground.get_turnaround_snapshot(plane)
	if String(snapshot.get("stage", "")) != "PUSHBACK_PREP":
		_fail("SEND should move the aircraft into real pushback preparation.")
		return
	ground._on_service_completed(
		plane,
		"Manual Pico",
		job_id,
		"pushback",
		false
	)
	if plane.get_handling_action() != "":
		_fail("Manual action bubble should clear after SEND.")
		return
	if plane.state != "READY_FOR_DEPARTURE":
		_fail("Completed pushback should leave the aircraft departure-ready.")
		return

	runway.request_departure(
		plane,
		"Manual Pico"
	)
	var departure_guard := 0
	while plane.state != "EN_ROUTE" and departure_guard < 1800:
		plane._process(0.05)
		runway._process(0.05)
		departure_guard += 1
	if plane.state != "EN_ROUTE":
		_fail("SEND should ultimately lead through taxi, takeoff and climb-out.")
		return

	# Future automation hook: service steps can run without taps, but SEND stops it.
	var auto_plane := CareerAircraft.new()
	root.add_child(auto_plane)
	await process_frame
	auto_plane.name = "Auto Pico"
	auto_plane.configure_aircraft_type("pico_p8")
	auto_plane.configure_handling_mode(true, true)
	auto_plane.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0
	})
	auto_plane.set_departure_route(
		departure.get("route", PackedVector2Array()),
		"S",
		stand_uid,
		int(departure.get("runway_uid", -1))
	)
	ground.request_turnaround(
		auto_plane,
		"Auto Pico",
		false,
		true
	)
	var auto_job_id := auto_plane.get_instance_id()
	var auto_snapshot := ground.get_turnaround_snapshot(auto_plane)
	if String(auto_snapshot.get("stage", "")) != "SERVICING":
		_fail("Handling automation should start service without a SERVICE tap.")
		return
	for service_key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			auto_plane,
			"Auto Pico",
			auto_job_id,
			service_key,
			false
		)
	auto_snapshot = ground.get_turnaround_snapshot(auto_plane)
	if String(auto_snapshot.get("stage", "")) != "WAITING_PASSENGERS":
		_fail("Automated service should advance to passenger loading.")
		return
	if not auto_plane.get_handling_action().is_empty():
		_fail("Paid automation should not require a LOAD tap.")
		return
	if not ground.approve_passenger_loading(auto_plane):
		_fail("Automated passenger handling should be able to start loading.")
		return
	for service_key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			auto_plane,
			"Auto Pico",
			auto_job_id,
			service_key,
			false
		)
	auto_snapshot = ground.get_turnaround_snapshot(auto_plane)
	if String(auto_snapshot.get("stage", "")) != "READY_SEND":
		_fail("Automation must stop before departure at READY_SEND.")
		return
	if auto_plane.get_handling_action() != "SEND":
		_fail("Paid automation must still require the player to press SEND.")
		return

	print(
		"MANUAL_AIRCRAFT_HANDLING_OK actions=LAND>TAXI>UNLOAD>SERVICE>LOAD>SEND "
		+ "automation=middle_steps_only"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
