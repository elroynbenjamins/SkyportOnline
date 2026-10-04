extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var slow := AircraftCatalog.get_profile("pico_p8")
	var fast := AircraftCatalog.get_profile("swift_s14")
	var brussels := DestinationCatalog.get_destination("brussels")
	var london := DestinationCatalog.get_destination("london")

	if slow.is_empty() or fast.is_empty():
		_fail("V1 Pico and Swift aircraft profiles should exist.")
		return
	if brussels.is_empty() or london.is_empty():
		_fail("Starter Europe destinations should exist.")
		return

	var slow_brussels := FlightRules.duration_seconds(slow, brussels)
	var fast_brussels := FlightRules.duration_seconds(fast, brussels)

	if slow_brussels <= fast_brussels:
		_fail("Slower aircraft type should remain away longer on the same route.")
		return
	if slow_brussels < 180.0:
		_fail("Starter flight timers should no longer be demo-length seconds.")
		return

	var slow_plan := FlightRules.create_flight_plan(slow, brussels)
	if slow_plan.is_empty():
		_fail("Pico P8 should create an in-range Brussels flight plan.")
		return
	if float(slow_plan.get("duration_seconds", 0.0)) <= 0.0:
		_fail("Flight plan should contain a positive timer.")
		return

	var swift_london := FlightRules.create_flight_plan(fast, london)
	if swift_london.is_empty():
		_fail("Swift S14 should reach London at 360 km.")
		return
	if FlightRules.can_fly(slow, london):
		_fail("Pico P8 should not reach London with its 320 km range.")
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
	plane.configure_aircraft_type("pico_p8")
	plane.assign_flight_plan(slow_plan)

	if plane.aircraft_display_name != String(slow.get("name", "")):
		_fail("Aircraft should expose its configured profile name.")
		return
	if plane.get_flight_plan().is_empty():
		_fail("Aircraft should retain its assigned flight plan.")
		return

	plane.clear_flight_plan()
	if not plane.get_flight_plan().is_empty():
		_fail("Returned aircraft should be able to clear its completed flight plan.")
		return

	print(
		"Flight timer rules passed: Pico Brussels %s, Swift Brussels %s."
		% [
			FlightRules.format_duration(slow_brussels),
			FlightRules.format_duration(fast_brussels)
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
