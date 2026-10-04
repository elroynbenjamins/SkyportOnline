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
		_fail("Starter airport should expose runway routes.")
		return

	var runway_uid := int(
		departures[0].get("runway_uid", -1)
	)
	if runway_uid < 0:
		_fail("Starter departure should identify its runway.")
		return

	var has_intersection := false
	for cell in [
		Vector2i(11, 10),
		Vector2i(12, 10),
		Vector2i(13, 10)
	]:
		if grid.get_taxiway_connection_count(cell) >= 3:
			has_intersection = true
			break
	if not has_intersection:
		_fail(
			"Starter taxiway should expose at least one marked 3-way intersection."
		)
		return

	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)

	var departure := AircraftPrototype.new()
	root.add_child(departure)
	departure.configure_aircraft_type("pico_p8")
	departure.set_departure_route(
		departures[0]["route"],
		"S",
		int(departures[0].get("stand_uid", -1)),
		runway_uid
	)
	departure.assign_flight_plan({
		"destination_id": "visual-control",
		"city": "Visual Control",
		"duration_seconds": 1.0
	})
	departure.mark_service_complete()

	dispatcher.request_departure(
		departure,
		"Departure"
	)
	var approaching := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if String(
		approaching.get("status", "")
	) != "departure_approaching":
		_fail(
			"Taxiing departure should set departure-approaching runway state."
		)
		return
	if String(
		approaching.get("stop_bar", "")
	) != "amber":
		_fail("Approaching departure should illuminate amber stop bar.")
		return

	grid.set_runway_visual_state(
		runway_uid,
		approaching
	)
	var stored := grid.get_runway_visual_state(
		runway_uid
	)
	if String(stored.get("status", "")) != "departure_approaching":
		_fail("Airport grid should retain dispatcher runway visual state.")
		return
	if grid._stop_bar_color_for_state(
		stored
	) != AirportGrid.STOP_BAR_AMBER:
		_fail("Amber runway state should map to amber stop-bar lamps.")
		return

	departure.hold_short_reached.emit()
	var occupied_departure := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if String(
		occupied_departure.get("status", "")
	) != "occupied_departure":
		_fail("Cleared departure should mark runway occupied by departure.")
		return
	if String(
		occupied_departure.get("stop_bar", "")
	) != "red":
		_fail("Occupied runway should illuminate red stop bar.")
		return

	var arrival := AircraftPrototype.new()
	root.add_child(arrival)
	arrival.configure_aircraft_type("pico_p8")
	arrival.set_arrival_route(
		arrivals[0]["route"],
		int(arrivals[0].get("stand_uid", -1)),
		runway_uid
	)
	dispatcher.request_arrival(
		arrival,
		"Arrival"
	)

	var arrival_priority := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if int(
		arrival_priority.get("waiting_arrivals", 0)
	) != 1:
		_fail("Queued arrival should be reflected in runway visual state.")
		return
	if not bool(
		arrival_priority.get("arrival_priority", false)
	):
		_fail("Queued arrival should flag arrival-priority indication.")
		return

	departure.runway_cleared.emit()
	await process_frame

	var spacing_state := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if String(
		spacing_state.get("status", "")
	) != "arrival_priority_spacing":
		_fail("Priority arrival should show an arrival-spacing runway state.")
		return
	if float(
		spacing_state.get("separation_remaining", 0.0)
	) <= 0.0:
		_fail("Runway visual state should expose live separation countdown.")
		return
	if String(
		spacing_state.get("stop_bar", "")
	) != "amber":
		_fail("Arrival-priority spacing should keep amber stop-bar indication.")
		return

	dispatcher._process(
		RunwayPacingRules.DEPARTURE_TO_ARRIVAL + 0.1
	)
	var occupied_arrival := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if String(
		occupied_arrival.get("status", "")
	) != "occupied_arrival":
		_fail("Priority arrival should occupy runway after separation.")
		return
	if String(
		occupied_arrival.get("active_operation", "")
	) != "arrival":
		_fail("Runway visual state should expose active arrival operation.")
		return

	arrival.runway_cleared.emit()
	await process_frame

	var clear_state := dispatcher.get_runway_visual_state(
		runway_uid
	)
	if String(
		clear_state.get("status", "")
	) != "clear":
		_fail("Cleared runway should return to clear visual state.")
		return
	if String(
		clear_state.get("stop_bar", "")
	) != "off":
		_fail("Clear runway should switch stop-bar lamps to off/dim.")
		return

	grid.set_runway_visual_state(
		runway_uid,
		clear_state
	)
	if grid._stop_bar_color_for_state(
		clear_state
	) != AirportGrid.STOP_BAR_OFF:
		_fail("Clear runway state should map to dim stop-bar lamps.")
		return

	print(
		"Runway visual controls passed: live stop bars, occupied beacon, "
		+ "arrival priority, and taxiway intersection detection."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
