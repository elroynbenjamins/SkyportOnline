extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var airport_key := "contract-test-airport"
	var now_unix := 1800
	var contract := RouteContractRules.active_contract(
		4,
		airport_key,
		now_unix
	)
	if contract.is_empty():
		_fail("Priority Contract should be available at Lv4.")
		return

	if int(contract.get("target_flights", 0)) != 3:
		_fail("Priority Contract should require three returns.")
		return
	if int(contract.get("ends_at_unix", 0)) - int(
		contract.get("starts_at_unix", 0)
	) != 5400:
		_fail("Priority Contract window should be 90 minutes.")
		return

	var bonus_resources: Array = contract.get(
		"bonus_resources",
		[]
	)
	if bonus_resources.size() != 3:
		_fail("Priority Contract should reward a three-resource bundle.")
		return
	if int(bonus_resources[0].get("amount", 0)) != 2:
		_fail("First contract resource should award two units.")
		return

	var destination := DestinationCatalog.get_destination(
		String(contract.get("destination_id", ""))
	)
	var comet := AircraftCatalog.get_profile("comet_c22")
	var plan := FlightRules.create_flight_plan(comet, destination)
	if plan.is_empty():
		_fail("Contract route should be flyable by Comet C22.")
		return

	plan = RouteContractRules.apply_to_flight_plan(
		plan,
		contract,
		{}
	)
	if String(plan.get("priority_contract_id", "")).is_empty():
		_fail("Matching contract route should snapshot contract ID.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Contract Test",
		"CTR",
		"NL"
	)
	if profile.is_empty():
		_fail("Priority Contract persistence profile should be created.")
		return

	for expected in range(1, 4):
		var result := ProfileStore.record_priority_contract_return(
			plan,
			int(contract.get("ends_at_unix", 0)) - 30
		)
		if result.is_empty():
			_fail("Qualifying contract return should record.")
			return
		if int(result.get("progress", 0)) != expected:
			_fail("Contract progress should increment once per return.")
			return
		if expected < 3 and bool(result.get("completed_now", false)):
			_fail("Contract should not complete before third return.")
			return
		if expected == 3 and not bool(
			result.get("completed_now", false)
		):
			_fail("Third qualifying return should complete contract.")
			return

	var duplicate := ProfileStore.record_priority_contract_return(
		plan,
		int(contract.get("ends_at_unix", 0)) - 20
	)
	if bool(duplicate.get("completed_now", false)):
		_fail("Completed contract must never pay completion twice.")
		return
	if int(duplicate.get("progress", 0)) != 3:
		_fail("Completed contract progress should remain capped at three.")
		return

	var reloaded := ProfileStore.load_profile()
	var progress_map: Dictionary = reloaded.get(
		"priority_contract_progress",
		{}
	)
	var contract_id := String(contract.get("id", ""))
	var saved: Dictionary = progress_map.get(contract_id, {})
	if int(saved.get("progress", 0)) != 3:
		_fail("Contract progress should survive profile reload.")
		return
	if not bool(saved.get("completed", false)):
		_fail("Completed contract state should persist.")
		return

	var next_contract := RouteContractRules.active_contract(
		4,
		airport_key,
		int(contract.get("ends_at_unix", 0)) + 1
	)
	var next_destination := DestinationCatalog.get_destination(
		String(next_contract.get("destination_id", ""))
	)
	var expired_plan := FlightRules.create_flight_plan(
		comet,
		next_destination
	)
	expired_plan = RouteContractRules.apply_to_flight_plan(
		expired_plan,
		next_contract,
		{}
	)
	var expired := ProfileStore.record_priority_contract_return(
		expired_plan,
		int(next_contract.get("ends_at_unix", 0)) + 1
	)
	if bool(expired.get("eligible", true)):
		_fail("Return after contract expiry must not count.")
		return

	var screen := WorldMapScreen.new()
	root.add_child(screen)
	await process_frame

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("comet_c22")
	var planes: Array[AircraftPrototype] = [plane]

	var partial_progress := {
		contract_id: {
			"progress": 1,
			"target": 3,
			"completed": false
		}
	}
	screen.set_demand_time_override(now_unix)
	screen.selected_destination_id = String(
		contract.get("destination_id", "")
	)
	screen.open_map(
		planes,
		4,
		{},
		50,
		100,
		{},
		airport_key,
		partial_progress
	)

	var destination_button: Button = screen.destination_buttons.get(
		String(contract.get("destination_id", ""))
	)
	if destination_button == null:
		_fail("Contract destination button should exist.")
		return
	if not destination_button.text.contains("CONTRACT"):
		_fail("Active contract destination should be marked on World Map.")
		return
	if not screen.details_body.text.contains("PRIORITY CONTRACT"):
		_fail("World Map details should show Priority Contract section.")
		return
	if not screen.details_body.text.contains("1/3 successful returns"):
		_fail("World Map should show persisted contract progress.")
		return
	if not screen.details_body.text.contains("Bonus:"):
		_fail("World Map should preview the contract completion bonus.")
		return

	_cleanup_profile()
	print(
		"Priority Contract passed: 90m window, 3 returns, expiry, "
		+ "single completion, persistence, and World Map progress."
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
