extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("nimbus_n40")

	if plane.aircraft_size != "M":
		_fail("Nimbus N40 should remain the first M-class aircraft.")
		return

	var profile := plane.get_flight_presentation_snapshot()
	if float(profile.get("approach_spawn_distance", 0.0)) < 680.0:
		_fail("Nimbus should use a longer regional final approach than S-class aircraft.")
		return
	if float(profile.get("climb_out_distance", 0.0)) < 730.0:
		_fail("Nimbus should remain visible through a longer regional climb-out.")
		return
	if float(profile.get("takeoff_acceleration", 999.0)) > 135.0:
		_fail("Nimbus should accelerate more deliberately than the small fast prop fleet.")
		return

	var route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(240, 0),
		Vector2(320, 80),
		Vector2(410, 130)
	])
	plane.set_arrival_route(route, 1, 2)
	plane.configure_handling_mode(true, false)
	if not plane.stage_for_manual_arrival():
		_fail("Nimbus should reuse the manual LAND handling gate.")
		return

	var fx := plane.get_nimbus_visual_fx_snapshot()
	if not bool(fx.get("engine_running", false)):
		_fail("Inbound Nimbus should show live twin-prop FX.")
		return
	if int(fx.get("propeller_count", 0)) != 2:
		_fail("Nimbus should expose exactly two animated propellers.")
		return
	if String(fx.get("size_class", "")) != "M":
		_fail("Nimbus visual snapshot should retain its M-class identity.")
		return
	if not bool(fx.get("landing_lights", false)):
		_fail("Nimbus should show landing lights during approach.")
		return

	plane._set_state("WAITING_TAXI_IN")
	fx = plane.get_nimbus_visual_fx_snapshot()
	if float(fx.get("throttle", 1.0)) > 0.50:
		_fail("Nimbus should settle to low propeller power after runway exit.")
		return

	plane._set_state("TAKEOFF_ROLL")
	plane.takeoff_velocity = plane.takeoff_speed
	fx = plane.get_nimbus_visual_fx_snapshot()
	if float(fx.get("throttle", 0.0)) < 0.99:
		_fail("Nimbus should show maximum propeller activity on takeoff.")
		return

	print(
		"NIMBUS_N40_POLISH_OK size=M approach=heavy twin_prop=true handling=manual"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
