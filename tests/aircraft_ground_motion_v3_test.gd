extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var corner_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(80, 0),
		Vector2(80, 80)
	])

	var far_heading := TaxiMotionRules.lookahead_heading(
		corner_route,
		Vector2(12, 0),
		1,
		"S"
	)
	var near_heading := TaxiMotionRules.lookahead_heading(
		corner_route,
		Vector2(68, 0),
		1,
		"S"
	)
	if absf(far_heading) > 0.08:
		_fail("Aircraft should stay aligned with the current taxi leg when far from a bend.")
		return
	if near_heading <= 0.05 or near_heading >= PI * 0.48:
		_fail("Aircraft nose should begin turning before reaching a 90-degree taxi corner.")
		return

	var far_braking := TaxiMotionRules.braking_speed_factor(
		60.0,
		"S"
	)
	var near_braking := TaxiMotionRules.braking_speed_factor(
		6.0,
		"S"
	)
	if near_braking >= far_braking:
		_fail("Taxi speed should reduce progressively as a stop point approaches.")
		return
	if near_braking < 0.20:
		_fail("Taxi braking should remain smooth rather than nearly stopping too early.")
		return

	var final_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(60, 0),
		Vector2(60, 60)
	])
	var final_heading := TaxiMotionRules.endpoint_heading(
		final_route
	)
	if absf(final_heading - PI * 0.5) > 0.01:
		_fail("Endpoint heading should match the final parking centerline.")
		return

	var steering_plane := AircraftPrototype.new()
	root.add_child(steering_plane)
	steering_plane.configure_aircraft_type("pico_p8")
	steering_plane.position = Vector2.ZERO
	steering_plane.rotation = 0.0
	steering_plane._move_toward_point(
		Vector2(100, 0),
		70.0,
		0.10,
		90.0,
		PI * 0.25
	)
	if steering_plane.position.y != 0.0:
		_fail("Heading anticipation must not pull the aircraft off its route centerline.")
		return
	if steering_plane.rotation <= 0.0:
		_fail("Heading override should begin rotating the aircraft nose ahead of the bend.")
		return
	if steering_plane.rotation >= PI * 0.25:
		_fail("Anticipatory steering should remain gradual.")
		return

	var runway_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(30, 0),
		Vector2(60, 0),
		Vector2(70, 10),
		Vector2(80, 20),
		Vector2(160, 20)
	])
	steering_plane.set_departure_route(
		runway_route,
		"S",
		1,
		2
	)
	var runway_heading := steering_plane._departure_runway_heading()
	if absf(runway_heading) > 0.01:
		_fail("Runway-entry heading should align with the runway centerline.")
		return

	var parking_plane := AircraftPrototype.new()
	root.add_child(parking_plane)
	parking_plane.configure_aircraft_type("pico_p8")
	parking_plane.arrival_route = PackedVector2Array([
		Vector2(0, 0),
		Vector2(60, 0),
		Vector2(60, 40),
		Vector2(60, 80)
	])
	parking_plane.route_index = parking_plane.arrival_route.size() - 1
	parking_plane.position = parking_plane.arrival_route[
		parking_plane.route_index
	]
	parking_plane.rotation = 0.0
	parking_plane._process_taxi_in(0.016)
	if parking_plane.state != "PARKED":
		_fail("Aircraft should complete parking when it reaches the final stand point.")
		return
	if absf(parking_plane.rotation - PI * 0.5) > 0.01:
		_fail("Parked aircraft should finish on the stand's exact centerline heading.")
		return

	print(
		"AIRCRAFT_GROUND_MOTION_V3_OK "
		+ "lookahead=true braking=true runway_alignment=true parking_heading=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
