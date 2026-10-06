extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("swift_s14")

	var profile := plane.get_flight_presentation_snapshot()
	if float(profile.get("approach_spawn_distance", 0.0)) < 550.0:
		_fail("Swift S14 should use a long visible final approach.")
		return
	if float(profile.get("climb_out_distance", 0.0)) < 580.0:
		_fail("Swift S14 should retain a long visible climb-out.")
		return
	if float(profile.get("approach_speed", 0.0)) <= float(profile.get("landing_speed", 0.0)):
		_fail("Swift approach speed should exceed landing speed.")
		return

	var route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(190, 0),
		Vector2(250, 60),
		Vector2(320, 100)
	])
	plane.set_arrival_route(route, 1, 2)
	plane.configure_handling_mode(true, false)
	if not plane.stage_for_manual_arrival():
		_fail("Swift should stage visibly before LAND.")
		return

	var fx := plane.get_swift_visual_fx_snapshot()
	if not bool(fx.get("engine_running", false)):
		_fail("Inbound Swift should show twin-prop operating FX.")
		return
	if int(fx.get("propeller_count", 0)) != 2:
		_fail("Swift S14 should expose exactly two animated propellers.")
		return
	var centers: Array = fx.get("propeller_centers", [])
	if centers.size() != 2:
		_fail("Swift should expose both directional propeller centers.")
		return
	if (centers[0] as Vector2).distance_to(centers[1] as Vector2) < 10.0:
		_fail("Swift propeller centers should be visibly separated.")
		return
	if not bool(fx.get("navigation_lights", false)):
		_fail("Swift should show navigation lights while operating.")
		return
	if not bool(fx.get("landing_lights", false)):
		_fail("Swift should show landing lights on arrival.")
		return

	plane._set_state("WAITING_TAXI_IN")
	fx = plane.get_swift_visual_fx_snapshot()
	if float(fx.get("throttle", 1.0)) > 0.50:
		_fail("Swift should idle its propellers after clearing the runway.")
		return
	if bool(fx.get("landing_lights", true)):
		_fail("Swift landing lights should switch off clear of the runway.")
		return

	plane._set_state("TAKEOFF_ROLL")
	plane.takeoff_velocity = plane.takeoff_speed
	fx = plane.get_swift_visual_fx_snapshot()
	if float(fx.get("throttle", 0.0)) < 0.99:
		_fail("Swift should use maximum propeller activity on takeoff.")
		return
	if not bool(fx.get("landing_lights", false)):
		_fail("Swift should show forward lights on takeoff roll.")
		return

	var other := CareerAircraft.new()
	root.add_child(other)
	await process_frame
	other.configure_aircraft_type("pico_p8")
	var other_fx := other.get_swift_visual_fx_snapshot()
	if bool(other_fx.get("engine_running", false)):
		_fail("Swift-specific FX must not leak onto the Pico.")
		return

	print(
		"SWIFT_S14_FLIGHT_POLISH_OK approach=true twin_prop=true lights=true climb=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
