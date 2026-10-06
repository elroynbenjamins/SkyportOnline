extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("nimbus_n40")
	plane.configure_handling_mode(true, false)

	if plane.aircraft_size != "M":
		_fail("Nimbus N40 should remain the first M-class aircraft.")
		return

	var presentation := plane.get_flight_presentation_snapshot()
	if float(presentation.get("approach_spawn_distance", 0.0)) < 670.0:
		_fail("Nimbus should use a distinctly longer medium-aircraft final approach.")
		return
	if float(presentation.get("climb_out_distance", 0.0)) < 730.0:
		_fail("Nimbus should stay visible through a longer medium-aircraft climb-out.")
		return
	if float(presentation.get("takeoff_acceleration", 999.0)) > 125.0:
		_fail("Nimbus should accelerate more heavily than the starter S aircraft.")
		return

	var handling := plane.get_handling_action_snapshot()
	if String(handling.get("automation_scope", "")) != "M":
		_fail("Nimbus handling automation should expose the M size-class scope.")
		return

	var route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(240, 0),
		Vector2(310, 70),
		Vector2(390, 120)
	])
	plane.set_arrival_route(route, 10, 20)
	if not plane.stage_for_manual_arrival():
		_fail("Nimbus should reuse the manual LAND handling lifecycle.")
		return
	if plane.get_handling_action() != "LAND":
		_fail("Nimbus should still require LAND manually.")
		return

	var fx := plane.get_nimbus_visual_fx_snapshot()
	if not bool(fx.get("engine_running", false)):
		_fail("Nimbus should show live twin-turboprop FX on approach.")
		return
	if int(fx.get("propeller_count", 0)) != 2:
		_fail("Nimbus should expose two animated propellers.")
		return
	if not bool(fx.get("landing_lights", false)):
		_fail("Nimbus should show approach landing lights.")
		return
	if float(fx.get("throttle", 0.0)) < 0.75:
		_fail("Nimbus should use a strong approach propeller setting.")
		return

	var centers: Array = fx.get("propeller_centers", [])
	if centers.size() != 2:
		_fail("Nimbus should expose both propeller centers.")
		return
	if (centers[0] as Vector2).distance_to(centers[1] as Vector2) < 20.0:
		_fail("Nimbus propellers should be visually separated across the wings.")
		return

	plane._set_state("WAITING_TAXI_IN")
	fx = plane.get_nimbus_visual_fx_snapshot()
	if float(fx.get("throttle", 1.0)) > 0.40:
		_fail("Nimbus should settle to a heavier low taxi idle after runway exit.")
		return
	if bool(fx.get("landing_lights", true)):
		_fail("Nimbus landing lights should switch off after clearing the runway.")
		return

	plane._set_state("TAKEOFF_ROLL")
	plane.takeoff_velocity = plane.takeoff_speed
	fx = plane.get_nimbus_visual_fx_snapshot()
	if float(fx.get("throttle", 0.0)) < 0.99:
		_fail("Nimbus should show full twin-prop activity on takeoff.")
		return

	print(
		"NIMBUS_N40_GOLDEN_PATH_OK size=M manual=true twin_prop=true "
		+ "approach=680 climb=740 heavier_motion=true automation_scope=M"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
