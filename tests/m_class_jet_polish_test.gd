extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for aircraft_id in ["arrow_a52", "atlas_a64"]:
		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)

		if plane.aircraft_size != "M":
			_fail("%s should remain M-class." % aircraft_id)
			return

		var profile := plane.get_flight_presentation_snapshot()
		if float(profile.get("approach_spawn_distance", 0.0)) < 700.0:
			_fail("%s should use a long regional jet approach." % aircraft_id)
			return
		if float(profile.get("climb_out_distance", 0.0)) < 760.0:
			_fail("%s should retain a long visible jet climb-out." % aircraft_id)
			return

		var route := PackedVector2Array([
			Vector2(0, 0),
			Vector2(260, 0),
			Vector2(340, 90),
			Vector2(430, 140)
		])
		plane.set_arrival_route(route, 1, 2)
		plane.configure_handling_mode(true, false)
		if not plane.stage_for_manual_arrival():
			_fail("%s should reuse the manual LAND gate." % aircraft_id)
			return

		var fx := plane.get_m_class_jet_fx_snapshot()
		if not bool(fx.get("engine_running", false)):
			_fail("%s should expose live jet engine FX." % aircraft_id)
			return
		if int(fx.get("engine_count", 0)) != 2:
			_fail("%s should expose two jet-engine positions." % aircraft_id)
			return
		if String(fx.get("size_class", "")) != "M":
			_fail("%s should retain M-class visual identity." % aircraft_id)
			return
		if not bool(fx.get("landing_lights", false)):
			_fail("%s should show landing lights on approach." % aircraft_id)
			return

		plane._set_state("WAITING_TAXI_IN")
		fx = plane.get_m_class_jet_fx_snapshot()
		if float(fx.get("throttle", 1.0)) > 0.40:
			_fail("%s should idle jet power after runway exit." % aircraft_id)
			return

		plane._set_state("TAKEOFF_ROLL")
		plane.takeoff_velocity = plane.takeoff_speed
		fx = plane.get_m_class_jet_fx_snapshot()
		if float(fx.get("throttle", 0.0)) < 0.99:
			_fail("%s should show full jet power on takeoff." % aircraft_id)
			return

		if aircraft_id == "arrow_a52":
			if float(profile.get("takeoff_acceleration", 0.0)) <= 130.0:
				_fail("Arrow should feel faster than the heavy Atlas.")
				return
		else:
			if float(profile.get("takeoff_acceleration", 999.0)) >= 130.0:
				_fail("Atlas should accelerate more deliberately than Arrow.")
				return

		plane.queue_free()
		await process_frame

	print(
		"M_CLASS_JET_POLISH_OK arrow=true atlas=true jet_fx=true handling=manual"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
