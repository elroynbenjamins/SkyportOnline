extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var aircraft := AircraftPrototype.new()
	root.add_child(aircraft)
	aircraft.configure_aircraft_type("pico_p8")
	aircraft.configure_skyrama_handling(true)
	aircraft.assign_flight_plan({
		"destination_id": "test",
		"city": "Test",
		"duration_seconds": 2.0,
		"fuel_required": 1
	})
	aircraft.set_simple_runway_route(
		Vector2(0, 0),
		Vector2(220, 0),
		7
	)
	aircraft.set_arrival_route(
		PackedVector2Array([
			Vector2(0, 0),
			Vector2(220, 0)
		]),
		-1,
		7
	)

	var counters := {
		"runway_clear": 0,
		"arrival_complete": 0
	}
	aircraft.runway_cleared.connect(
		func():
			counters["runway_clear"] = int(
				counters["runway_clear"]
			) + 1
	)
	aircraft.arrival_completed.connect(
		func():
			counters["arrival_complete"] = int(
				counters["arrival_complete"]
			) + 1
	)

	# Receiving: RECEIVE animates to the runway end, then waits on the runway.
	aircraft.stage_for_manual_arrival()
	if aircraft.state != "HOLDING_FOR_ARRIVAL":
		_fail("Simple arrival should stage with a RECEIVE action.")
		return
	if aircraft.get_handling_action() != "RECEIVE":
		_fail("Simple arrival should show RECEIVE.")
		return

	aircraft.begin_arrival_after_clearance()
	for _step in range(80):
		aircraft._process(0.10)
		if aircraft.state == "SIMPLE_WAITING_UNLOAD":
			break
	if aircraft.state != "SIMPLE_WAITING_UNLOAD":
		_fail("Landing should stop at runway end waiting for UNLOAD.")
		return
	if int(counters["runway_clear"]) != 0:
		_fail("Runway must remain occupied until UNLOAD is pressed.")
		return
	if aircraft.get_handling_action() != "UNLOAD":
		_fail("Landed aircraft should show UNLOAD.")
		return

	aircraft.start_simple_unloading(
		Vector2(360, 140),
		0.5
	)
	if int(counters["runway_clear"]) != 1:
		_fail("Leaving runway for cargo should release runway exactly once.")
		return
	if aircraft.position != Vector2(360, 140):
		_fail("UNLOAD should teleport the aircraft to cargo handling.")
		return
	for _step in range(8):
		aircraft._process(0.10)
	if aircraft.state != "SIMPLE_WAITING_HANGAR":
		_fail("Unload completion should wait for HANGAR.")
		return
	if aircraft.get_handling_action() != "HANGAR":
		_fail("Unload completion should show HANGAR.")
		return
	if int(counters["arrival_complete"]) != 1:
		_fail("Flight completion should be emitted after unloading.")
		return

	aircraft.stage_simple_hangar_inventory()
	if aircraft.visible:
		_fail("Hangar/inventory aircraft should be hidden from airport ground.")
		return
	if aircraft.state != "READY_FOR_DESTINATION":
		_fail("Hangared aircraft should be ready for destination selection.")
		return
	if aircraft.has_flight_plan():
		_fail("Hangaring returned aircraft should clear its old flight plan.")
		return

	# Sending: destination -> fuel -> LOAD -> cargo -> SEND -> runway/takeoff.
	aircraft.assign_flight_plan({
		"destination_id": "test2",
		"city": "Test 2",
		"duration_seconds": 2.0,
		"fuel_required": 1
	})
	aircraft.start_simple_fueling(
		Vector2(420, 80),
		0.5
	)
	if not aircraft.visible or aircraft.position != Vector2(420, 80):
		_fail("Destination selection should place aircraft on fuel structure.")
		return
	for _step in range(8):
		aircraft._process(0.10)
	if aircraft.state != "SIMPLE_WAITING_LOAD":
		_fail("Fuel completion should wait for LOAD.")
		return
	if aircraft.get_handling_action() != "LOAD":
		_fail("Fuel completion should show LOAD.")
		return

	aircraft.start_simple_loading(
		Vector2(360, 140),
		0.5
	)
	for _step in range(8):
		aircraft._process(0.10)
	if aircraft.state != "SIMPLE_WAITING_SEND":
		_fail("Cargo load completion should wait for SEND.")
		return
	if aircraft.get_handling_action() != "SEND":
		_fail("Cargo load completion should show SEND.")
		return

	aircraft.begin_departure_after_clearance()
	if aircraft.state != "LINE_UP":
		_fail("SEND clearance should teleport directly to runway start.")
		return
	if aircraft.position != Vector2(0, 0):
		_fail("Direct departure should begin at runway start.")
		return

	for _step in range(120):
		aircraft._process(0.10)
		if aircraft.state == "EN_ROUTE":
			break
	if aircraft.state != "EN_ROUTE":
		_fail("Direct runway departure should complete takeoff animation.")
		return
	if aircraft.visible:
		_fail("Aircraft should hide after climbing out en route.")
		return

	print(
		"SKYRAMA_SIMPLE_HANDLING_OK "
		+ "land=true runway_lock=true teleport=true "
		+ "fuel=true load=true takeoff=true hangar=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
