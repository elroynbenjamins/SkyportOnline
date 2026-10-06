extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lv1 := ServiceUpgradeCatalog.effective_fuel_stats(
		"basic_fuel",
		1
	)
	var lv4 := ServiceUpgradeCatalog.effective_fuel_stats(
		"basic_fuel",
		4
	)
	if int(lv1.get("fuel_storage", 0)) != 240:
		_fail("Basic Fuel Lv1 should retain 240 storage.")
		return
	if absf(
		float(lv1.get("fuel_delivery_per_minute", 0.0)) - 1.0
	) > 0.001:
		_fail("Basic Fuel Lv1 should retain +1.0 fuel/min.")
		return
	if int(lv4.get("fuel_storage", 0)) != 480:
		_fail("Basic Fuel Lv4 should double storage to 480.")
		return
	if absf(
		float(lv4.get("fuel_delivery_per_minute", 0.0)) - 1.8
	) > 0.001:
		_fail("Basic Fuel Lv4 should deliver +1.8 fuel/min.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var station := grid.get_best_service_building("fuel", "S")
	if station.is_empty():
		_fail("Starter airport should expose its fuel depot.")
		return
	var uid := int(station.get("uid", -1))
	if not grid.set_building_upgrade_level(uid, 3):
		_fail("Starter fuel depot should accept Lv3 upgrade state.")
		return

	var upgraded := grid.get_best_service_building("fuel", "S")
	if int(upgraded.get("fuel_storage", 0)) != 360:
		_fail("Lv3 Basic Fuel should expose 360 effective storage.")
		return
	if absf(
		float(upgraded.get("fuel_delivery_per_minute", 0.0)) - 1.45
	) > 0.001:
		_fail("Lv3 Basic Fuel should expose +1.45 fuel/min.")
		return

	var economy := FuelEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 180.0)
	if economy.get_capacity() != 360:
		_fail("Fuel economy should use upgraded depot storage.")
		return
	if absf(economy.get_delivery_per_minute() - 1.45) > 0.001:
		_fail("Fuel economy should use upgraded depot delivery rate.")
		return

	grid.set_fuel_status(30, 360)
	var warning := grid.get_fuel_status_snapshot()
	if String(warning.get("level", "")) != "critical":
		_fail("Airport should expose critical visual state at <=10% fuel.")
		return

	grid.set_fuel_status(80, 360)
	warning = grid.get_fuel_status_snapshot()
	if String(warning.get("level", "")) != "low":
		_fail("Airport should expose low visual state at <=25% fuel.")
		return

	grid.set_fuel_status(200, 360)
	warning = grid.get_fuel_status_snapshot()
	if String(warning.get("level", "")) != "normal":
		_fail("Airport fuel warning should clear above 25%.")
		return

	var hud := load("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_fuel_data(30, 360, 1.45)
	if not hud.fuel_rate_label.text.begins_with("CRITICAL"):
		_fail("HUD should label critically low fuel.")
		return
	if String(
		hud.fuel_order_button.get_meta("game_style_key", "")
	) != "danger:full":
		_fail("Critical fuel should promote the emergency order action.")
		return

	hud.set_fuel_data(80, 360, 1.45)
	if not hud.fuel_rate_label.text.begins_with("LOW"):
		_fail("HUD should label low fuel.")
		return

	var panel := ServiceUpgradePanel.new()
	root.add_child(panel)
	await process_frame
	var building := grid.get_building(uid)
	panel.open_building(building, {}, 999999)
	if not panel.current_stats_label.text.contains("Storage 360"):
		_fail("Fuel upgrade panel should show current storage.")
		return
	if not panel.next_stats_label.text.contains("Storage 480"):
		_fail("Fuel upgrade panel should preview next storage.")
		return

	print(
		"Fuel upgrade feedback passed: storage/delivery scaling, "
		+ "economy refresh values, world warnings and HUD states."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
