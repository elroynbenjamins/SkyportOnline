extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var definition := BuildingCatalog.get_definition(
		"atc_tower"
	)
	if definition.is_empty():
		_fail("ATC Tower building should exist.")
		return
	if int(definition.get("level", 0)) != 9:
		_fail("ATC Tower should unlock at airport Lv9.")
		return
	if int(definition.get("cost", 0)) != 55000:
		_fail("ATC Tower should cost 55,000 coins.")
		return
	if not bool(
		definition.get("air_traffic_control", false)
	):
		_fail("ATC Tower should be flagged as air traffic control.")
		return

	var base_grid := AirportGrid.new()
	root.add_child(base_grid)
	await process_frame
	var base_dispatcher := RunwayDispatcher.new()
	root.add_child(base_dispatcher)
	base_dispatcher.configure(base_grid)
	if absf(
		base_dispatcher.get_separation_multiplier() - 1.0
	) > 0.001:
		_fail("Airport without ATC Tower should retain baseline x1.00 spacing.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.select_parcel("east")
	grid.purchase_selected()

	var placed: Dictionary = {}
	for y in range(8, 15):
		for x in range(16, 23):
			var preview := grid.set_build_preview(
				"atc_tower",
				grid.tile_to_world(Vector2(x, y)),
				0
			)
			if not bool(preview.get("valid", false)):
				continue
			placed = grid.confirm_build_preview()
			break
		if not placed.is_empty():
			break

	if placed.is_empty():
		_fail("ATC Tower should be placeable on expanded east parcel.")
		return

	var tower := grid.get_best_air_traffic_control()
	if tower.is_empty():
		_fail("Placed ATC Tower should be discoverable by airport grid.")
		return
	if absf(
		float(tower.get("separation_multiplier", 1.0)) - 0.92
	) > 0.001:
		_fail("ATC Tower Lv1 should reduce runway separation to x0.92.")
		return

	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	if absf(
		dispatcher.get_separation_multiplier() - 0.92
	) > 0.001:
		_fail("Runway dispatcher should read placed ATC Tower multiplier.")
		return

	var panel := AirTrafficUpgradePanel.new()
	root.add_child(panel)
	await process_frame
	panel.open_building(
		tower,
		{},
		100000
	)
	if not panel.stats_label.text.contains("DEP→DEP 2.3s"):
		_fail("ATC panel should show concrete Lv1 departure spacing.")
		return
	if not panel.stats_label.text.contains("ARR→ARR 4.1s"):
		_fail("ATC panel should show concrete Lv1 arrival spacing.")
		return

	var level_2 := AirTrafficUpgradeCatalog.get_next_level(
		"atc_tower",
		1
	)
	if level_2.is_empty():
		_fail("ATC Tower should have a Lv2 upgrade.")
		return

	var profile := ProfileStore.create_guest_airport(
		"ATC Upgrade Test",
		"ATC",
		"NL"
	)
	if profile.is_empty():
		_fail("ATC upgrade test profile should be created.")
		return

	var resource_cost: Dictionary = level_2.get(
		"resource_cost",
		{}
	).duplicate(true)
	var drops: Array[Dictionary] = []
	for resource_id in resource_cost.keys():
		drops.append({
			"id": String(resource_id),
			"amount": int(resource_cost[resource_id])
		})
	profile = ProfileStore.add_resource_drops(drops)
	if profile.is_empty():
		_fail("ATC upgrade resources should be fundable.")
		return

	var tower_key := grid.get_building_key(tower)
	profile = ProfileStore.apply_building_upgrade(
		tower_key,
		2,
		resource_cost
	)
	if profile.is_empty():
		_fail("ATC Lv2 upgrade should persist using regional resources.")
		return
	if int(
		(profile.get("building_upgrades", {}) as Dictionary).get(
			tower_key,
			0
		)
	) != 2:
		_fail("ATC Tower upgrade level should persist in profile.")
		return

	grid.set_building_upgrade_level(
		int(tower.get("uid", -1)),
		2
	)
	dispatcher.refresh_air_traffic_control()
	if absf(
		dispatcher.get_separation_multiplier() - 0.84
	) > 0.001:
		_fail("ATC Tower Lv2 should reduce separation to x0.84.")
		return

	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		_fail("ATC test airport should retain two departure routes.")
		return

	var runway_uid := int(
		routes[0].get("runway_uid", -1)
	)
	var first := AircraftPrototype.new()
	var second := AircraftPrototype.new()
	root.add_child(first)
	root.add_child(second)

	for index in range(2):
		var aircraft: AircraftPrototype = (
			first if index == 0 else second
		)
		aircraft.configure_aircraft_type("pico_p8")
		aircraft.set_departure_route(
			routes[index]["route"],
			"S",
			int(routes[index].get("stand_uid", -1)),
			runway_uid
		)
		aircraft.assign_flight_plan({
			"destination_id": "atc-%d" % index,
			"city": "ATC Test",
			"duration_seconds": 1.0
		})
		aircraft.mark_service_complete()

	dispatcher.request_departure(first, "ATC-A")
	dispatcher.request_departure(second, "ATC-B")
	first.hold_short_reached.emit()
	second.hold_short_reached.emit()
	first.runway_cleared.emit()

	var initial_required := (
		RunwayPacingRules.DEPARTURE_TO_DEPARTURE * 0.84
	)
	var initial_remaining := dispatcher.get_separation_remaining(
		runway_uid
	)
	if absf(
		initial_remaining - initial_required
	) > 0.01:
		_fail("Lv2 ATC should apply x0.84 to live DEP→DEP spacing.")
		return

	dispatcher._process(0.8)
	var before_upgrade := dispatcher.get_separation_remaining(
		runway_uid
	)
	if before_upgrade <= 1.2:
		_fail("Queued departure should still have spacing before max ATC upgrade.")
		return

	grid.set_building_upgrade_level(
		int(tower.get("uid", -1)),
		4
	)
	dispatcher.refresh_air_traffic_control()
	if absf(
		dispatcher.get_separation_multiplier() - 0.68
	) > 0.001:
		_fail("ATC Tower Lv4 should reduce separation to x0.68.")
		return

	var after_upgrade := dispatcher.get_separation_remaining(
		runway_uid
	)
	if after_upgrade >= before_upgrade:
		_fail("Live ATC upgrade should shorten an already-running separation.")
		return
	if after_upgrade > 0.95 or after_upgrade < 0.85:
		_fail("Lv4 upgrade should leave about 0.9s after 0.8s elapsed.")
		return

	dispatcher._process(1.0)
	if second.state != "CLEARED":
		_fail("Queued departure should clear using improved Lv4 ATC spacing.")
		return

	var snapshot := dispatcher.get_atc_snapshot()
	if int(snapshot.get("atc_level", 0)) != 4:
		_fail("ATC snapshot should expose active Tower Lv4.")
		return
	if absf(
		float(snapshot.get("separation_multiplier", 1.0)) - 0.68
	) > 0.001:
		_fail("ATC snapshot should expose x0.68 separation factor.")
		return

	panel.open_building(
		grid.get_building(
			int(tower.get("uid", -1))
		),
		{},
		1000000
	)
	if not panel.stats_label.text.contains("ARR→ARR 3.1s"):
		_fail("Max ATC panel should show ARR→ARR reduced to about 3.1s.")
		return

	_cleanup_profile()
	print(
		"ATC Tower passed: placement, regional-resource upgrades, "
		+ "live runway pacing reduction, persistence, and UI preview."
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
