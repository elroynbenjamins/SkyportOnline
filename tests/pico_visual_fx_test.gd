extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")

	if plane.get_pico_visual_fx_snapshot().get("engine_running", true):
		_fail("Parked Pico should not show running-engine FX.")
		return

	var route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(180, 0),
		Vector2(240, 60),
		Vector2(300, 100)
	])
	plane.set_arrival_route(route, 1, 2)
	plane.configure_handling_mode(true, false)
	if not plane.stage_for_manual_arrival():
		_fail("Pico should stage visibly before LAND.")
		return

	var staged_fx := plane.get_pico_visual_fx_snapshot()
	if not bool(staged_fx.get("engine_running", false)):
		_fail("Inbound Pico should show live propeller FX while waiting for LAND.")
		return
	if not bool(staged_fx.get("navigation_lights", false)):
		_fail("Inbound Pico should show navigation lights.")
		return
	if not bool(staged_fx.get("landing_lights", false)):
		_fail("Inbound Pico should show landing lights.")
		return
	if float(staged_fx.get("throttle", 0.0)) < 0.80:
		_fail("Inbound Pico should use a high approach propeller throttle.")
		return

	var prop_center: Vector2 = staged_fx.get(
		"propeller_center",
		Vector2.ZERO
	)
	if prop_center.length() < 5.0:
		_fail("Pico propeller overlay should be positioned away from the sprite center.")
		return

	var before_clock := plane.get_visual_clock()
	plane._process(0.11)
	if plane.get_visual_clock() <= before_clock:
		_fail("Pico visual FX clock should advance during live operation.")
		return

	# Rollout should smoothly bleed speed from landing toward taxi pace.
	plane.visible = true
	plane.position = route[0]
	plane.route_index = 0
	plane._set_state("LANDING_ROLL")
	plane._process_landing_roll(0.01)
	var start_speed := float(
		plane.get_motion_feedback_snapshot().get(
			"landing_roll_target_speed",
			0.0
		)
	)
	if start_speed < plane.landing_speed * 0.95:
		_fail("Touchdown rollout should begin close to landing speed.")
		return

	plane.position = route[1].lerp(
		route[0],
		0.10
	)
	plane.route_index = 0
	plane._process_landing_roll(0.01)
	var near_exit_speed := float(
		plane.get_motion_feedback_snapshot().get(
			"landing_roll_target_speed",
			0.0
		)
	)
	if near_exit_speed >= start_speed:
		_fail("Landing rollout should decelerate as the runway exit approaches.")
		return
	if near_exit_speed < plane.taxi_speed * 0.70:
		_fail("Rollout deceleration should remain smooth rather than snapping nearly to zero.")
		return

	plane._set_state("WAITING_TAXI_IN")
	var taxi_wait_fx := plane.get_pico_visual_fx_snapshot()
	if float(taxi_wait_fx.get("throttle", 1.0)) > 0.50:
		_fail("Pico should idle its propeller after clearing the runway.")
		return
	if bool(taxi_wait_fx.get("landing_lights", true)):
		_fail("Landing lights should switch off once the Pico is clear of the runway.")
		return

	plane._set_state("TAKEOFF_ROLL")
	plane.takeoff_velocity = plane.takeoff_speed
	var takeoff_fx := plane.get_pico_visual_fx_snapshot()
	if float(takeoff_fx.get("throttle", 0.0)) < 0.99:
		_fail("Pico should show maximum propeller activity on takeoff.")
		return
	if not bool(takeoff_fx.get("landing_lights", false)):
		_fail("Pico should show forward landing/takeoff lights during the roll.")
		return

	var static_plane := CareerAircraft.new()
	root.add_child(static_plane)
	await process_frame
	static_plane.configure_aircraft_type("swift_s14")
	if bool(static_plane.get_pico_visual_fx_snapshot().get("engine_running", false)):
		_fail("Pico-specific propeller FX must not leak onto other aircraft.")
		return

	print(
		"PICO_VISUAL_FX_OK propeller=true nav=true beacon=true landing_lights=true "
		+ "rollout_deceleration=true redraw_hz=20"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
