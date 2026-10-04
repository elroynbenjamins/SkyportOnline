extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw := PackedVector2Array([
		Vector2(0, 0),
		Vector2(80, 0),
		Vector2(80, 80),
		Vector2(160, 80)
	])
	var refined_s := TaxiMotionRules.refined_route(
		raw,
		"S"
	)
	var refined_m := TaxiMotionRules.refined_route(
		raw,
		"M"
	)

	if refined_s.size() <= raw.size():
		_fail("S-class sharp taxi corner should gain smoothing points.")
		return
	if refined_m.size() <= raw.size():
		_fail("M-class sharp taxi corner should gain smoothing points.")
		return
	if refined_s[0] != raw[0] or refined_s[
		refined_s.size() - 1
	] != raw[raw.size() - 1]:
		_fail("Taxi smoothing must preserve route endpoints.")
		return

	var raw_angle := TaxiMotionRules.turn_angle_degrees(
		raw[0],
		raw[1],
		raw[2]
	)
	if absf(raw_angle - 90.0) > 0.01:
		_fail("Reference taxi corner should be 90 degrees.")
		return

	var sharpest_refined := 0.0
	for index in range(1, refined_s.size() - 1):
		sharpest_refined = maxf(
			sharpest_refined,
			TaxiMotionRules.turn_angle_degrees(
				refined_s[index - 1],
				refined_s[index],
				refined_s[index + 1]
			)
		)
	if sharpest_refined >= raw_angle:
		_fail("Refined route should split a hard 90-degree turn.")
		return

	if TaxiMotionRules.corner_speed_factor(90.0) >= (
		TaxiMotionRules.corner_speed_factor(20.0)
	):
		_fail("Sharp taxi corners should use a lower speed factor.")
		return
	if TaxiMotionRules.turn_rate_degrees("M") >= (
		TaxiMotionRules.turn_rate_degrees("S")
	):
		_fail("M-class aircraft should steer more slowly than S-class.")
		return
	if TaxiMotionRules.corner_radius("M") <= (
		TaxiMotionRules.corner_radius("S")
	):
		_fail("M-class aircraft should use a wider taxi corner radius.")
		return

	var steering_plane := AircraftPrototype.new()
	root.add_child(steering_plane)
	steering_plane.configure_aircraft_type("pico_p8")
	steering_plane.position = Vector2.ZERO
	steering_plane.rotation = 0.0
	steering_plane._move_toward_point(
		Vector2(0, 100),
		80.0,
		0.05,
		90.0
	)
	if steering_plane.rotation <= 0.0:
		_fail("Aircraft should begin steering toward the target heading.")
		return
	if steering_plane.rotation >= PI * 0.25:
		_fail("Aircraft steering should not snap instantly to a 90-degree turn.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose an S-class route.")
		return

	var raw_route: PackedVector2Array = routes[0].get(
		"route",
		PackedVector2Array()
	)
	if raw_route.size() < 4:
		_fail("Starter route should include stand, taxiway, and runway.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.set_departure_route(
		raw_route,
		"S",
		int(routes[0].get("stand_uid", -1)),
		int(routes[0].get("runway_uid", -1))
	)

	if plane.departure_route[0] != raw_route[0]:
		_fail("Refined departure route must keep exact stand position.")
		return
	if plane.departure_route[1] != raw_route[1]:
		_fail("First stand-to-taxiway leg must remain exact for pushback.")
		return
	if plane.departure_route[
		plane.departure_route.size() - 1
	] != raw_route[raw_route.size() - 1]:
		_fail("Refined departure route must keep runway end exact.")
		return

	var first_leg := plane.departure_route[0].distance_to(
		plane.departure_route[1]
	)
	var pushback_target := plane.get_pushback_target_position()
	var pushback_distance := plane.departure_route[0].distance_to(
		pushback_target
	)
	if pushback_distance >= first_leg:
		_fail("Pushback must stop before the first taxiway target.")
		return
	if pushback_distance > first_leg * 0.73:
		_fail("Pushback should respect the stand lead-out safety cap.")
		return

	var arrivals := grid.get_arrival_routes("S")
	if arrivals.is_empty():
		_fail("Starter airport should expose an S-class arrival route.")
		return

	var arrival_raw: PackedVector2Array = arrivals[0].get(
		"route",
		PackedVector2Array()
	)
	plane.set_arrival_route(
		arrival_raw,
		int(arrivals[0].get("stand_uid", -1)),
		int(arrivals[0].get("runway_uid", -1))
	)
	if plane.arrival_route[0] != arrival_raw[0]:
		_fail("Arrival refinement must preserve runway start.")
		return
	if plane.arrival_route[1] != arrival_raw[1]:
		_fail("Arrival refinement must preserve runway exit.")
		return
	if plane.arrival_route[
		plane.arrival_route.size() - 1
	] != arrival_raw[arrival_raw.size() - 1]:
		_fail("Arrival refinement must preserve final stand position.")
		return

	print(
		"Taxi motion passed: rounded corners, class steering, "
		+ "stand geometry, and pushback-safe lead-out."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
