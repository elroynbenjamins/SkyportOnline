extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var phase_cases := [
		{"hour": 0, "phase": TimeOfDayRules.PHASE_NIGHT},
		{"hour": 5, "phase": TimeOfDayRules.PHASE_NIGHT},
		{"hour": 6, "phase": TimeOfDayRules.PHASE_DAWN},
		{"hour": 7, "phase": TimeOfDayRules.PHASE_DAWN},
		{"hour": 8, "phase": TimeOfDayRules.PHASE_DAY},
		{"hour": 17, "phase": TimeOfDayRules.PHASE_DAY},
		{"hour": 18, "phase": TimeOfDayRules.PHASE_EVENING},
		{"hour": 20, "phase": TimeOfDayRules.PHASE_EVENING},
		{"hour": 21, "phase": TimeOfDayRules.PHASE_NIGHT},
		{"hour": 23, "phase": TimeOfDayRules.PHASE_NIGHT}
	]

	for item in phase_cases:
		var actual := TimeOfDayRules.phase_for_hour(
			int(item["hour"])
		)
		if actual != String(item["phase"]):
			_fail(
				"Hour %d should map to %s, got %s."
				% [
					int(item["hour"]),
					String(item["phase"]),
					actual
				]
			)
			return

	var day := TimeOfDayRules.profile_for_phase(
		TimeOfDayRules.PHASE_DAY
	)
	var dawn := TimeOfDayRules.profile_for_phase(
		TimeOfDayRules.PHASE_DAWN
	)
	var evening := TimeOfDayRules.profile_for_phase(
		TimeOfDayRules.PHASE_EVENING
	)
	var night := TimeOfDayRules.profile_for_phase(
		TimeOfDayRules.PHASE_NIGHT
	)

	if float((day["world_tint"] as Color).a) != 0.0:
		_fail("Day should not darken the airport.")
		return
	if not (
		float((dawn["world_tint"] as Color).a)
		< float((evening["world_tint"] as Color).a)
		and float((evening["world_tint"] as Color).a)
		< float((night["world_tint"] as Color).a)
	):
		_fail("World tint should strengthen from dawn to evening to night.")
		return
	if not (
		float(day["airfield_light_strength"])
		< float(dawn["airfield_light_strength"])
		and float(dawn["airfield_light_strength"])
		< float(evening["airfield_light_strength"])
		and float(evening["airfield_light_strength"])
		< float(night["airfield_light_strength"])
	):
		_fail("Airfield lights should strengthen as ambient light drops.")
		return
	if not (
		float(day["window_strength"])
		< float(dawn["window_strength"])
		and float(dawn["window_strength"])
		< float(evening["window_strength"])
		and float(evening["window_strength"])
		< float(night["window_strength"])
	):
		_fail("Building windows should brighten toward night.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var overlay := AirportLightingOverlay.new()
	root.add_child(overlay)
	overlay.configure(grid)
	await process_frame

	var inventory := overlay.get_lighting_inventory()
	if int(inventory.get("runways", 0)) != 1:
		_fail("Starter airport lighting should detect one runway.")
		return
	if int(inventory.get("taxiways", 0)) != 3:
		_fail("Starter airport lighting should detect three taxiways.")
		return
	if int(inventory.get("stands", 0)) != 2:
		_fail("Starter airport lighting should detect two stands.")
		return
	if int(inventory.get("window_buildings", 0)) < 4:
		_fail(
			"Starter airport should expose terminal/service buildings for window glow."
		)
		return

	overlay.set_phase_override(TimeOfDayRules.PHASE_NIGHT)
	await process_frame
	var snapshot := overlay.get_snapshot()
	if String(snapshot.get("phase", "")) != TimeOfDayRules.PHASE_NIGHT:
		_fail("Night override should immediately change the visual phase.")
		return
	if String(snapshot.get("source", "")) != "override":
		_fail("Manual time-of-day phase should report override source.")
		return
	if float(snapshot.get("airfield_light_strength", 0.0)) < 0.99:
		_fail("Night override should use full airfield light strength.")
		return
	if float(snapshot.get("floodlight_strength", 0.0)) < 0.85:
		_fail("Night override should strongly enable apron floodlights.")
		return

	overlay.set_phase_override(TimeOfDayRules.PHASE_EVENING)
	await process_frame
	snapshot = overlay.get_snapshot()
	if String(snapshot.get("display_name", "")) != "Evening":
		_fail("Evening override should expose the correct display name.")
		return

	overlay.set_phase_override("invalid")
	snapshot = overlay.get_snapshot()
	if String(snapshot.get("phase", "")) != TimeOfDayRules.PHASE_DAY:
		_fail("Unknown phase overrides should safely normalize to Day.")
		return

	if not TimeOfDayRules.is_low_light(TimeOfDayRules.PHASE_NIGHT):
		_fail("Night should be classified as low-light.")
		return
	if TimeOfDayRules.is_low_light(TimeOfDayRules.PHASE_DAY):
		_fail("Day should not be classified as low-light.")
		return

	print(
		"Time-of-day visuals passed: phase boundaries, palette strengths, "
		+ "airport light inventory and manual overrides."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
