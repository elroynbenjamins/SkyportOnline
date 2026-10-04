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
		_fail("Starter airport should expose departure and arrival routes.")
		return

	var departure_info: Dictionary = departures[0]
	var raw_departure: PackedVector2Array = departure_info.get(
		"route",
		PackedVector2Array()
	)
	if raw_departure.size() < 5:
		_fail("Departure route should include explicit hold-short point.")
		return

	var hold_short: Vector2 = departure_info.get(
		"hold_short_position",
		Vector2.INF
	)
	if hold_short == Vector2.INF:
		_fail("Departure route should expose hold-short metadata.")
		return
	if raw_departure[
		raw_departure.size() - 3
	].distance_to(hold_short) > 0.01:
		_fail("Hold-short point should sit immediately before runway entry.")
		return

	var traffic := TaxiTrafficController.new()
	root.add_child(traffic)
	var runway := RunwayDispatcher.new()
	root.add_child(runway)

	var arrival_a := AircraftPrototype.new()
	var arrival_b := AircraftPrototype.new()
	var departure := AircraftPrototype.new()
	root.add_child(arrival_a)
	root.add_child(arrival_b)
	root.add_child(departure)

	for aircraft in [arrival_a, arrival_b, departure]:
		aircraft.configure_aircraft_type("pico_p8")
		aircraft.configure_taxi_traffic(traffic)

	var arrival_info: Dictionary = arrivals[0]
	var arrival_route: PackedVector2Array = arrival_info.get(
		"route",
		PackedVector2Array()
	)
	for aircraft in [arrival_a, arrival_b]:
		aircraft.set_arrival_route(
			arrival_route,
			int(arrival_info.get("stand_uid", -1)),
			int(arrival_info.get("runway_uid", -1))
		)

	departure.set_departure_route(
		raw_departure,
		"S",
		int(departure_info.get("stand_uid", -1)),
		int(departure_info.get("runway_uid", -1))
	)
	departure.assign_flight_plan({
		"destination_id": "hold-short-test",
		"city": "Hold Short Test",
		"duration_seconds": 1.0
	})
	departure.mark_service_complete()

	runway.request_arrival(arrival_a, "Arrival A")
	if runway.get_active_count() != 1:
		_fail("First arrival should occupy the runway.")
		return
	if arrival_a.state != "APPROACH":
		_fail("First arrival should be cleared to approach.")
		return

	runway.request_departure(departure, "Departure")
	if runway.get_taxiing_to_hold_count() != 1:
		_fail("Departure should taxi toward hold short without reserving runway.")
		return
	if runway.get_waiting_departure_count() != 0:
		_fail("Departure should not enter runway queue before hold short.")
		return

	for _step in range(500):
		departure._process(0.10)
		if departure.state == "HOLD_SHORT":
			break

	if departure.state != "HOLD_SHORT":
		_fail("Departure should stop at runway hold short.")
		return
	if departure.global_position.distance_to(hold_short) > 0.5:
		_fail("Departure should stop on the marked hold-short position.")
		return
	if runway.get_waiting_departure_count() != 1:
		_fail("Hold-short departure should queue while runway is occupied.")
		return
	if not departure.turnaround_label.text.contains("HOLD SHORT"):
		_fail("Hold-short wait should be visible above aircraft.")
		return

	# This arrival joins after the departure, but arrivals should still
	# receive priority once the runway becomes free.
	runway.request_arrival(arrival_b, "Arrival B")
	if runway.get_waiting_arrival_count() != 1:
		_fail("Second arrival should queue behind active runway use.")
		return
	if runway.get_waiting_count() != 2:
		_fail("Runway queue should contain one arrival and one departure.")
		return

	arrival_a.runway_cleared.emit()
	await process_frame

	if arrival_b.state != "APPROACH":
		_fail("Queued arrival should receive priority over hold-short departure.")
		return
	if departure.state != "HOLD_SHORT":
		_fail("Departure should remain holding while priority arrival lands.")
		return
	if runway.get_waiting_departure_count() != 1:
		_fail("Departure should remain in queue during priority arrival.")
		return

	arrival_b.runway_cleared.emit()
	await process_frame

	if departure.state != "CLEARED":
		_fail("Departure should be cleared after all queued arrivals.")
		return
	if runway.get_waiting_count() != 0:
		_fail("Runway queue should empty after departure clearance.")
		return

	departure._process(0.60)
	if departure.state != "ENTERING_RUNWAY":
		_fail("Cleared departure should move from hold short onto runway.")
		return

	for _step in range(100):
		departure._process(0.10)
		if departure.state == "LINE_UP":
			break
	if departure.state != "LINE_UP":
		_fail("Departure should enter runway then line up for takeoff.")
		return

	print(
		"Runway hold-short passed: marked stop point, taxi-before-clearance, "
		+ "arrival priority, runway entry, and lineup sequencing."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
