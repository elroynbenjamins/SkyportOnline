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

	# New shortcut behavior: secondary tools stay available without
	# permanently covering the runway / parked aircraft.
	if (hud.nav_buttons["tools"] as Button).icon == null:
		_fail("Tools expander should have a dedicated icon.")
		return
	for secondary in ["edit", "storage", "social"]:
		if (hud.nav_buttons[secondary] as Button).visible:
			_fail("Secondary actions should start collapsed.")
			return
	(hud.nav_buttons["tools"] as Button).pressed.emit()
	for secondary in ["edit", "storage", "social"]:
		if not (hud.nav_buttons[secondary] as Button).visible:
			_fail("Tools should reveal " + secondary)
			return
	hud.set_social_attention(true)
	hud._collapse_hud_tools()
	if not (hud.nav_buttons["tools"] as Button).text.contains("•"):
		_fail("Collapsed Tools must preserve a social attention indicator.")
		return
	hud.set_social_attention(false)

	# Narrow landscape should clip + allow scrolling rather than pushing
	# action buttons over the bottom contextual strip.
	hud._update_action_rail_layout(Vector2i(980, 500))
	if hud.right_action_rail.offset_bottom > 439.0:
		_fail("Action rail must leave room for the bottom dock.")
		return
	if hud.right_action_scroll == null:
		_fail("Rail needs scroll support on smaller landscape screens.")
		return
	hud._update_action_rail_layout(Vector2i(1280, 720))

	var build_surface := (
		(hud.nav_buttons["build"] as Button).get_theme_stylebox("normal")
	)
	if not (build_surface is StyleBoxFlat):
		_fail("Modern floating rail buttons must not use old heavy tile graphics.")
		return
	if (build_surface as StyleBoxFlat).corner_radius_top_left < 14:
		_fail("Modern rail buttons should have consistently rounded corners.")
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

	var definitions: Array[Dictionary] = [BuildingCatalog.get_definition("small_stand")]
	hud.set_build_catalog(definitions)
	await process_frame
	var stand := hud.catalog_buttons.get("small_stand") as Button
	if stand == null or stand.icon == null:
		_fail("Build cards must display a real thumbnail or game icon fallback.")
		return
	if not stand.text.contains("2×2") or not stand.text.contains("COINS"):
		_fail("Build cards should show price and true grid footprint.")
		return

	hud.set_operation_status("Landing queue clear", "normal")
	if hud.bottom_status_label.text != "Landing queue clear":
		_fail("Bottom contextual strip should show current airport status.")
		return

	# Escape / Android Back should close just the top airport overlay,
	# not accidentally navigate away or confirm a building purchase.
	hud._on_status_chip_pressed("airside")
	if not hud._handle_hud_back() or hud.status_detail_panel.visible:
		_fail("Back should collapse the airfield details panel.")
		return
	hud._on_build_navigation_pressed()
	if not hud._handle_hud_back() or hud.catalog_panel.visible:
		_fail("Back should close the Build drawer.")
		return
	hud._toggle_hud_tools()
	if not hud._handle_hud_back() or hud.tools_expanded:
		_fail("Back should collapse secondary tools.")
		return
	var cancelled: Array[String] = []
	hud.cancel_building_requested.connect(func() -> void: cancelled.append("cancel"))
	hud.enter_building_mode(BuildingCatalog.get_definition("small_stand"))
	if not hud._handle_hud_back() or cancelled.size() != 1:
		_fail("Back during placement should request cancel once.")
		return
	hud.exit_building_mode()
	hud._on_catalog_close_pressed()
	if hud._handle_hud_back():
		_fail("Back must not consume unrelated navigation when no overlay is open.")
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
