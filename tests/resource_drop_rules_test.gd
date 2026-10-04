extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pico := AircraftCatalog.get_profile("pico_p8")
	var swift := AircraftCatalog.get_profile("swift_s14")
	var nimbus := AircraftCatalog.get_profile("nimbus_n40")
	var brussels := DestinationCatalog.get_destination("brussels")
	var london := DestinationCatalog.get_destination("london")
	var copenhagen := DestinationCatalog.get_destination("copenhagen")

	var plans := [
		FlightRules.create_flight_plan(pico, brussels),
		FlightRules.create_flight_plan(swift, london),
		FlightRules.create_flight_plan(nimbus, london),
		FlightRules.create_flight_plan(nimbus, copenhagen)
	]
	for plan in plans:
		if plan.is_empty():
			_fail("Expected valid test flight plan.")
			return

	var profiles := [pico, swift, nimbus, nimbus]
	for index in range(plans.size()):
		var chance := ResourceDropRules.chance_for_flight(
			profiles[index],
			plans[index]
		)
		if absf(chance - 0.40) > 0.001:
			_fail("Every configured country resource must use a fixed 40% chance.")
			return

	var belgium_resources := CountryResourceCatalog.resources_for_country("BE")
	if belgium_resources.size() != 3:
		_fail("Each configured country should expose exactly three resources.")
		return

	var deterministic := ResourceDropRules.evaluate_resources(
		"BE",
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
		pico,
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
		pico,
		plans[0],
		rng
	)
	if int(reward.get("coins", 0)) != int(brussels.get("coin_reward", 0)):
		_fail("Return reward should preserve destination coin reward.")
		return
	if int(reward.get("xp", 0)) != int(brussels.get("xp_reward", 0)):
		_fail("Return reward should preserve destination XP reward.")
		return
	if absf(float(reward.get("resource_chance", 0.0)) - 0.40) > 0.001:
		_fail("Return reward should report a fixed 40% resource chance.")
		return
	if (reward.get("resource_rolls", []) as Array).size() != 3:
		_fail("Return reward should include all three resource roll results.")
		return

	print("Resource rules passed for reconciled V1 aircraft: three independent 40% rolls.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
