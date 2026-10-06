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
	var brussels_factor := PassengerDemandRules.base_load_factor(
		brussels
	)
	var expected_pico_brussels := clampi(
		int(ceil(float(pico.get("passengers", 0)) * brussels_factor)),
		1,
		int(pico.get("passengers", 0))
	)
	if int(pico_brussels.get("route_requirement", 0)) != expected_pico_brussels:
		_fail("Generated Brussels demand should follow its route load factor.")
		return
	if absf(
		float(pico_brussels.get("adjusted_load_factor", 0.0))
		- brussels_factor
	) > 0.001:
		_fail("Preview should expose the generated Brussels load factor.")
		return

	var pico_london := PassengerDemandRules.preview(
		pico,
		london,
		0.0
	)
	var london_factor := PassengerDemandRules.base_load_factor(
		london
	)
	var expected_pico_london := clampi(
		int(ceil(float(pico.get("passengers", 0)) * london_factor)),
		1,
		int(pico.get("passengers", 0))
	)
	if int(pico_london.get("route_requirement", 0)) != expected_pico_london:
		_fail("Generated London demand should follow its route load factor.")
		return

	var mastered_brussels := PassengerDemandRules.preview(
		pico,
		brussels,
		10.0
	)
	var expected_mastered := AircraftMastery.passenger_requirement(
		expected_pico_brussels,
		10.0
	)
	if int(mastered_brussels.get("mastery_requirement", 0)) != expected_mastered:
		_fail("Mastery reduction should apply to generated route demand.")
		return

	var comet_brussels := PassengerDemandRules.preview(
		comet,
		brussels,
		0.0
	)
	var expected_comet_brussels := clampi(
		int(ceil(float(comet.get("passengers", 0)) * brussels_factor)),
		1,
		int(comet.get("passengers", 0))
	)
	if int(comet_brussels.get("route_requirement", 0)) != expected_comet_brussels:
		_fail("Larger aircraft demand should use the same generated route factor.")
		return

	var boosted := PassengerDemandRules.preview(
		pico,
		brussels,
		0.0,
		1.25
	)
	var boosted_factor := clampf(
		brussels_factor * 1.25,
		PassengerDemandRules.MIN_LOAD_FACTOR,
		PassengerDemandRules.MAX_LOAD_FACTOR
	)
	var expected_boosted := clampi(
		int(ceil(float(pico.get("passengers", 0)) * boosted_factor)),
		1,
		int(pico.get("passengers", 0))
	)
	if int(boosted.get("route_requirement", 0)) != expected_boosted:
		_fail("Demand modifiers should scale generated route demand.")
		return

	var capped := PassengerDemandRules.preview(
		pico,
		brussels,
		0.0,
		2.0
	)
	if int(capped.get("route_requirement", 0)) != int(pico.get("passengers", 0)):
		_fail("Demand modifiers should never exceed full seat capacity.")
		return

	var plan := FlightRules.create_flight_plan(pico, brussels)
	if absf(
		float(plan.get("passenger_load_factor", 0.0))
		- brussels_factor
	) > 0.001:
		_fail("Flight plan should snapshot the generated route load factor.")
		return
	if String(
		plan.get("passenger_demand_label", "")
	) != String(brussels.get("demand_label", "")):
		_fail("Flight plan should snapshot the generated route demand label.")
		return

	plan["passenger_demand_modifier"] = 1.25
	if PassengerDemandRules.required_from_plan(
		pico,
		plan,
		0.0
	) != expected_boosted:
		_fail("Boarding should use the generated demand snapshot stored in the plan.")
		return

	print(
		"Passenger demand passed: generated home-relative route factors, "
		+ "Mastery reduction, modifiers and flight-plan snapshot."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
