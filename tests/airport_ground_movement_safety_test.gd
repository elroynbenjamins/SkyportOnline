extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var traffic := TaxiTrafficController.new()
	root.add_child(traffic)

	var blocker := AircraftPrototype.new()
	var pushback_plane := AircraftPrototype.new()
	root.add_child(blocker)
	root.add_child(pushback_plane)
	blocker.configure_aircraft_type("pico_p8")
	pushback_plane.configure_aircraft_type("pico_p8")
	blocker.configure_taxi_traffic(traffic)
	pushback_plane.configure_taxi_traffic(traffic)

	blocker.state = "TAXIING_IN"
	var blocker_request := traffic.request_segment(
		blocker,
		Vector2(0, -60),
		Vector2(0, 60)
	)
	if not bool(blocker_request.get("allowed", false)):
		_fail("Arrival blocker should reserve the crossing taxi corridor.")
		return

	pushback_plane.set_departure_route(
		PackedVector2Array([
			Vector2(-20, 0),
			Vector2(100, 0),
			Vector2(130, 0),
			Vector2(220, 0)
		]),
		"S",
		1,
		10
	)
	pushback_plane.position = Vector2(-20, 0)
	pushback_plane.state = "PUSHBACK_PREP"

	var pushback_clearance := pushback_plane.reserve_pushback_path()
	if bool(pushback_clearance.get("allowed", true)):
		_fail("Pushback must wait when its movement crosses reserved arrival traffic.")
		return
	if String(pushback_clearance.get("reason", "")) != "arrival traffic":
		_fail("Blocked pushback should identify arrival traffic as the reason.")
		return

	traffic.release_segment(blocker)
	blocker.state = "PARKED"
	blocker.position = Vector2(0, 120)
	pushback_clearance = pushback_plane.reserve_pushback_path()
	if not bool(pushback_clearance.get("allowed", false)):
		_fail("Pushback should reserve its corridor after crossing traffic clears.")
		return
	if not traffic.has_reservation(pushback_plane):
		_fail("Cleared pushback should own a taxi reservation until tow completion.")
		return

	pushback_plane.release_pushback_path()
	if traffic.has_reservation(pushback_plane):
		_fail("Completed/cancelled pushback should release its taxi reservation.")
		return

	var entry_blocker := AircraftPrototype.new()
	var departure := AircraftPrototype.new()
	root.add_child(entry_blocker)
	root.add_child(departure)
	entry_blocker.configure_aircraft_type("pico_p8")
	departure.configure_aircraft_type("pico_p8")
	entry_blocker.configure_taxi_traffic(traffic)
	departure.configure_taxi_traffic(traffic)

	entry_blocker.state = "TAXIING_IN"
	var crossing := traffic.request_segment(
		entry_blocker,
		Vector2(25, -60),
		Vector2(25, 60)
	)
	if not bool(crossing.get("allowed", false)):
		_fail("Runway-entry blocker should reserve its crossing corridor.")
		return

	departure.set_departure_route(
		PackedVector2Array([
			Vector2(-120, 0),
			Vector2(-60, 0),
			Vector2(0, 0),
			Vector2(50, 0),
			Vector2(220, 0)
		]),
		"S",
		2,
		10
	)
	departure.assign_flight_plan({
		"destination_id": "safety-test",
		"city": "Safety",
		"duration_seconds": 1.0
	})
	departure.mark_service_complete()
	departure.begin_departure_after_clearance()
	departure._process(0.60)
	if departure.state != "ENTERING_RUNWAY":
		_fail("Cleared aircraft should advance to runway-entry movement.")
		return

	var before_entry := departure.global_position
	departure._process(0.10)
	if not departure.is_taxi_holding():
		_fail("Runway entry must hold for conflicting taxi traffic.")
		return
	if departure.global_position.distance_to(before_entry) > 0.01:
		_fail("Held runway-entry aircraft must not move into the conflict.")
		return

	traffic.release_segment(entry_blocker)
	entry_blocker.state = "PARKED"
	entry_blocker.position = Vector2(25, 120)
	departure._process(0.10)
	if departure.is_taxi_holding():
		_fail("Runway-entry hold should clear after crossing traffic releases.")
		return
	if departure.global_position.distance_to(before_entry) <= 0.01:
		_fail("Released aircraft should start moving onto the runway.")
		return

	print(
		"Ground movement safety passed: pushback and runway entry both "
		+ "reserve taxi corridors and wait for conflicting arrival traffic."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
