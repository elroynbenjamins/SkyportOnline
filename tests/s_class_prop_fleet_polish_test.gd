extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for aircraft_id in ["comet_c22", "voyager_v32"]:
		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)

		var profile := plane.get_flight_presentation_snapshot()
		if float(profile.get("approach_spawn_distance", 0.0)) < 580.0:
			_fail("%s should use a long visible final approach." % aircraft_id)
			return
		if float(profile.get("climb_out_distance", 0.0)) < 610.0:
			_fail("%s should keep a long visible climb-out." % aircraft_id)
			return

		var route := PackedVector2Array([
			Vector2(0, 0),
			Vector2(200, 0),
			Vector2(260, 60),
			Vector2(330, 100)
		])
		plane.set_arrival_route(route, 1, 2)
		plane.configure_handling_mode(true, false)
		if not plane.stage_for_manual_arrival():
			_fail("%s should stage before LAND." % aircraft_id)
			return

		if aircraft_id == "comet_c22":
			var fx := plane.get_comet_visual_fx_snapshot()
			if not bool(fx.get("engine_running", false)):
				_fail("Comet should show live engine FX.")
				return
			if int(fx.get("propeller_count", 0)) != 1:
				_fail("Comet should expose one animated propeller.")
				return
			if not bool(fx.get("landing_lights", false)):
				_fail("Comet should show landing lights on approach.")
				return
		else:
			var fx := plane.get_voyager_visual_fx_snapshot()
			if not bool(fx.get("engine_running", false)):
				_fail("Voyager should show live engine FX.")
				return
			if int(fx.get("propeller_count", 0)) != 2:
				_fail("Voyager should expose two animated propellers.")
				return
			if not bool(fx.get("landing_lights", false)):
				_fail("Voyager should show landing lights on approach.")
				return

		plane._set_state("WAITING_TAXI_IN")
		if aircraft_id == "comet_c22":
			var fx := plane.get_comet_visual_fx_snapshot()
			if float(fx.get("throttle", 1.0)) > 0.50:
				_fail("Comet should idle after clearing the runway.")
				return
		else:
			var fx := plane.get_voyager_visual_fx_snapshot()
			if float(fx.get("throttle", 1.0)) > 0.50:
				_fail("Voyager should idle after clearing the runway.")
				return

		plane._set_state("TAKEOFF_ROLL")
		plane.takeoff_velocity = plane.takeoff_speed
		if aircraft_id == "comet_c22":
			var fx := plane.get_comet_visual_fx_snapshot()
			if float(fx.get("throttle", 0.0)) < 0.99:
				_fail("Comet should show full propeller activity on takeoff.")
				return
		else:
			var fx := plane.get_voyager_visual_fx_snapshot()
			if float(fx.get("throttle", 0.0)) < 0.99:
				_fail("Voyager should show full propeller activity on takeoff.")
				return

		plane.queue_free()
		await process_frame

	print(
		"S_CLASS_PROP_FLEET_POLISH_OK comet=true voyager=true "
		+ "manual_cycle=true approach=true climb=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
