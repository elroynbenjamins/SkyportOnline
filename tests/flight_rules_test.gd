extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var slow := AircraftCatalog.get_profile("comet_c22")
	var fast := AircraftCatalog.get_profile("voyager_v32")
	var london := DestinationCatalog.get_destination("berlin")
	var paris := DestinationCatalog.get_destination("paris")

	if slow.is_empty() or fast.is_empty():
		_fail("Approved V1 aircraft profiles should exist.")
		return
	if london.is_empty() or paris.is_empty():
		_fail("Starter Europe destinations should exist.")
		return

	var slow_london := FlightRules.duration_seconds(slow, london)
	var fast_london := FlightRules.duration_seconds(fast, london)

	if slow_london <= fast_london:
		_fail("Slower aircraft type should remain away longer on same route.")
		return
	if slow_london < 180.0:
		_fail("Starter flight timers should no longer be demo-length seconds.")
		return

	var slow_plan := FlightRules.create_flight_plan(slow, paris)
	if slow_plan.is_empty():
		_fail("In-range destination should create a flight plan.")
		return
	if float(slow_plan.get("duration_seconds", 0.0)) <= 0.0:
		_fail("Flight plan should contain a positive timer.")
		return

	var unreachable := {
		"id": "far_test",
		"city": "Far Test",
		"country": "Test",
		"distance_km": 5000.0,
		"coin_reward": 1,
		"xp_reward": 1
	}
	if FlightRules.can_fly(slow, unreachable):
		_fail("Aircraft range should block unreachable destinations.")
		return
	if not FlightRules.create_flight_plan(slow, unreachable).is_empty():
		_fail("Out-of-range destination should not create a flight plan.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("comet_c22")
	plane.assign_flight_plan(slow_plan)

	if plane.aircraft_display_name != String(slow.get("name", "")):
		_fail("Aircraft should expose its configured profile name.")
		return
	if plane.get_flight_plan().is_empty():
		_fail("Aircraft should retain its assigned flight plan.")
		return

	print(
		"Flight timer rules passed: Comet route %s, Voyager route %s."
		% [
			FlightRules.format_duration(slow_london),
			FlightRules.format_duration(fast_london)
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
