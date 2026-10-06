extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_check := CountryCatalog.validate_catalog()
	if not bool(catalog_check.get("valid", false)):
		_fail("Country catalog validation failed: %s" % str(catalog_check.get("errors", [])))
		return

	var countries := CountryCatalog.get_countries()
	if countries.size() < 20:
		_fail("Expected a curated launch roster with at least 20 countries.")
		return

	for country in countries:
		var resources: Array = country.get("resources", [])
		if resources.size() != 3:
			_fail("%s should expose exactly three country resources." % String(country.get("id", "")))
			return

	for destination in DestinationCatalog.all():
		var country_code := String(destination.get("country_code", ""))
		if CountryResourceCatalog.resources_for_country(country_code).size() != 3:
			_fail("Destination country %s has no three-resource definition." % country_code)
			return

	var visual_check := ResourceVisualCatalog.validate_catalog()
	if not bool(visual_check.get("valid", false)):
		_fail(
			"Country resource visual validation failed: %s"
			% str(visual_check.get("errors", []))
		)
		return
	if not FileAccess.file_exists(ResourceVisualCatalog.ATLAS_PATH):
		_fail("Country resource icon atlas is missing.")
		return

	var none := ResourceDropRules.evaluate_resources("NL", [0.40, 0.75, 0.99])
	if _success_count(none) != 0:
		_fail("Rolls at or above 40% should not drop a resource.")
		return

	var two := ResourceDropRules.evaluate_resources("NL", [0.10, 0.399, 0.95])
	if _success_count(two) != 2:
		_fail("Independent resource rolls should be able to award exactly two resources.")
		return

	var all_three := ResourceDropRules.evaluate_resources("NL", [0.00, 0.20, 0.3999])
	if _success_count(all_three) != 3:
		_fail("Independent lucky rolls should be able to award all three resources.")
		return

	var summary := ResourceDropRules.probability_summary()
	if absf(float(summary.get("none", 0.0)) - 0.216) > 0.0001:
		_fail("Three independent 40% rolls should have a 21.6% no-drop chance.")
		return
	if absf(float(summary.get("all_three", 0.0)) - 0.064) > 0.0001:
		_fail("Three independent 40% rolls should have a 6.4% all-three chance.")
		return
	if absf(float(summary.get("expected_resources", 0.0)) - 1.2) > 0.0001:
		_fail("Expected country resources per flight should be 1.2.")
		return

	var london := DestinationCatalog.get_destination("london")
	var aircraft_profile := AircraftCatalog.get_profile("swift_s14")
	var plan := FlightRules.create_flight_plan(aircraft_profile, london)
	if String(plan.get("country_code", "")) != "GB":
		_fail("Flight plans should preserve destination country code.")
		return
	var adjusted_chance := ResourceDropRules.chance_for_flight(
		aircraft_profile,
		plan
	)
	if adjusted_chance >= 0.40:
		_fail("Fast Swift S14 short flight should be below the 40% base.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 847231
	var total_drops := 0
	var trials := 10000
	for _trial in range(trials):
		total_drops += _success_count(
			ResourceDropRules.roll_resources(aircraft_profile, plan, rng)
		)
	var average := float(total_drops) / float(trials)
	var expected_average := 3.0 * adjusted_chance
	if absf(average - expected_average) > 0.05:
		_fail(
			"Seeded drop simulation should match adjusted chance; "
			+ "expected %.3f, got %.3f."
			% [expected_average, average]
		)
		return

	if not bool(ProfileStore.validate_airport_name("Skyhaven International").get("valid", false)):
		_fail("Normal airport names should pass local validation.")
		return
	if not bool(ProfileStore.validate_airport_code("SKY").get("valid", false)):
		_fail("Three-character airport codes should pass validation.")
		return
	if ProfileStore.suggest_airport_code("Skyhaven International") != "SKY":
		_fail("Airport code suggestion should use the first three valid characters.")
		return

	print("Guest airport selection and independent base-40% adjusted resource-drop tests passed.")
	quit(0)


func _success_count(results: Array[Dictionary]) -> int:
	var count := 0
	for result in results:
		if bool(result.get("success", false)):
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
