extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var seen: Dictionary = {}
	var times: Dictionary = {}
	for slot in range(DynamicDemandRules.CONDITION_ORDER.size()):
		var timestamp := slot * DynamicDemandRules.SLOT_SECONDS
		var condition := DynamicDemandRules.condition_for(
			"brussels",
			timestamp
		)
		var condition_id := String(condition.get("id", ""))
		seen[condition_id] = true
		times[condition_id] = timestamp

	for expected in [
		"normal",
		"off_peak",
		"surge",
		"seasonal",
		"contract"
	]:
		if not seen.has(expected):
			_fail("Demand cycle should expose %s." % expected)
			return

	var comet := AircraftCatalog.get_profile("comet_c22")
	var brussels := DestinationCatalog.get_destination("brussels")
	var base_plan := FlightRules.create_flight_plan(comet, brussels)
	if base_plan.is_empty():
		_fail("Dynamic demand test flight plan should be valid.")
		return

	var normal := DynamicDemandRules.condition_for(
		"brussels",
		int(times["normal"])
	)
	var surge := DynamicDemandRules.condition_for(
		"brussels",
		int(times["surge"])
	)
	var off_peak := DynamicDemandRules.condition_for(
		"brussels",
		int(times["off_peak"])
	)
	var contract := DynamicDemandRules.condition_for(
		"brussels",
		int(times["contract"])
	)

	var normal_plan := DynamicDemandRules.apply_to_flight_plan(
		base_plan,
		normal
	)
	var surge_plan := DynamicDemandRules.apply_to_flight_plan(
		base_plan,
		surge
	)
	var off_peak_plan := DynamicDemandRules.apply_to_flight_plan(
		base_plan,
		off_peak
	)
	var contract_plan := DynamicDemandRules.apply_to_flight_plan(
		base_plan,
		contract
	)

	var normal_pax := PassengerDemandRules.required_from_plan(
		comet,
		normal_plan,
		0.0
	)
	var surge_pax := PassengerDemandRules.required_from_plan(
		comet,
		surge_plan,
		0.0
	)
	var off_peak_pax := PassengerDemandRules.required_from_plan(
		comet,
		off_peak_plan,
		0.0
	)
	var contract_pax := PassengerDemandRules.required_from_plan(
		comet,
		contract_plan,
		0.0
	)

	var expected_normal_pax := PassengerDemandRules.base_route_requirement(
		comet,
		brussels,
		1.0
	)
	if normal_pax != expected_normal_pax:
		_fail("Normal demand should use the generated Brussels route factor.")
		return
	if surge_pax <= normal_pax:
		_fail("Surge should increase route passenger demand.")
		return
	if off_peak_pax >= normal_pax:
		_fail("Off-Peak should reduce route passenger demand.")
		return
	if contract_pax < surge_pax:
		_fail("Priority Contract should be at least as demanding as Surge.")
		return

	var expected_contract_coins := int(round(
		float(base_plan.get("coin_reward", 0))
		* float(contract.get("coin_multiplier", 1.0))
	))
	var expected_contract_xp := int(round(
		float(base_plan.get("xp_reward", 0))
		* float(contract.get("xp_multiplier", 1.0))
	))
	if int(contract_plan.get("coin_reward", 0)) != expected_contract_coins:
		_fail("Priority Contract should apply its coin multiplier to the generated route reward.")
		return
	if int(contract_plan.get("xp_reward", 0)) != expected_contract_xp:
		_fail("Priority Contract should apply its XP multiplier to the generated route reward.")
		return

	if String(
		contract_plan.get("demand_condition_id", "")
	) != "contract":
		_fail("Flight plan should snapshot the active condition.")
		return
	if int(
		contract_plan.get("demand_condition_ends_at_unix", 0)
	) <= int(times["contract"]):
		_fail("Flight plan should snapshot the condition expiry.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Route History",
		"RTE",
		"NL"
	)
	if profile.is_empty():
		_fail("Route history test profile should be created.")
		return

	var base_coins := int(base_plan.get("coin_reward", 0))
	var base_xp := int(base_plan.get("xp_reward", 0))
	profile = ProfileStore.record_route_completion(
		"brussels",
		normal_pax,
		base_coins,
		base_xp,
		1,
		"normal"
	)
	profile = ProfileStore.record_route_completion(
		"brussels",
		contract_pax,
		expected_contract_coins,
		expected_contract_xp,
		2,
		"contract"
	)
	if profile.is_empty():
		_fail("Route history should persist.")
		return

	var history: Dictionary = profile.get("route_history", {})
	var entry: Dictionary = history.get("brussels", {})
	if int(entry.get("flights_completed", 0)) != 2:
		_fail("Route history should count completed flights.")
		return
	if int(entry.get("passengers_boarded", 0)) != normal_pax + contract_pax:
		_fail("Route history should sum generated boarded passenger counts.")
		return
	if int(entry.get("coins_earned", 0)) != base_coins + expected_contract_coins:
		_fail("Route history should sum generated route coins.")
		return
	if int(entry.get("resources_earned", 0)) != 3:
		_fail("Route history should sum route resources.")
		return

	var counts: Dictionary = entry.get("condition_counts", {})
	if int(counts.get("normal", 0)) != 1:
		_fail("Route history should count Normal flights.")
		return
	if int(counts.get("contract", 0)) != 1:
		_fail("Route history should count Contract flights.")
		return

	_cleanup_profile()
	print(
		"Dynamic demand passed: Normal/Off-Peak/Surge/Seasonal/Contract, "
		+ "snapshot rewards, passenger modifiers, and route history."
	)
	quit(0)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
