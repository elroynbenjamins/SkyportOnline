extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Service Upgrade Test",
		"SVC",
		"NL"
	)
	if profile.is_empty():
		_fail("Service upgrade test profile should be created.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var base_station := grid.get_best_service_building(
		"cleaning",
		"S"
	)
	if base_station.is_empty():
		_fail("Starter airport should expose cleaning service.")
		return

	if String(
		base_station.get("definition_id", "")
	) != "ground_ops_depot":
		_fail("Starter cleaning should use Ground Operations Depot.")
		return

	if absf(
		float(base_station.get("service_speed", 0.0)) - 1.0
	) > 0.001:
		_fail("Ground Operations Depot Lv1 should use x1.00 speed.")
		return
	if int(base_station.get("vehicle_capacity", 0)) != 1:
		_fail("Ground Operations Depot Lv1 should have one vehicle.")
		return

	var building_uid := int(base_station.get("uid", -1))
	var building := grid.get_building(building_uid)
	var building_key := grid.get_building_key(building)

	var service_upgrade_panel := ServiceUpgradePanel.new()
	root.add_child(service_upgrade_panel)
	await process_frame
	service_upgrade_panel.open_building(
		building,
		{},
		0
	)
	var ground_ops_definition := BuildingCatalog.get_definition(
		"ground_ops_depot"
	)
	if String(
		ground_ops_definition.get("visual_contract", "")
	) != "grid_v1":
		_fail("Ground Ops should use the grid-first visual contract.")
		return
	if ground_ops_definition.has("world_sprite_atlas_path"):
		_fail("Ground Ops should not retain legacy atlas metadata.")
		return
	if service_upgrade_panel.building_image.texture != null:
		_fail(
			"Grid-first reset should keep service upgrade panels free of legacy building art."
		)
		return
	service_upgrade_panel.close_panel()

	var level_2 := ServiceUpgradeCatalog.get_next_level(
		"ground_ops_depot",
		1
	)
	if level_2.is_empty():
		_fail("Ground Operations Depot should have a Lv2 upgrade.")
		return

	profile = _fund_and_apply(
		profile,
		building_key,
		level_2
	)
	if profile.is_empty():
		_fail("Lv2 service upgrade should apply with required resources.")
		return

	grid.set_building_upgrade_level(
		building_uid,
		int(level_2.get("level", 2))
	)

	var level_2_station := grid.get_best_service_building(
		"cleaning",
		"S"
	)
	if absf(
		float(level_2_station.get("service_speed", 0.0)) - 1.10
	) > 0.001:
		_fail("Ground Operations Depot Lv2 should improve speed to x1.10.")
		return
	if int(level_2_station.get("vehicle_capacity", 0)) != 1:
		_fail("Ground Operations Depot Lv2 should still have one vehicle.")
		return

	var level_3 := ServiceUpgradeCatalog.get_next_level(
		"ground_ops_depot",
		2
	)
	profile = _fund_and_apply(
		profile,
		building_key,
		level_3
	)
	if profile.is_empty():
		_fail("Lv3 service upgrade should apply with required resources.")
		return

	grid.set_building_upgrade_level(
		building_uid,
		int(level_3.get("level", 3))
	)

	var level_3_station := grid.get_best_service_building(
		"cleaning",
		"S"
	)
	if absf(
		float(level_3_station.get("service_speed", 0.0)) - 1.15
	) > 0.001:
		_fail("Ground Operations Depot Lv3 should improve speed to x1.15.")
		return
	if int(level_3_station.get("vehicle_capacity", 0)) != 2:
		_fail("Ground Operations Depot Lv3 should add a second vehicle.")
		return

	var loaded := ProfileStore.load_profile()
	var upgrades: Dictionary = loaded.get(
		"building_upgrades",
		{}
	)
	if int(upgrades.get(building_key, 0)) != 3:
		_fail("Service building level should persist in profile.")
		return

	var fresh_grid := AirportGrid.new()
	root.add_child(fresh_grid)
	await process_frame
	fresh_grid.apply_saved_building_upgrades(upgrades)

	var restored := fresh_grid.get_best_service_building(
		"cleaning",
		"S"
	)
	if int(restored.get("upgrade_level", 0)) != 3:
		_fail("Saved service upgrade should restore onto a new airport grid.")
		return
	if int(restored.get("vehicle_capacity", 0)) != 2:
		_fail("Restored Lv3 service building should keep added capacity.")
		return

	var cleaning_stats := ServiceUpgradeCatalog.effective_service_stats(
		"cleaning_center",
		"cleaning",
		3
	)
	if float(cleaning_stats.get("service_speed", 0.0)) <= 1.35:
		_fail("Cleaning Center Lv3 should be faster than its base x1.35.")
		return
	if int(cleaning_stats.get("vehicle_capacity", 0)) != 3:
		_fail("Cleaning Center Lv3 should have three cleaning vans.")
		return

	_cleanup_profile()
	print(
		"Service upgrades passed: resource costs, speed, capacity, "
		+ "and persistence all verified."
	)
	quit(0)


func _fund_and_apply(
	profile: Dictionary,
	building_key: String,
	level_data: Dictionary
) -> Dictionary:
	if level_data.is_empty():
		return {}

	var resource_cost: Dictionary = level_data.get(
		"resource_cost",
		{}
	).duplicate(true)
	var drops: Array[Dictionary] = []
	for resource_id in resource_cost.keys():
		drops.append({
			"id": String(resource_id),
			"amount": int(resource_cost[resource_id])
		})

	if not drops.is_empty():
		profile = ProfileStore.add_resource_drops(drops)
		if profile.is_empty():
			return {}

	return ProfileStore.apply_building_upgrade(
		building_key,
		int(level_data.get("level", 1)),
		resource_cost
	)


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
