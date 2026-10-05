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
		"Airport UI takeover passed: concept dock/tray geometry, quiet world labels, "
		+ "and compact aircraft status bubbles."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
