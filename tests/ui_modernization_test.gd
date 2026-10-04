extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel_style := GameUIStyle.panel()
	if panel_style.corner_radius_top_left < 8:
		_fail("Shared game panel should use modern rounded corners.")
		return
	if panel_style.shadow_size <= 0:
		_fail("Shared game panel should use depth/shadow.")
		return

	var primary := Button.new()
	GameUIStyle.apply_button(primary, "primary")
	if primary.get_theme_stylebox("normal") == null:
		_fail("Primary game button style should be installed.")
		return

	var hud := HUD.new() if false else null
	# HUD is not a class_name; instantiate its script through the main scene
	# smoke test instead. The rest of the screens can be created directly.

	var world := WorldMapScreen.new()
	root.add_child(world)

	var fleet := FleetScreen.new()
	root.add_child(fleet)

	var event := EventScreen.new()
	root.add_child(event)

	var inventory := ResourceInventoryScreen.new()
	root.add_child(inventory)

	var passenger_upgrade := PassengerUpgradePanel.new()
	root.add_child(passenger_upgrade)

	var service_upgrade := ServiceUpgradePanel.new()
	root.add_child(service_upgrade)

	var return_summary := FlightReturnSummary.new()
	root.add_child(return_summary)

	var setup := AirportSetup.new()
	root.add_child(setup)

	await process_frame

	for screen in [
		world.root,
		fleet.root,
		event.root,
		inventory.root,
		passenger_upgrade.root,
		service_upgrade.root,
		return_summary.root,
		setup.overlay_root
	]:
		if screen == null:
			_fail("Modernized UI screen should build its root control.")
			return

	var selected := Button.new()
	GameUIStyle.apply_button(selected, "selected", true)
	var selected_style := selected.get_theme_stylebox("normal")
	if selected_style == null:
		_fail("Selected game-card style should exist.")
		return

	var event_button := Button.new()
	GameUIStyle.apply_button(event_button, "event", true)
	if event_button.get_theme_stylebox("normal") == null:
		_fail("Event action style should exist.")
		return

	var map := CountryMap.new()
	root.add_child(map)
	await process_frame
	if map.custom_minimum_size.x < 600:
		_fail("Country selection map should remain a dominant visual surface.")
		return

	print(
		"UI modernization passed: shared cards/buttons, all major screens, "
		+ "and game-first country map surface."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
