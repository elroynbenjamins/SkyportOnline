extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var passenger_buildings := grid.get_passenger_generator_buildings()
	if passenger_buildings.size() != 1:
		_fail("Starter airport should contain one passenger Travel Office.")
		return

	var office: Dictionary = passenger_buildings[0]
	if String(office.get("definition_id", "")) != "travel_office":
		_fail("Starter passenger generator should be the Travel Office.")
		return

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 20.0)

	if economy.get_capacity() != 40:
		_fail("Travel Office Lv1 should provide 40 passenger storage.")
		return
	if absf(economy.get_production_per_minute() - 1.5) > 0.001:
		_fail("Travel Office Lv1 should produce 1.5 passengers/min.")
		return

	economy._process(60.0)
	if economy.get_passengers() != 21:
		_fail("One minute should add 1.5 passengers from the Lv1 office.")
		return

	if not economy.spend_passengers(18):
		_fail("Passenger stock should be spendable for aircraft boarding.")
		return
	if economy.get_passengers() != 3:
		_fail("Boarding should deduct the aircraft passenger requirement.")
		return
	if economy.spend_passengers(24):
		_fail("Aircraft should wait when passenger stock is insufficient.")
		return

	if not grid.set_building_upgrade_level(
		int(office.get("uid", -1)),
		2
	):
		_fail("Passenger building should accept an internal upgrade level.")
		return
	economy.refresh_building_stats()

	if economy.get_capacity() != 55:
		_fail("Travel Office Lv2 should provide 55 passenger storage.")
		return
	if absf(economy.get_production_per_minute() - 2.2) > 0.001:
		_fail("Travel Office Lv2 should produce 2.2 passengers/min.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Passenger Test",
		"PAX",
		"NL"
	)
	if profile.is_empty():
		_fail("Passenger persistence test profile should be created.")
		return

	var next_upgrade := PassengerUpgradeCatalog.get_next_level(
		"travel_office",
		1
	)
	var upgrade_cost: Dictionary = next_upgrade.get(
		"resource_cost",
		{}
	).duplicate(true)
	var drops: Array[Dictionary] = []
	for resource_id in upgrade_cost.keys():
		drops.append({
			"id": String(resource_id),
			"amount": int(upgrade_cost[resource_id])
		})

	profile = ProfileStore.add_resource_drops(drops)
	if profile.is_empty():
		_fail("Test resources should be added to profile.")
		return

	var building_key := grid.get_building_key(office)
	profile = ProfileStore.apply_building_upgrade(
		building_key,
		2,
		upgrade_cost
	)
	if profile.is_empty():
		_fail("Resource-funded Travel Office upgrade should persist.")
		return

	var inventory: Dictionary = profile.get(
		"resource_inventory",
		{}
	)
	for resource_id in upgrade_cost.keys():
		if int(inventory.get(resource_id, -1)) != 0:
			_fail(
				"Upgrade should consume all required regional resources."
			)
			return

	var upgrades: Dictionary = profile.get("building_upgrades", {})
	if int(upgrades.get(building_key, 0)) != 2:
		_fail("Travel Office upgrade level should persist in profile.")
		return

	profile = ProfileStore.save_passenger_balance(37)
	if int(profile.get("passenger_balance", 0)) != 37:
		_fail("Passenger balance should persist in profile.")
		return

	var reloaded := ProfileStore.load_profile()
	if int(reloaded.get("passenger_balance", 0)) != 37:
		_fail("Passenger balance should survive profile reload.")
		return
	if int(
		(reloaded.get("building_upgrades", {}) as Dictionary).get(
			building_key,
			0
		)
	) != 2:
		_fail("Passenger building upgrade should survive profile reload.")
		return

	_cleanup_profile()
	print(
		"Passenger economy passed: production/storage upgrades, "
		+ "boarding consumption, and resource costs persisted."
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
