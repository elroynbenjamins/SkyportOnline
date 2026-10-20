extends SceneTree

# One tap = one runway request; aircraft waiting through separation must not
# be overtaken by new requests on the same runway.
func _init() -> void:
	call_deferred("_run")


func _make_departure(label: String, runway: Dictionary) -> CareerAircraft:
	var aircraft := CareerAircraft.new()
	root.add_child(aircraft)
	aircraft.name = label
	aircraft.configure_aircraft_type("pico_p8")
	aircraft.configure_skyrama_handling(true)
	aircraft.set_simple_runway_route(
		runway.get("start_world", Vector2.ZERO),
		runway.get("end_world", Vector2.ZERO),
		int(runway.get("runway_uid", -1))
	)
	aircraft.assign_flight_plan({
		"destination_id": "brussels",
		"city": "Brussels",
		"duration_seconds": 60.0,
		"fuel_required": 1
	})
	aircraft._set_state("SIMPLE_WAITING_SEND")
	return aircraft


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	var preview := grid.set_build_preview(
		"short_runway",
		grid.tile_to_world(Vector2(4, 4)),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail("Runway fixture cannot be placed.")
		return
	if grid.confirm_build_preview().is_empty():
		_fail("Runway fixture was not built.")
		return
	var runway := grid.get_simple_runway_animation_route("S")
	if runway.is_empty():
		_fail("Runway fixture has no simple route.")
		return
	var uid := int(runway.get("runway_uid", -1))

	# A double SEND tap must not grant a second clearance or create a ghost
	# entry in the waiting queue (including after the plane is on the runway).
	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	var first := _make_departure("First", runway)
	var second := _make_departure("Second", runway)
	await process_frame
	dispatcher.request_direct_departure(first, "First")
	dispatcher.request_direct_departure(first, "First")
	if (
		first.state != "LINE_UP"
		or dispatcher.get_active_count() != 1
		or dispatcher.get_waiting_count() != 0
	):
		_fail("Repeated request for a cleared plane must be ignored.")
		return

	dispatcher.request_direct_departure(second, "Second")
	dispatcher.request_direct_departure(second, "Second")
	if (
		dispatcher.get_waiting_count() != 1
		or dispatcher.get_waiting_departure_count() != 1
		or second.state != "SIMPLE_WAITING_SEND"
	):
		_fail("Repeated request for a waiting plane must be ignored.")
		return
	if int(dispatcher.get_runway_analytics(uid).get("requests", 0)) != 2:
		_fail("Duplicate taps must not inflate runway request analytics.")
		return

	# A new request arriving exactly as separation expires must not
	# overtake a departure already waiting on an otherwise empty runway.
	var fairness := RunwayDispatcher.new()
	root.add_child(fairness)
	fairness.configure(grid)
	fairness.last_operation_by_runway[uid] = "departure"
	fairness.separation_elapsed_by_runway[uid] = 0.0
	var waiting_first := _make_departure("Queued first", runway)
	var waiting_second := _make_departure("Queued second", runway)
	await process_frame
	fairness.request_direct_departure(waiting_first, "Queued first")
	if (
		fairness.get_active_count() != 0
		or fairness.get_waiting_count() != 1
	):
		_fail("The first plane should wait for runway separation.")
		return
	fairness.separation_elapsed_by_runway[uid] = 60.0
	fairness.request_direct_departure(waiting_second, "Queued second")
	var current := fairness.get_runway_slot_snapshot(uid)
	if (
		String(current.get("aircraft_label", "")) != "Queued first"
		or waiting_first.state != "LINE_UP"
		or waiting_second.state != "SIMPLE_WAITING_SEND"
		or fairness.get_waiting_count() != 1
	):
		_fail("Fresh request bypassed an older queued departure.")
		return

	# Releasing a slot starts separation; only then may the second queued
	# aircraft reach the runway. Never spawn two planes at runway START.
	waiting_first.runway_cleared.emit()
	if fairness.get_active_count() != 0:
		_fail("A completed departure should release its runway slot.")
		return
	fairness.separation_elapsed_by_runway[uid] = 60.0
	fairness._process(0.0)
	if (
		waiting_second.state != "LINE_UP"
		or fairness.get_active_count() != 1
		or fairness.get_waiting_count() != 0
	):
		_fail("The second queued aircraft should clear after separation.")
		return

	print("RUNWAY_QUEUE_SAFETY_OK duplicate_active=true duplicate_waiting=true fifo=true separation=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
