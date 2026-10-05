# Visual/game-feel regression for aircraft movement and runway response.
# These cues must remain presentation-only and preserve the existing lifecycle.
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")

	plane._set_state("TAXIING_OUT")
	var snapshot := plane.get_motion_feedback_snapshot()
	if String(snapshot.get("kind", "")) != "taxi_start":
		_fail("Taxi-out should trigger a short movement-start cue.")
		return
	if not bool(snapshot.get("active", false)):
		_fail("Taxi movement feedback should be active immediately after start.")
		return

	plane._set_state("TAKEOFF_ROLL")
	snapshot = plane.get_motion_feedback_snapshot()
	if String(snapshot.get("kind", "")) != "takeoff_start":
		_fail("Takeoff roll should trigger runway acceleration feedback.")
		return

	plane._set_state("CLIMBING")
	snapshot = plane.get_motion_feedback_snapshot()
	if String(snapshot.get("kind", "")) != "rotation":
		_fail("Climb transition should trigger a rotation/liftoff cue.")
		return

	plane._set_state("LANDING_ROLL")
	snapshot = plane.get_motion_feedback_snapshot()
	if String(snapshot.get("kind", "")) != "touchdown":
		_fail("Landing roll should trigger touchdown tire-smoke feedback.")
		return
	if plane._motion_fx_duration() <= AircraftPrototype.MOTION_FX_DURATION:
		_fail("Touchdown feedback should linger slightly longer than generic motion cues.")
		return

	plane._set_state("PUSHBACK_PREP")
	plane._process(0.05)
	plane.global_position += Vector2(5, 0)
	plane._process(0.05)
	snapshot = plane.get_motion_feedback_snapshot()
	if not bool(snapshot.get("pushback_motion", false)):
		_fail("Externally towed aircraft should expose live pushback motion.")
		return
	if String(snapshot.get("kind", "")) != "pushback":
		_fail("Physical pushback should trigger the tug/rolling feedback cue.")
		return
	if float(snapshot.get("external_speed", 0.0)) <= 0.0:
		_fail("Pushback feedback should expose non-zero external movement speed.")
		return

	if not plane.has_method("_draw_motion_feedback"):
		_fail("Directional aircraft renderer should retain the shared motion FX layer.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a departure runway for visual feedback.")
		return
	var runway_uid := int(routes[0].get("runway_uid", -1))
	if runway_uid < 0:
		_fail("Starter departure route should identify a runway.")
		return

	var active_state := {
		"runway_uid": runway_uid,
		"status": "occupied_departure",
		"stop_bar": "red",
		"active_operation": "departure",
		"waiting_arrivals": 0,
		"waiting_departures": 0,
		"taxiing_departures": 0,
		"arrival_priority": false
	}
	grid.set_runway_visual_state(runway_uid, active_state)
	var runway_snapshot := grid.get_runway_feedback_snapshot(runway_uid)
	if not bool(runway_snapshot.get("active", false)):
		_fail("Occupied departure runway should activate edge-light response.")
		return
	var first_pulse := float(runway_snapshot.get("pulse", 0.0))
	if first_pulse <= 0.0:
		_fail("Active runway should expose a visible light pulse.")
		return

	grid._process(0.17)
	runway_snapshot = grid.get_runway_feedback_snapshot(runway_uid)
	var second_pulse := float(runway_snapshot.get("pulse", 0.0))
	if is_equal_approx(first_pulse, second_pulse):
		_fail("Runway edge-light pulse should advance while an operation is active.")
		return
	if not grid.has_method("_draw_runway_activity_edge_lights"):
		_fail("Airport grid should retain the state-driven runway edge-light renderer.")
		return

	var clear_state := {
		"runway_uid": runway_uid,
		"status": "clear",
		"stop_bar": "off",
		"active_operation": "",
		"waiting_arrivals": 0,
		"waiting_departures": 0,
		"taxiing_departures": 0,
		"arrival_priority": false
	}
	grid.set_runway_visual_state(runway_uid, clear_state)
	runway_snapshot = grid.get_runway_feedback_snapshot(runway_uid)
	if bool(runway_snapshot.get("active", true)):
		_fail("Clear runway should return edge lights to their quiet idle state.")
		return
	if float(runway_snapshot.get("pulse", -1.0)) != 0.0:
		_fail("Clear runway should not keep an operational pulse active.")
		return

	print(
		"AIRCRAFT_RUNWAY_MOTION_FEEDBACK_OK "
		+ "taxi=true takeoff=true touchdown=true pushback=true runway_lights=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
