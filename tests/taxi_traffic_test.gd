extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := TaxiTrafficController.new()
	root.add_child(controller)

	var arrival := AircraftPrototype.new()
	var departure := AircraftPrototype.new()
	root.add_child(arrival)
	root.add_child(departure)
	arrival.configure_aircraft_type("pico_p8")
	departure.configure_aircraft_type("pico_p8")
	arrival.state = "TAXIING_IN"
	departure.state = "TAXIING_OUT"

	var arrival_request := controller.request_segment(
		arrival,
		Vector2(0, 0),
		Vector2(80, 0)
	)
	if not bool(arrival_request.get("allowed", false)):
		_fail("First taxi segment reservation should be granted.")
		return

	var departure_request := controller.request_segment(
		departure,
		Vector2(40, -60),
		Vector2(40, 60)
	)
	if bool(departure_request.get("allowed", true)):
		_fail("Crossing departure must hold for reserved arrival traffic.")
		return
	if String(
		departure_request.get("reason", "")
	) != "arrival traffic":
		_fail("Departure conflict with taxiing-in aircraft should report arrival traffic.")
		return

	controller.release_segment(arrival)
	departure_request = controller.request_segment(
		departure,
		Vector2(40, -60),
		Vector2(40, 60)
	)
	if not bool(departure_request.get("allowed", false)):
		_fail("Held departure should proceed after arrival reservation clears.")
		return
	controller.release_segment(departure)

	var leader := AircraftPrototype.new()
	var follower := AircraftPrototype.new()
	root.add_child(leader)
	root.add_child(follower)
	leader.configure_aircraft_type("pico_p8")
	follower.configure_aircraft_type("pico_p8")
	leader.state = "TAXIING_OUT"
	follower.state = "TAXIING_OUT"

	if not bool(
		controller.request_segment(
			leader,
			Vector2(0, 0),
			Vector2(80, 0)
		).get("allowed", false)
	):
		_fail("Lead aircraft should reserve shared taxi segment.")
		return

	var follower_request := controller.request_segment(
		follower,
		Vector2(-35, 0),
		Vector2(45, 0)
	)
	if bool(follower_request.get("allowed", true)):
		_fail("Following aircraft should not enter occupied taxi corridor.")
		return
	if String(
		follower_request.get("reason", "")
	) != "aircraft ahead":
		_fail("Same-direction conflict should report aircraft ahead.")
		return

	controller.release_all_for_aircraft(leader)
	controller.release_all_for_aircraft(follower)

	var pico_clearance := TaxiTrafficController.clearance_for_aircraft(
		leader
	)
	var nimbus := AircraftPrototype.new()
	root.add_child(nimbus)
	nimbus.configure_aircraft_type("nimbus_n40")
	var nimbus_clearance := TaxiTrafficController.clearance_for_aircraft(
		nimbus
	)
	if nimbus_clearance <= pico_clearance:
		_fail("M-class aircraft should reserve a larger taxi clearance corridor.")
		return

	var live_controller := TaxiTrafficController.new()
	root.add_child(live_controller)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)
	plane_a.configure_aircraft_type("pico_p8")
	plane_b.configure_aircraft_type("pico_p8")
	plane_a.configure_taxi_traffic(live_controller)
	plane_b.configure_taxi_traffic(live_controller)

	var route_a := PackedVector2Array([
		Vector2(-80, 0),
		Vector2(0, 0),
		Vector2(80, 0),
		Vector2(160, 0)
	])
	var route_b := PackedVector2Array([
		Vector2(0, -80),
		Vector2(0, 0),
		Vector2(0, 80),
		Vector2(0, 160)
	])

	plane_a.set_departure_route(route_a, "S", 1, 10)
	plane_b.set_departure_route(route_b, "S", 2, 10)
	plane_a.assign_flight_plan({
		"destination_id": "taxi-a",
		"city": "Taxi A",
		"duration_seconds": 1.0
	})
	plane_b.assign_flight_plan({
		"destination_id": "taxi-b",
		"city": "Taxi B",
		"duration_seconds": 1.0
	})
	plane_a.mark_service_complete()
	plane_b.mark_service_complete()
	plane_a.begin_taxi_to_hold_short()
	plane_b.begin_taxi_to_hold_short()

	plane_a._process(0.10)
	plane_b._process(0.10)
	if plane_a.state != "TAXIING_OUT" or plane_b.state != "TAXIING_OUT":
		_fail("Both test aircraft should enter taxi-out state.")
		return

	plane_a._process(0.10)
	var b_start := plane_b.global_position
	plane_b._process(0.10)

	if not plane_b.is_taxi_holding():
		_fail("Conflicting aircraft should enter visible taxi hold.")
		return
	if plane_b.global_position.distance_to(b_start) > 0.01:
		_fail("Held aircraft must remain at its current holding point.")
		return
	if not plane_b.turnaround_label.text.contains("TAXI HOLD"):
		_fail("Taxi hold should be visible above the aircraft.")
		return
	if live_controller.get_active_reservation_count() != 1:
		_fail("Only the moving aircraft should own the conflict reservation.")
		return

	# Let A clear the shared intersection and reach runway hold short.
	for _step in range(80):
		plane_a._process(0.10)
		if plane_a.state == "HOLD_SHORT":
			break
	if plane_a.state != "HOLD_SHORT":
		_fail("Lead aircraft should clear the intersection and reach hold short.")
		return
	if live_controller.has_reservation(plane_a):
		_fail("Aircraft should release taxi reservation at hold short.")
		return

	plane_b._process(0.10)
	if plane_b.is_taxi_holding():
		_fail("Held aircraft should resume once the conflict corridor clears.")
		return
	if plane_b.global_position.distance_to(b_start) <= 0.01:
		_fail("Released aircraft should begin moving into its reserved segment.")
		return

	print(
		"Taxi traffic passed: segment reservations, arrival conflict labels, "
		+ "same-direction spacing, visible holding, and automatic release."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
