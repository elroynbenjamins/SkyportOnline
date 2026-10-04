extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var aerolet_100 := AircraftCatalog.get_profile("aerolet_100")
	var aerolet_120 := AircraftCatalog.get_profile("aerolet_120")
	var regional_200 := AircraftCatalog.get_profile("regional_200")

	var london := DestinationCatalog.get_destination("london")
	var copenhagen := DestinationCatalog.get_destination("copenhagen")

	var slow_london_plan := FlightRules.create_flight_plan(
		aerolet_100,
		london
	)
	var fast_london_plan := FlightRules.create_flight_plan(
		aerolet_120,
		london
	)
	var regional_london_plan := FlightRules.create_flight_plan(
		regional_200,
		london
	)
	var regional_copenhagen_plan := FlightRules.create_flight_plan(
		regional_200,
		copenhagen
	)

	if String(slow_london_plan.get("country_code", "")) != "GB":
		_fail("Flight plans should carry destination country codes.")
		return

	var slow_chance := ResourceDropRules.chance_for_flight(
		aerolet_100,
		slow_london_plan
	)
	var fast_chance := ResourceDropRules.chance_for_flight(
		aerolet_120,
		fast_london_plan
	)
	var regional_chance := ResourceDropRules.chance_for_flight(
		regional_200,
		regional_london_plan
	)
	var longer_regional_chance := ResourceDropRules.chance_for_flight(
		regional_200,
		regional_copenhagen_plan
	)

	if absf(slow_chance - 0.40) > 0.001:
		_fail("Baseline Aerolet 100 London chance should remain 40%.")
		return

	if fast_chance >= slow_chance:
		_fail("Fast aircraft with -20% modifier should lower resource chance.")
		return

	if regional_chance <= slow_chance:
		_fail("Larger aircraft with +20% modifier should raise resource chance.")
		return

	if longer_regional_chance <= regional_chance:
		_fail("Longer travel time should increase resource chance.")
		return

	var london_resources := CountryResourceCatalog.resources_for_country("GB")
	if london_resources.size() != 3:
		_fail("Each configured country should expose exactly three resources.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var rolls := ResourceDropRules.roll_resources(
		aerolet_100,
		slow_london_plan,
		rng
	)

	if rolls.size() != 3:
		_fail("A completed country flight should roll all three resources.")
		return

	var seen_rolls: Dictionary = {}
	for result in rolls:
		if absf(float(result.get("chance", 0.0)) - slow_chance) > 0.001:
			_fail("Every resource should use the same adjusted flight chance.")
			return

		var roll_key := "%.6f" % float(result.get("roll", -1.0))
		seen_rolls[roll_key] = true

	if seen_rolls.size() < 2:
		_fail("Country resources should be rolled independently.")
		return

	rng.seed = 987654321
	var reward := FlightRewardRules.create_return_reward(
		aerolet_100,
		slow_london_plan,
		rng
	)

	if int(reward.get("coins", 0)) != int(london.get("coin_reward", 0)):
		_fail("Return reward should preserve destination coin reward.")
		return

	if int(reward.get("xp", 0)) != int(london.get("xp_reward", 0)):
		_fail("Return reward should preserve destination XP reward.")
		return

	if (reward.get("resource_rolls", []) as Array).size() != 3:
		_fail("Return reward should include all three resource roll results.")
		return

	print(
		"Resource rules passed: baseline %.1f%%, fast %.1f%%, regional %.1f%%, longer regional %.1f%%."
		% [
			slow_chance * 100.0,
			fast_chance * 100.0,
			regional_chance * 100.0,
			longer_regional_chance * 100.0
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
