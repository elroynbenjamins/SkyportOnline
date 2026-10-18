extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud = load("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	if hud.right_action_rail == null or not hud.right_action_rail.visible:
		_fail("Airport should show the Skyrama-style right action rail.")
		return
	for tab in ["build", "edit", "storage", "fleet", "world", "activities", "social", "more"]:
		var button := hud.nav_buttons.get(tab) as Button
		if button == null or button.icon == null:
			_fail("Missing usable icon shortcut for " + tab)
			return
		if button.custom_minimum_size.y < 44.0:
			_fail("Rail touch targets must remain mobile friendly.")
			return

	var selected_tabs: Array[String] = []
	hud.navigation_requested.connect(func(tab: String) -> void:
		selected_tabs.append(tab)
	)
	(hud.nav_buttons["activities"] as Button).pressed.emit()
	if selected_tabs != ["activities"]:
		_fail("Tasks shortcut must retain the existing Activities navigation.")
		return

	hud._on_build_navigation_pressed()
	await process_frame
	if not hud.catalog_panel.visible or hud.right_action_rail.visible:
		_fail("Construction drawer should hide the shortcut rail.")
		return
	hud._on_catalog_close_pressed()
	await process_frame
	if not hud.right_action_rail.visible:
		_fail("Closing construction drawer should reveal the rail.")
		return

	hud.set_build_catalog([BuildingCatalog.get_definition("small_stand")])
	await process_frame
	var stand := hud.catalog_buttons.get("small_stand") as Button
	if stand == null or not (stand.icon is AtlasTexture):
		_fail("Build cards should use the approved production atlas thumbnail.")
		return
	if not stand.text.contains("2×2") or not stand.text.contains("COINS"):
		_fail("Build cards should show price and true grid footprint.")
		return

	hud.set_operation_status("Landing queue clear", "normal")
	if hud.bottom_status_label.text != "Landing queue clear":
		_fail("Bottom contextual strip should show current airport status.")
		return

	var aircraft := AircraftPrototype.new()
	root.add_child(aircraft)
	await process_frame
	aircraft.configure_skyrama_handling(true)
	aircraft.set_handling_action("UNLOAD")
	var bubble := aircraft.handling_action_button
	if bubble.custom_minimum_size.y < 44.0:
		_fail("Handling action bubbles should keep 44px touch targets.")
		return
	var unload_style := bubble.get_theme_stylebox("normal") as StyleBoxFlat
	if unload_style == null:
		_fail("Handling action skin must expose a glossy rounded panel.")
		return
	var unload_fill := unload_style.bg_color
	aircraft.set_handling_action("SEND")
	var send_style := bubble.get_theme_stylebox("normal") as StyleBoxFlat
	if send_style == null or unload_fill == send_style.bg_color:
		_fail("Send and unload actions need distinct readable colors.")
		return

	print("SKYRAMA_HUD_RAIL_OK rail=true compact_top=true build_art=true actions=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
