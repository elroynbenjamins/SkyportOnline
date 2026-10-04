extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not AirportAmbienceRules.is_stand_ambience_state("PARKED"):
		_fail("PARKED should render stand ambience.")
		return
	if AirportAmbienceRules.is_stand_ambience_state("TAXIING_OUT"):
		_fail("Taxiing aircraft must not render stand clutter.")
		return
	if not AirportAmbienceRules.profile_for_state(
		"TAKEOFF_ROLL"
	).is_empty():
		_fail("Runway states must have no stand ambience profile.")
		return

	var parked := AirportAmbienceRules.profile_for_state("PARKED")
	if not bool(parked.get("chocks", false)):
		_fail("Parked aircraft should show wheel chocks.")
		return
	if int(parked.get("cones", 0)) < 2:
		_fail("Parked aircraft should show a small safety cone set.")
		return

	var unloading := AirportAmbienceRules.profile_for_state("UNLOADING")
	if int(unloading.get("baggage", 0)) < 3:
		_fail("Unloading should visibly show baggage activity.")
		return
	if int(unloading.get("workers", 0)) < 2:
		_fail("Unloading should visibly show ramp staff.")
		return

	var waiting := AirportAmbienceRules.profile_for_state(
		"WAITING_PASSENGERS"
	)
	if int(waiting.get("passengers", 0)) < 4:
		_fail("Waiting passengers should show a visible passenger queue.")
		return

	var pushback := AirportAmbienceRules.profile_for_state("PUSHBACK_PREP")
	if bool(pushback.get("chocks", true)):
		_fail("Pushback preparation should remove wheel chocks.")
		return
	if not bool(pushback.get("marshaller", false)):
		_fail("Pushback preparation should show a marshaller.")
		return

	if AirportAmbienceRules.size_scale("M") <= (
		AirportAmbienceRules.size_scale("S")
	):
		_fail("Medium aircraft ambience footprint should be larger than Small.")
		return
	if AirportAmbienceRules.worker_count_for("UNLOADING", "M") <= (
		AirportAmbienceRules.worker_count_for("UNLOADING", "S")
	):
		_fail("Medium unloading should use a slightly larger ramp crew.")
		return
	if AirportAmbienceRules.passenger_count_for(
		"WAITING_PASSENGERS",
		"M"
	) <= AirportAmbienceRules.passenger_count_for(
		"WAITING_PASSENGERS",
		"S"
	):
		_fail("Medium passenger queues should read busier than Small.")
		return

	var aircraft := AircraftPrototype.new()
	root.add_child(aircraft)
	aircraft.configure_aircraft_type("pico_p8")

	var route := PackedVector2Array([
		Vector2.ZERO,
		Vector2(30, 0),
		Vector2(60, 0),
		Vector2(90, 0),
		Vector2(120, 0)
	])
	aircraft.set_departure_route(
		route,
		"S",
		1,
		2
	)

	var profile := aircraft.get_ambience_profile()
	if not bool(profile.get("chocks", false)):
		_fail("WAITING_FUEL aircraft should expose chocks via runtime profile.")
		return
	if int(profile.get("worker_count", 0)) != 1:
		_fail("WAITING_FUEL should expose one visible ramp worker.")
		return

	aircraft.begin_ground_service("UNLOADING")
	profile = aircraft.get_ambience_profile()
	if int(profile.get("baggage_count", 0)) < 3:
		_fail("Runtime unloading profile should expose baggage props.")
		return

	aircraft.begin_ground_service("LOADING")
	profile = aircraft.get_ambience_profile()
	if int(profile.get("passenger_count", 0)) < 3:
		_fail("Runtime loading profile should expose passenger figures.")
		return

	aircraft.begin_ground_service("PUSHBACK_PREP")
	profile = aircraft.get_ambience_profile()
	if not bool(profile.get("marshaller", false)):
		_fail("Runtime pushback profile should expose the marshaller.")
		return

	aircraft.assign_flight_plan({
		"destination_id": "ambience-test",
		"city": "Ambience Test",
		"duration_seconds": 10.0
	})
	aircraft.mark_service_complete()
	profile = aircraft.get_ambience_profile()
	if profile.is_empty():
		_fail("Ready-for-departure aircraft should retain minimal stand dressing.")
		return

	aircraft.begin_taxi_to_hold_short()
	if not aircraft.get_ambience_profile().is_empty():
		_fail("Stand ambience must clear immediately when taxi-out starts.")
		return

	print(
		"Aircraft ambience passed: contextual workers, passengers, baggage, "
		+ "cones, chocks and marshaller follow turnaround state."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
