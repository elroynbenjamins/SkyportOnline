extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var aerolet_100 := AircraftCatalog.get_profile("aerolet_100")
	var aerolet_120 := AircraftCatalog.get_profile("aerolet_120")
	var regional_200 := AircraftCatalog.get_profile("regional_200")
	var london := DestinationCatalog.get_destination("london")
	var copenhagen := DestinationCatalog.get_destination("copenhagen")

	var plans := [
		FlightRules.create_flight_plan(aerolet_100, london),
		FlightRules.create_flight_plan(aerolet_120, london),
		FlightRules.create_flight_plan(regional_200, london),
		FlightRules.create_flight_plan(regional_200, copenhagen)
	]
	for plan in plans:
		if plan.is_empty():
			_fail("Expected valid test flight plan.")
			return

	var profiles := [aerolet_100, aerolet_120, regional_200, regional_200]
	for index in range(plans.size()):
		var chance := ResourceDropRules.chance_for_flight(
			profiles[index],
			plans[index]
		)
		if absf(chance - 0.40) > 0.001:
			_fail("Every configured country resource must use a fixed 40% chance.")
			return

	var london_resources := CountryResourceCatalog.resources_for_country("GB")
	if london_resources.size() != 3:
		_fail("Each configured country should expose exactly three resources.")
		return

	var deterministic := ResourceDropRules.evaluate_resources(
		"GB",
		[0.10, 0.40, 0.39]
	)
	var wins := 0
	for result in deterministic:
		if bool(result.get("success", false)):
			wins += 1
	if wins != 2:
		_fail("Independent 40% rolls should support mixed success/failure outcomes.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var rolls := ResourceDropRules.roll_resources(
		aerolet_100,
		plans[0],
		rng
	)
	if rolls.size() != 3:
		_fail("A completed country flight should roll all three resources.")
		return

	var seen_rolls: Dictionary = {}
	for result in rolls:
		if absf(float(result.get("chance", 0.0)) - 0.40) > 0.001:
			_fail("Every resource should report the fixed 40% chance.")
			return
		seen_rolls["%.6f" % float(result.get("roll", -1.0))] = true
	if seen_rolls.size() < 2:
		_fail("Country resources should be rolled independently.")
		return

	rng.seed = 987654321
	var reward := FlightRewardRules.create_return_reward(
		aerolet_100,
		plans[0],
		rng
	)
	if int(reward.get("coins", 0)) != int(london.get("coin_reward", 0)):
		_fail("Return reward should preserve destination coin reward.")
		return
	if int(reward.get("xp", 0)) != int(london.get("xp_reward", 0)):
		_fail("Return reward should preserve destination XP reward.")
		return
	if absf(float(reward.get("resource_chance", 0.0)) - 0.40) > 0.001:
		_fail("Return reward should report a fixed 40% resource chance.")
		return
	if (reward.get("resource_rolls", []) as Array).size() != 3:
		_fail("Return reward should include all three resource roll results.")
		return

	print("Resource rules passed: three independent country rolls at a fixed 40% each.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
