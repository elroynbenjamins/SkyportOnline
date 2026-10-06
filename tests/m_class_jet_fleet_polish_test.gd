extends SceneTree


const M_JETS := {
	"arrow_a52": {
		"min_approach": 700.0,
		"min_climb": 780.0,
		"min_accel": 150.0,
		"role": "fast"
	},
	"atlas_a64": {
		"min_approach": 725.0,
		"min_climb": 795.0,
		"max_accel": 120.0,
		"role": "heavy"
	},
	"falcon_f72": {
		"min_approach": 760.0,
		"min_climb": 840.0,
		"min_accel": 158.0,
		"role": "performance"
	},
	"horizon_h88": {
		"min_approach": 800.0,
		"min_climb": 900.0,
		"role": "flagship"
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for aircraft_id_variant in M_JETS.keys():
		var aircraft_id := String(aircraft_id_variant)
		var expected: Dictionary = M_JETS[aircraft_id_variant]

		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)
		plane.configure_handling_mode(true, false)

		if plane.aircraft_size != "M":
			_fail("%s should remain M-class." % aircraft_id)
			return

		var handling := plane.get_handling_action_snapshot()
		if String(handling.get("automation_scope", "")) != "M":
			_fail("%s should expose M automation scope." % aircraft_id)
			return

		var presentation := plane.get_flight_presentation_snapshot()
		if float(presentation.get("approach_spawn_distance", 0.0)) < float(expected.get("min_approach", 0.0)):
			_fail("%s should use its longer regional final approach." % aircraft_id)
			return
		if float(presentation.get("climb_out_distance", 0.0)) < float(expected.get("min_climb", 0.0)):
			_fail("%s should remain visible through its regional climb-out." % aircraft_id)
			return
		if expected.has("min_accel") and float(presentation.get("takeoff_acceleration", 0.0)) < float(expected["min_accel"]):
			_fail("%s should preserve its high-performance takeoff feel." % aircraft_id)
			return
		if expected.has("max_accel") and float(presentation.get("takeoff_acceleration", 999.0)) > float(expected["max_accel"]):
			_fail("%s should preserve its heavier takeoff feel." % aircraft_id)
			return

		var route := PackedVector2Array([
			Vector2(0, 0),
			Vector2(260, 0),
			Vector2(330, 70),
			Vector2(420, 120)
		])
		plane.set_arrival_route(route, 20, 30)
		if not plane.stage_for_manual_arrival():
			_fail("%s should reuse the manual LAND lifecycle." % aircraft_id)
			return
		if plane.get_handling_action() != "LAND":
			_fail("%s should still require LAND manually." % aircraft_id)
			return

		var fx := plane.get_m_jet_visual_fx_snapshot()
		if not bool(fx.get("engine_running", false)):
			_fail("%s should show live jet operating FX on approach." % aircraft_id)
			return
		if int(fx.get("engine_count", 0)) != 2:
			_fail("%s should expose two live jet engines." % aircraft_id)
			return
		if not bool(fx.get("landing_lights", false)):
			_fail("%s should show landing lights on approach." % aircraft_id)
			return
		if float(fx.get("throttle", 0.0)) < 0.60:
			_fail("%s should use meaningful approach thrust." % aircraft_id)
			return

		plane._set_state("WAITING_TAXI_IN")
		fx = plane.get_m_jet_visual_fx_snapshot()
		if float(fx.get("throttle", 1.0)) > 0.30:
			_fail("%s should settle to low jet idle after runway exit." % aircraft_id)
			return
		if bool(fx.get("landing_lights", true)):
			_fail("%s landing lights should switch off after runway exit." % aircraft_id)
			return

		plane._set_state("TAKEOFF_ROLL")
		plane.takeoff_velocity = plane.takeoff_speed
		fx = plane.get_m_jet_visual_fx_snapshot()
		if float(fx.get("throttle", 0.0)) < 0.99:
			_fail("%s should show full takeoff thrust." % aircraft_id)
			return

		plane.queue_free()
		await process_frame

	var arrow := AircraftCatalog.get_profile("arrow_a52")
	var atlas := AircraftCatalog.get_profile("atlas_a64")
	var falcon := AircraftCatalog.get_profile("falcon_f72")
	var horizon := AircraftCatalog.get_profile("horizon_h88")
	if float(falcon.get("takeoff_acceleration", 0.0)) <= float(atlas.get("takeoff_acceleration", 0.0)):
		_fail("Falcon should feel more performance-oriented than Atlas.")
		return
	if float(horizon.get("climb_out_distance", 0.0)) <= float(arrow.get("climb_out_distance", 0.0)):
		_fail("Horizon flagship should have the longest visible climb-out.")
		return

	print(
		"M_CLASS_JET_FLEET_POLISH_OK arrow=true atlas=true falcon=true horizon=true "
		+ "jet_fx=true manual_cycle=true automation_scope=M"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
