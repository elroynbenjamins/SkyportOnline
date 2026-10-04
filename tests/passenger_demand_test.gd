extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pico := AircraftCatalog.get_profile("pico_p8")
	var comet := AircraftCatalog.get_profile("comet_c22")
	var brussels := DestinationCatalog.get_destination("brussels")
	var london := DestinationCatalog.get_destination("london")

	if pico.is_empty() or comet.is_empty():
		_fail("V1 aircraft profiles should exist.")
		return
	if brussels.is_empty() or london.is_empty():
		_fail("Starter passenger-demand destinations should exist.")
		return

	var pico_brussels := PassengerDemandRules.preview(
		pico,
		brussels,
		0.0
	)
	if int(pico_brussels.get("route_requirement", 0)) != 6:
		_fail("Fresh Pico P8 should need 6 passengers for Brussels.")
		return
	if int(pico_brussels.get("mastery_requirement", 0)) != 6:
		_fail("Unmastered Brussels demand should remain 6.")
		return
	if absf(
		float(pico_brussels.get("adjusted_load_factor", 0.0)) - 0.65
	) > 0.001:
		_fail("Brussels should use a 65% base load factor.")
		return

	var pico_london := PassengerDemandRules.preview(
		pico,
		london,
		0.0
	)
	if int(pico_london.get("route_requirement", 0)) != 8:
		_fail("Busy London route should fill the 8-seat Pico P8.")
		return

	var mastered_brussels := PassengerDemandRules.preview(
		pico,
		brussels,
		10.0
	)
	if int(mastered_brussels.get("mastery_requirement", 0)) != 5:
		_fail("Star 1 Pico should reduce Brussels demand from 6 to 5.")
		return

	var comet_brussels := PassengerDemandRules.preview(
		comet,
		brussels,
		0.0
	)
	if int(comet_brussels.get("route_requirement", 0)) != 15:
		_fail("Comet C22 should need 15 passengers on Brussels.")
		return

	var boosted := PassengerDemandRules.preview(
		pico,
		brussels,
		0.0,
		1.25
	)
	if int(boosted.get("route_requirement", 0)) != 7:
		_fail("A +25% demand modifier should raise Pico Brussels to 7.")
		return

	var capped := PassengerDemandRules.preview(
		pico,
		brussels,
		0.0,
		2.0
	)
	if int(capped.get("route_requirement", 0)) != 8:
		_fail("Demand modifiers should never exceed full seat capacity.")
		return

	var plan := FlightRules.create_flight_plan(pico, brussels)
	if absf(
		float(plan.get("passenger_load_factor", 0.0)) - 0.65
	) > 0.001:
		_fail("Flight plan should snapshot the route load factor.")
		return
	if String(
		plan.get("passenger_demand_label", "")
	) != "Feeder":
		_fail("Flight plan should snapshot the route demand label.")
		return

	plan["passenger_demand_modifier"] = 1.25
	if PassengerDemandRules.required_from_plan(
		pico,
		plan,
		0.0
	) != 7:
		_fail("Boarding should use the demand snapshot stored in the plan.")
		return

	print(
		"Passenger demand passed: Pico Brussels 6, London 8, "
		+ "Mastery Brussels 5, event-modified Brussels 7."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
