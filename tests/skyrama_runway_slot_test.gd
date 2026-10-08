extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	return not grid.confirm_build_preview().is_empty()


func _make_plane(
	name_text: String,
	runway: Dictionary
) -> CareerAircraft:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	plane.name = name_text
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.set_simple_runway_route(
		runway.get("start_world", Vector2.ZERO),
		runway.get("end_world", Vector2.ZERO),
		int(runway.get("runway_uid", -1))
	)
	return plane


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	if not _place(
		grid,
		"short_runway",
		Vector2i(4, 4)
	):
		return

	var runway_route := grid.get_simple_runway_animation_route(
		"S"
	)
	if runway_route.is_empty():
		_fail("Short Runway should expose the simple animation route.")
		return
	var runway_uid := int(
		runway_route.get(
			"runway_uid",
			-1
		)
	)

	# Arrival: the landed aircraft owns the runway until UNLOAD is tapped.
	var arrival_dispatcher := RunwayDispatcher.new()
	root.add_child(arrival_dispatcher)
	arrival_dispatcher.configure(grid)

	var arrival_a := _make_plane(
		"Arrival A",
		runway_route
	)
	await process_frame
	if not arrival_a.stage_for_manual_arrival():
		_fail("Inbound aircraft should expose RECEIVE/LAND.")
		return
	if arrival_a.get_handling_action() != "RECEIVE":
		_fail("Inbound Skyrama aircraft should expose RECEIVE.")
		return

	arrival_dispatcher.request_arrival(
		arrival_a,
		"Arrival A"
	)
	var guard := 0
	while (
		arrival_a.state != "SIMPLE_WAITING_UNLOAD"
		and guard < 2400
	):
		arrival_a._process(0.05)
		arrival_dispatcher._process(0.05)
		guard += 1

	if arrival_a.state != "SIMPLE_WAITING_UNLOAD":
		_fail("Received aircraft should finish at the runway end.")
		return
	var arrival_slot := arrival_dispatcher.get_runway_slot_snapshot(
		runway_uid
	)
	if not bool(arrival_slot.get("occupied", false)):
		_fail("Landed aircraft must keep the runway occupied.")
		return
	if String(arrival_slot.get("slot", "")) != "end":
		_fail("Landed aircraft should occupy the runway END slot.")
		return
	if String(
		arrival_slot.get(
			"phase",
			""
		)
	) != "arrival_end_waiting":
		_fail("Runway should report arrival_end_waiting before UNLOAD.")
		return

	var arrival_b := _make_plane(
		"Arrival B",
		runway_route
	)
	await process_frame
	arrival_b.stage_for_manual_arrival()
	arrival_dispatcher.request_arrival(
		arrival_b,
		"Arrival B"
	)
	if arrival_dispatcher.get_active_count() != 1:
		_fail("Only one aircraft may occupy a runway.")
		return
	if arrival_dispatcher.get_waiting_arrival_count() != 1:
		_fail("Second arrival should wait while runway END is occupied.")
		return
	if arrival_b.state != "HOLDING_FOR_ARRIVAL":
		_fail("Second arrival must remain inbound until runway is clear.")
		return

	# Tapping UNLOAD teleports the aircraft away and is the exact release point.
	arrival_a.start_simple_unloading(
		Vector2(300, 220),
		1.0
	)
	if arrival_dispatcher.is_runway_slot_occupied(
		runway_uid
	):
		_fail("UNLOAD transfer should release the occupied runway slot.")
		return

	# Departure: SEND may place only one aircraft at runway START at a time.
	var departure_dispatcher := RunwayDispatcher.new()
	root.add_child(departure_dispatcher)
	departure_dispatcher.configure(grid)

	var departure_a := _make_plane(
		"Departure A",
		runway_route
	)
	await process_frame
	departure_a.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0
	})
	departure_a._set_state("SIMPLE_WAITING_SEND")
	departure_dispatcher.request_direct_departure(
		departure_a,
		"Departure A"
	)

	if departure_a.state != "LINE_UP":
		_fail("SEND should teleport cleared aircraft to runway START.")
		return
	var departure_slot := departure_dispatcher.get_runway_slot_snapshot(
		runway_uid
	)
	if String(departure_slot.get("slot", "")) != "start":
		_fail("Departure should occupy runway START.")
		return
	if String(
		departure_slot.get(
			"phase",
			""
		)
	) != "departure_start_waiting":
		_fail("Lined-up aircraft should report departure_start_waiting.")
		return

	var departure_b := _make_plane(
		"Departure B",
		runway_route
	)
	await process_frame
	departure_b.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0
	})
	departure_b._set_state("SIMPLE_WAITING_SEND")
	departure_dispatcher.request_direct_departure(
		departure_b,
		"Departure B"
	)
	if departure_dispatcher.get_active_count() != 1:
		_fail("Runway START may contain only one departure aircraft.")
		return
	if departure_dispatcher.get_waiting_departure_count() != 1:
		_fail("Second departure should remain queued while START is occupied.")
		return
	if departure_b.state != "SIMPLE_WAITING_SEND":
		_fail("Queued departure should stay at cargo until runway is free.")
		return

	print(
		"SKYRAMA_RUNWAY_SLOT_OK receive=true arrival_end=one "
		+ "unload_releases=true departure_start=one queued_stays_at_cargo=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
