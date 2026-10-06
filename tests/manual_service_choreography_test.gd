extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var ambient := AirportAmbientLife.new()
	root.add_child(ambient)
	ambient.configure(grid)
	await process_frame

	var ground := GroundServiceDispatcher.new()
	root.add_child(ground)
	ground.configure(grid)

	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.configure_handling_mode(true, false)
	plane.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0
	})

	var departures := grid.get_departure_routes("S")
	if departures.is_empty():
		_fail("Starter airport should expose an S departure route.")
		return
	var departure: Dictionary = departures[0]
	plane.set_departure_route(
		departure.get("route", PackedVector2Array()),
		"S",
		int(departure.get("stand_uid", -1)),
		int(departure.get("runway_uid", -1))
	)

	ground.request_turnaround(
		plane,
		"Choreography Pico",
		true,
		true
	)
	var job_id := plane.get_instance_id()
	var snapshot := ambient.get_apron_choreography_snapshot(plane)
	if plane.state != "WAITING_UNLOAD":
		_fail("Manual returned aircraft should wait at UNLOAD.")
		return
	if not bool(snapshot.get("stairs", false)):
		_fail("Passenger stairs should already be staged while UNLOAD waits for a tap.")
		return
	if bool(snapshot.get("cargo_equipment", true)):
		_fail("Cargo equipment should not deploy before the UNLOAD tap.")
		return
	if bool(snapshot.get("gpu", true)):
		_fail("Service GPU should not deploy before SERVICE.")
		return
	if int(snapshot.get("prop_count", 0)) != 3:
		_fail("WAITING_UNLOAD should show safety kit plus stairs.")
		return
	if int(snapshot.get("crew_count", 0)) != 1:
		_fail("WAITING_UNLOAD should stage one ground crew member.")
		return

	if not ground.advance_manual_handling(plane, "UNLOAD"):
		_fail("UNLOAD tap should start unloading.")
		return
	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if not bool(snapshot.get("cargo_equipment", false)):
		_fail("UNLOAD should deploy the belt/loader and cargo staging.")
		return
	if int(snapshot.get("prop_count", 0)) != 5:
		_fail("Active unloading should use the full five-piece apron setup.")
		return

	for service_key in ["passenger_out", "cargo_out"]:
		ground._on_service_completed(
			plane,
			"Choreography Pico",
			job_id,
			service_key,
			false
		)

	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if plane.state != "WAITING_SERVICE":
		_fail("Unload completion should pause at SERVICE.")
		return
	if not bool(snapshot.get("stairs", false)):
		_fail("Stairs should remain staged between unload and service.")
		return
	if bool(snapshot.get("cargo_equipment", true)):
		_fail("Cargo equipment should clear after unloading completes.")
		return
	if bool(snapshot.get("gpu", true)):
		_fail("GPU should wait for the SERVICE tap.")
		return

	if not ground.advance_manual_handling(plane, "SERVICE"):
		_fail("SERVICE tap should start ground service.")
		return
	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if plane.state != "SERVICING":
		_fail("SERVICE tap should put the aircraft into SERVICING.")
		return
	if not bool(snapshot.get("gpu", false)):
		_fail("SERVICE should visibly stage the GPU.")
		return
	if not bool(snapshot.get("stairs", false)):
		_fail("Stairs should remain at the aircraft throughout service.")
		return
	if int(snapshot.get("prop_count", 0)) != 4:
		_fail("SERVICING should show safety kit, stairs and GPU.")
		return

	for service_key in ["fuel", "cleaning", "catering"]:
		ground._on_service_completed(
			plane,
			"Choreography Pico",
			job_id,
			service_key,
			false
		)

	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if plane.state != "WAITING_PASSENGERS":
		_fail("Service completion should pause at LOAD.")
		return
	if not bool(snapshot.get("stairs", false)):
		_fail("LOAD gate should keep stairs ready for boarding.")
		return
	if bool(snapshot.get("cargo_equipment", true)):
		_fail("Loading equipment should wait for the LOAD tap.")
		return

	plane.clear_handling_action()
	if not ground.approve_passenger_loading(plane):
		_fail("LOAD should start loading when passenger stock has been approved.")
		return
	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if not bool(snapshot.get("cargo_equipment", false)):
		_fail("LOAD should deploy baggage/cargo handling equipment.")
		return
	if int(snapshot.get("prop_count", 0)) != 5:
		_fail("Active loading should use the full five-piece apron setup.")
		return

	for service_key in ["passenger_in", "cargo_in"]:
		ground._on_service_completed(
			plane,
			"Choreography Pico",
			job_id,
			service_key,
			false
		)

	snapshot = ambient.get_apron_choreography_snapshot(plane)
	if plane.state != "READY_FOR_DEPARTURE":
		_fail("Loading completion should pause at SEND.")
		return
	if bool(snapshot.get("stairs", true)):
		_fail("Stairs should clear when the aircraft becomes ready for SEND.")
		return
	if bool(snapshot.get("cargo_equipment", true)):
		_fail("Cargo equipment should clear before SEND.")
		return
	if not bool(snapshot.get("marshaller", false)):
		_fail("A marshaller should remain for the SEND/pushback handoff.")
		return
	if int(snapshot.get("prop_count", 0)) != 2:
		_fail("SEND gate should leave only the compact safety kit.")
		return

	print(
		"MANUAL_SERVICE_CHOREOGRAPHY_OK unload=staged service=staged "
		+ "load=staged send=clear"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
