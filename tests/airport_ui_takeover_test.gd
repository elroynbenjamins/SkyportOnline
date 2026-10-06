extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud_script := load("res://src/ui/HUD.gd")
	if hud_script == null:
		_fail("HUD script should load.")
		return
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame

	if hud.bottom_nav_panel == null:
		_fail("Concept HUD should expose the bottom dock.")
		return
	if hud.catalog_panel == null or hud.catalog_panel.visible:
		_fail("Build drawer should start collapsed so the airport remains visible.")
		return
	if hud.parcel_panel == null or hud.parcel_panel.visible:
		_fail("Empty expansion context should not cover the airport.")
		return
	if int(hud.bottom_nav_panel.offset_left) != 16:
		_fail("Bottom dock should use the tighter concept edge margin.")
		return
	if int(hud.bottom_nav_panel.offset_right) != -16:
		_fail("Bottom dock should span the airport like the concept.")
		return
	if not hud.nav_buttons.has("build"):
		_fail("Build dock action should exist.")
		return
	if String((hud.nav_buttons["build"] as Button).text) != "BUILD":
		_fail("Main dock should use clean icon-safe labels instead of emoji placeholders.")
		return
	for tab in ["build", "fleet", "world", "activities", "social", "more"]:
		var nav_button := hud.nav_buttons.get(tab) as Button
		if nav_button == null or nav_button.icon == null:
			_fail("Every compact dock action should expose a real HUD icon: " + tab)
			return
	if (
		hud.passenger_icon == null
		or hud.passenger_icon.texture == null
		or hud.fuel_icon == null
		or hud.fuel_icon.texture == null
		or hud.coins_icon == null
		or hud.coins_icon.texture == null
		or hud.gems_icon == null
		or hud.gems_icon.texture == null
	):
		_fail("Top HUD resource pills should expose dedicated icon art.")
		return
	if (
		hud.airside_status_chip.icon == null
		or hud.operation_status_chip.icon == null
		or hud.atc_status_chip.icon == null
	):
		_fail("Operational status chips should expose dedicated icon badges.")
		return

	if hud.catalog_panel == null:
		_fail("Build tray should exist.")
		return
	if hud.catalog_panel.offset_left < -430:
		_fail("Build tray should be slimmer so more airport remains visible.")
		return
	if hud.catalog_filter_buttons.size() != 6:
		_fail("Build tray should retain six compact concept filters.")
		return
	if hud.catalog_help_label == null or hud.catalog_help_label.visible:
		_fail("Build tray helper copy should not consume permanent screen space.")
		return

	hud._on_build_navigation_pressed()
	if not hud.catalog_panel.visible:
		_fail("BUILD should open the construction drawer on demand.")
		return
	hud._on_build_navigation_pressed()
	if hud.catalog_panel.visible:
		_fail("BUILD should close the construction drawer on a second tap.")
		return

	hud.show_parcel(
		{
			"id": "north",
			"name": "Service Apron",
			"tag": "EXPANSION",
			"purpose": "Additional service space.",
			"owned": false,
			"level": 5,
			"cost": 25000,
			"progression_state": "available"
		},
		7,
		50000
	)
	if not hud.parcel_panel.visible:
		_fail("Selecting expansion land should reveal a compact context card.")
		return
	if hud.parcel_panel.offset_right - hud.parcel_panel.offset_left > 680.0:
		_fail("Expansion context card should no longer span most of the airport.")
		return
	hud.show_parcel({}, 7, 50000)
	if hud.parcel_panel.visible:
		_fail("Clearing parcel selection should collapse expansion context.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var home_label := grid.parcel_labels.get("home") as Label
	var north_label := grid.parcel_labels.get("north") as Label
	var corner_label := grid.parcel_labels.get("north_west") as Label
	if home_label == null or home_label.visible:
		_fail("Owned airport parcels should not carry permanent map labels.")
		return
	if north_label == null or not north_label.visible:
		_fail("The connected next expansion should remain discoverable.")
		return
	if corner_label == null or corner_label.visible:
		_fail("Distant future districts should stay quiet until selected.")
		return
	grid.select_parcel("north_west")
	if not corner_label.visible:
		_fail("Selected future land should reveal its label.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	await process_frame
	plane.set_turnaround_status(
		"Passengers 20 / 40\nWAITING",
		"warning"
	)
	if plane.turnaround_panel == null:
		_fail("Aircraft should expose a compact status bubble.")
		return
	if plane.turnaround_panel.custom_minimum_size.x > 120.0:
		_fail("Aircraft status bubble should no longer be an oversized world panel.")
		return
	if plane.turnaround_panel.custom_minimum_size.y > 32.0:
		_fail("Aircraft status bubble should remain one compact line.")
		return
	if plane.turnaround_label.text.contains("\n"):
		_fail("Aircraft status bubble should collapse multiline status into one line.")
		return
	if plane.turnaround_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_fail("Aircraft status bubble should not grow vertically from wrapping.")
		return

	print(
		"Airport UI takeover passed: compact dock, on-demand drawers, quiet world labels, "
		+ "and compact aircraft status bubbles."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
