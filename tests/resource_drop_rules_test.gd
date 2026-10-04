extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var swift := AircraftCatalog.get_profile("swift_s14")
	var comet := AircraftCatalog.get_profile("comet_c22")
	var nimbus := AircraftCatalog.get_profile("nimbus_n40")
	var london := DestinationCatalog.get_destination("london")
	var copenhagen := DestinationCatalog.get_destination("copenhagen")

	var swift_london := FlightRules.create_flight_plan(swift, london)
	var comet_london := FlightRules.create_flight_plan(comet, london)
	var nimbus_london := FlightRules.create_flight_plan(nimbus, london)
	var nimbus_copenhagen := FlightRules.create_flight_plan(
		nimbus,
		copenhagen
	)

	for plan in [
		swift_london,
		comet_london,
		nimbus_london,
		nimbus_copenhagen
	]:
		if plan.is_empty():
			_fail("Expected valid V1 resource test flight plan.")
			return

	var swift_chance := ResourceDropRules.chance_for_flight(
		swift,
		swift_london
	)
	var comet_chance := ResourceDropRules.chance_for_flight(
		comet,
		comet_london
	)
	var nimbus_chance := ResourceDropRules.chance_for_flight(
		nimbus,
		nimbus_london
	)
	var longer_nimbus_chance := ResourceDropRules.chance_for_flight(
		nimbus,
		nimbus_copenhagen
	)

	if absf(swift_chance - 0.288) > 0.001:
		_fail("Swift S14 London resource chance should be 28.8%.")
		return
	if comet_chance <= swift_chance:
		_fail("Comet should beat the Swift resource chance.")
		return
	if nimbus_chance <= comet_chance:
		_fail("Medium Nimbus should beat small Comet resource chance.")
		return
	if longer_nimbus_chance <= nimbus_chance:
		_fail("Longer Nimbus flight should further improve resource chance.")
		return

	var london_resources := CountryResourceCatalog.resources_for_country("GB")
	if london_resources.size() != 3:
		_fail("Each configured country should expose exactly three resources.")
		return

	var deterministic := ResourceDropRules.evaluate_resources(
		"GB",
		[0.10, 0.40, 0.39],
		0.40
	)
	var wins := 0
	for result in deterministic:
		if bool(result.get("success", false)):
			wins += 1
	if wins != 2:
		_fail("Independent base-40% rolls should support mixed outcomes.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var rolls := ResourceDropRules.roll_resources(
		swift,
		swift_london,
		rng
	)
	if rolls.size() != 3:
		_fail("A completed country flight should roll all three resources.")
		return

	var seen_rolls: Dictionary = {}
	for result in rolls:
		if absf(
			float(result.get("chance", 0.0)) - swift_chance
		) > 0.001:
			_fail("Every resource should report the adjusted flight chance.")
			return
		seen_rolls[
			"%.6f" % float(result.get("roll", -1.0))
		] = true

	if seen_rolls.size() < 2:
		_fail("Country resources should be rolled independently.")
		return

	rng.seed = 987654321
	var reward := FlightRewardRules.create_return_reward(
		swift,
		swift_london,
		rng
	)
	if int(reward.get("coins", 0)) != int(london.get("coin_reward", 0)):
		_fail("Return reward should preserve destination coin reward.")
		return
	if int(reward.get("xp", 0)) != int(london.get("xp_reward", 0)):
		_fail("Return reward should preserve destination XP reward.")
		return
	if absf(
		float(reward.get("resource_chance", 0.0)) - swift_chance
	) > 0.001:
		_fail("Return reward should report adjusted resource chance.")
		return
	if (reward.get("resource_rolls", []) as Array).size() != 3:
		_fail("Return reward should include all three resource rolls.")
		return

	print(
		"Resource modifiers passed: Swift %.1f%%, Comet %.1f%%, "
		+ "Nimbus %.1f%%, longer Nimbus %.1f%%."
		% [
			swift_chance * 100.0,
			comet_chance * 100.0,
			nimbus_chance * 100.0,
			longer_nimbus_chance * 100.0
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
