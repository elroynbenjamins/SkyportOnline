extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Runway Strategy Test",
		"RST",
		"NL"
	)
	if profile.is_empty():
		_fail("Runway strategy test profile should be created.")
		return

	var single_grid := AirportGrid.new()
	root.add_child(single_grid)
	await process_frame

	var single_runways := single_grid.get_runway_buildings()
	if single_runways.size() != 1:
		_fail("Starter airport should expose one runway.")
		return

	var single_panel := RunwayStrategyPanel.new()
	root.add_child(single_panel)
	await process_frame
	single_panel.open_runway(
		single_runways[0],
		RunwayStrategyRules.ARRIVALS,
		1
	)
	if single_panel.specialization_available:
		_fail("Runway specialization should stay locked with one runway.")
		return
	if not single_panel.arrival_button.disabled:
		_fail("Arrival strategy button should be disabled with one runway.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.select_parcel("east")
	grid.purchase_selected()
	grid.select_parcel("south_east")
	grid.purchase_selected()

	var runway_preview := grid.set_build_preview(
		"regional_runway",
		grid.tile_to_world(Vector2(20, 8)),
		1
	)
	if not bool(runway_preview.get("valid", false)):
		_fail("Regional Runway should fit for specialization test.")
		return
	if grid.confirm_build_preview().is_empty():
		_fail("Regional Runway placement should succeed.")
		return

	for x in range(14, 20):
		var taxi_preview := grid.set_build_preview(
			"taxiway",
			grid.tile_to_world(Vector2(x, 10)),
			0
		)
		if not bool(taxi_preview.get("valid", false)):
			_fail("Strategy taxiway should be placeable at x=%d." % x)
			return
		grid.confirm_build_preview()

	var runways := grid.get_runway_buildings()
	if runways.size() != 2:
		_fail("Specialization test requires two runways.")
		return

	var short_runway: Dictionary = {}
	var regional_runway: Dictionary = {}
	for runway in runways:
		match String(runway.get("definition_id", "")):
			"short_runway":
				short_runway = runway
			"regional_runway":
				regional_runway = runway

	if short_runway.is_empty() or regional_runway.is_empty():
		_fail("Test airport should expose Short and Regional runways.")
		return

	var short_key := String(short_runway.get("building_key", ""))
	var regional_key := String(regional_runway.get("building_key", ""))
	if short_key.is_empty() or regional_key.is_empty():
		_fail("Runways should expose stable building keys.")
		return

	profile = ProfileStore.set_runway_strategy(
		short_key,
		RunwayStrategyRules.DEPARTURES
	)
	if profile.is_empty():
		_fail("Departure runway strategy should persist.")
		return
	profile = ProfileStore.set_runway_strategy(
		regional_key,
		RunwayStrategyRules.ARRIVALS
	)
	if profile.is_empty():
		_fail("Arrival runway strategy should persist.")
		return

	var stored: Dictionary = profile.get(
		"runway_strategies",
		{}
	)
	if String(stored.get(short_key, "")) != RunwayStrategyRules.DEPARTURES:
		_fail("Short runway should persist departure preference.")
		return
	if String(stored.get(regional_key, "")) != RunwayStrategyRules.ARRIVALS:
		_fail("Regional runway should persist arrival preference.")
		return

	var loaded := ProfileStore.load_profile()
	var loaded_strategies: Dictionary = loaded.get(
		"runway_strategies",
		{}
	)
	if loaded_strategies != stored:
		_fail("Runway strategies should survive profile reload.")
		return

	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(
		grid,
		loaded_strategies
	)

	var short_uid := int(short_runway.get("uid", -1))
	var regional_uid := int(regional_runway.get("uid", -1))
	if dispatcher.get_runway_strategy(short_uid) != RunwayStrategyRules.DEPARTURES:
		_fail("Dispatcher should map Short runway to departure preference.")
		return
	if dispatcher.get_runway_strategy(regional_uid) != RunwayStrategyRules.ARRIVALS:
		_fail("Dispatcher should map Regional runway to arrival preference.")
		return

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Specialization airport should retain starter stands.")
		return
	var stand_uid := int(routes[0].get("stand_uid", -1))
	var departure_options := grid.get_departure_route_options_for_stand(
		stand_uid,
		"S"
	)
	if departure_options.size() != 2:
		_fail("Starter stand should have two runway choices.")
		return

	var departure_choice := dispatcher.select_best_runway_option(
		departure_options,
		"departure"
	)
	if int(departure_choice.get("runway_uid", -1)) != short_uid:
		_fail("Idle departure should prefer departure-specialized Short runway.")
		return

	var arrival_options := grid.get_arrival_route_options_for_stand(
		stand_uid,
		"S"
	)
	var arrival_choice := dispatcher.select_best_runway_option(
		arrival_options,
		"arrival"
	)
	if int(arrival_choice.get("runway_uid", -1)) != regional_uid:
		_fail("Idle arrival should prefer arrival-specialized Regional runway.")
		return

	var preferred_arrival_route: Dictionary = {}
	for option in arrival_options:
		if int(option.get("runway_uid", -1)) == regional_uid:
			preferred_arrival_route = option
			break
	if preferred_arrival_route.is_empty():
		_fail("Regional arrival route should exist.")
		return

	var occupying_arrival := AircraftPrototype.new()
	root.add_child(occupying_arrival)
	occupying_arrival.configure_aircraft_type("pico_p8")
	occupying_arrival.set_arrival_route(
		preferred_arrival_route["route"],
		stand_uid,
		regional_uid
	)
	dispatcher.request_arrival(
		occupying_arrival,
		"ARR-BUSY"
	)
	if dispatcher.get_active_count() != 1:
		_fail("Preferred arrival runway should become occupied.")
		return

	var overridden_choice := dispatcher.select_best_runway_option(
		arrival_options,
		"arrival"
	)
	if int(overridden_choice.get("runway_uid", -1)) != short_uid:
		_fail("Congestion should override arrival preference and use free runway.")
		return

	var panel := RunwayStrategyPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open_runway(
		short_runway,
		RunwayStrategyRules.DEPARTURES,
		2
	)
	if not panel.specialization_available:
		_fail("Two-runway airport should unlock specialization controls.")
		return
	if not panel.strategy_label.text.contains("Departures preferred"):
		_fail("Runway panel should show current departure preference.")
		return
	if panel.arrival_button.disabled:
		_fail("Alternative arrival strategy should be selectable.")
		return

	var snapshot := dispatcher.get_atc_snapshot()
	var runway_states: Array = snapshot.get("runways", [])
	var saw_departure_pref := false
	var saw_arrival_pref := false
	for runway_state_variant in runway_states:
		var runway_state: Dictionary = runway_state_variant
		if int(runway_state.get("runway_uid", -1)) == short_uid:
			saw_departure_pref = (
				String(runway_state.get("strategy_label", ""))
				== "DEP PREF"
			)
		elif int(runway_state.get("runway_uid", -1)) == regional_uid:
			saw_arrival_pref = (
				String(runway_state.get("strategy_label", ""))
				== "ARR PREF"
			)
	if not saw_departure_pref or not saw_arrival_pref:
		_fail("ATC snapshot should expose runway preference labels.")
		return

	profile = ProfileStore.set_runway_strategy(
		short_key,
		RunwayStrategyRules.AUTO
	)
	if (
		profile.get("runway_strategies", {}) as Dictionary
	).has(short_key):
		_fail("Returning runway to AUTO should remove explicit saved override.")
		return

	_cleanup_profile()
	print(
		"Runway strategy passed: persistence, specialization UI, idle preferences, "
		+ "ATC labels, and congestion override."
	)
	quit(0)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(
		ProfileStore.SAVE_PATH
	)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
