extends SceneTree

const RUNWAY_UID := 17


func _init() -> void:
	call_deferred("_run")


func _plane(label: String, departure: bool = true) -> CareerAircraft:
	var aircraft := CareerAircraft.new()
	aircraft.name = label
	root.add_child(aircraft)
	aircraft.configure_aircraft_type("pico_p8")
	aircraft.configure_skyrama_handling(true)
	aircraft.set_simple_runway_route(
		Vector2(0, 0),
		Vector2(280, 0),
		RUNWAY_UID
	)
	if departure:
		aircraft.assign_flight_plan({
			"destination_id": "brussels",
			"duration_seconds": 60.0
		})
		aircraft._set_state("SIMPLE_WAITING_SEND")
	return aircraft


func _run() -> void:
	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(null)

	var first := _plane("First")
	var second := _plane("Second")
	var stale := _plane("Canceled")
	await process_frame
	dispatcher.request_direct_departure(first, first.name)
	if first.state != "LINE_UP" or dispatcher.get_active_count() != 1:
		_fail("First SEND must reserve runway START exactly once.")
		return

	# Double taps while cleared may not put the active plane in the queue.
	dispatcher.request_direct_departure(first, first.name)
	if dispatcher.get_waiting_count() != 0:
		_fail("Repeated clearance must not enqueue an active aircraft.")
		return

	dispatcher.request_direct_departure(second, second.name)
	dispatcher.request_direct_departure(second, second.name)
	if dispatcher.get_waiting_departure_count() != 1:
		_fail("Double SEND on a blocked runway must queue only once.")
		return

	dispatcher.request_direct_departure(stale, stale.name)
	stale.stage_simple_hangar_inventory()
	dispatcher._process(0.1)
	if dispatcher.get_waiting_departure_count() != 1:
		_fail("Hangar transfer must invalidate obsolete runway clearance.")
		return

	# While the first takeoff is separating, a new request must not skip
	# the existing queue even though the active slot is now empty.
	first.runway_cleared.emit()
	var third := _plane("Third")
	dispatcher.request_direct_departure(third, third.name)
	if (
		dispatcher.get_waiting_departure_count() != 2
		or third.state != "SIMPLE_WAITING_SEND"
	):
		_fail("A new SEND must not jump past a departure already waiting.")
		return

	for tick in range(20):
		dispatcher._process(0.25)
	if second.state != "LINE_UP" or third.state != "SIMPLE_WAITING_SEND":
		_fail("FIFO runway clearance should resume after separation.")
		return

	# An old, late completion event cannot unlock a different plane.
	dispatcher._on_aircraft_cleared_runway(
		RUNWAY_UID, "First", first.get_instance_id()
	)
	if dispatcher.get_active_count() != 1:
		_fail("Stale completion must not release the next active plane.")
		return

	# A node removed during departure must not permanently block the
	# runway or prevent subsequent aircraft receiving clearance.
	second.queue_free()
	await process_frame
	dispatcher._process(0.1)
	if third.state != "LINE_UP" or dispatcher.get_active_count() != 1:
		_fail("Freed aircraft must release its slot to the next departure.")
		return

	# Arrival RECEIVE gets the same idempotence guarantee.
	var arriving := _plane("Arriving", false)
	if not arriving.stage_for_manual_arrival():
		_fail("Arrival fixture must be ready for RECEIVE.")
		return
	var arrivals := RunwayDispatcher.new()
	root.add_child(arrivals)
	arrivals.configure(null)
	arrivals.request_arrival(arriving, arriving.name)
	arrivals.request_arrival(arriving, arriving.name)
	if arrivals.get_active_count() != 1 or arrivals.get_waiting_count() != 0:
		_fail("Repeated RECEIVE must not queue an already-cleared arrival.")
		return

	print("RUNWAY_QUEUE_INTEGRITY_OK duplicates=false stale=false fifo=true released=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
