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

	# HUD has no global class_name; the existing main-scene smoke test
	# validates HUD construction. The remaining screens can be built directly.

	var hud_script := load("res://src/ui/HUD.gd")
	if hud_script == null:
		_fail("HUD script should load for modernization regression.")
		return
	var hud = hud_script.new()
	root.add_child(hud)

	var world := WorldMapScreen.new()
	root.add_child(world)

	var fleet := FleetScreen.new()
	root.add_child(fleet)

	var event := EventScreen.new()
	root.add_child(event)

	var mission_control := MissionPassScreen.new()
	root.add_child(mission_control)

	var social := SocialAirportScreen.new()
	root.add_child(social)

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

	if hud.airport_meta_label == null:
		_fail("Airport HUD should show airport-code/country identity metadata.")
		return
	if hud.xp_progress == null or hud.xp_label == null:
		_fail("Airport HUD should expose visible level XP progression.")
		return
	if hud.bottom_nav_panel == null:
		_fail("Airport HUD should expose a dedicated game action dock.")
		return
	if hud.operation_toast_panel == null:
		_fail("Airport HUD should expose game-style operation feedback toast.")
		return
	if hud.operation_toast_panel.visible:
		_fail("Operation feedback toast should start hidden.")
		return
	hud.set_level_progress(150, 100, 300, false)
	if int(hud.xp_progress.value) != 50 or int(hud.xp_progress.max_value) != 200:
		_fail("HUD XP bar should show progress within the current airport level.")
		return
	if hud.airside_status_chip == null:
		_fail("Airport HUD should expose compact Airfield status chip.")
		return
	if hud.operation_status_chip == null:
		_fail("Airport HUD should expose compact Ground Ops status chip.")
		return
	if hud.atc_status_chip == null:
		_fail("Airport HUD should expose compact ATC status chip.")
		return
	if hud.status_detail_panel == null:
		_fail("Airport HUD should expose contextual status detail drawer.")
		return
	if hud.status_detail_panel.visible:
		_fail("Airport status detail drawer should start collapsed.")
		return
	if hud.catalog_filter_buttons.size() < 6:
		_fail("Build drawer should expose category filter chips.")
		return
	if hud.catalog_close_button == null or hud.catalog_count_label == null:
		_fail("Build drawer should expose close control and availability counter.")
		return
	hud._on_catalog_close_pressed()
	if hud.catalog_panel.visible:
		_fail("Build drawer close control should reveal more of the airport.")
		return
	hud._on_build_navigation_pressed()
	if not hud.catalog_panel.visible:
		_fail("BUILD action dock button should reopen the construction drawer.")
		return
	if hud.social_nav_button == null:
		_fail("Airport HUD should expose the Social network navigation button.")
		return
	hud.set_social_attention(true)
	if not hud.social_nav_button.text.contains("•"):
		_fail("Social nav should visibly flag active visiting traffic.")
		return
	hud.set_social_attention(false)

	if world.screen_title_label == null or not world.screen_title_label.text.contains("ROUTE CONTROL"):
		_fail("World screen should present itself as game-style Route Control.")
		return
	if world.network_meta_label == null or not world.network_meta_label.text.contains("DISPATCH"):
		_fail("Route Control should expose the select-route-dispatch gameplay flow.")
		return
	if world.route_card_label == null:
		_fail("World Map should expose compact Route information card.")
		return
	if world.reward_card_label == null:
		_fail("World Map should expose compact Reward information card.")
		return
	if world.resource_card_label == null:
		_fail("World Map should expose compact Resource information card.")
		return
	if world.aircraft_fit_label == null:
		_fail("World Map should expose compact Aircraft Fit card.")
		return

	if fleet.screen_title_label == null or not fleet.screen_title_label.text.contains("FLEET BAY"):
		_fail("Fleet screen should present itself as the game Fleet Bay.")
		return
	if mission_control.header == null or not mission_control.header.text.contains("MISSION CONTROL"):
		_fail("Mission screen should expose a game-style Mission Control header.")
		return
	if mission_control.header_meta_label == null:
		_fail("Mission Control should separate live pass stats from the screen title.")
		return
	if passenger_upgrade.current_stats_label == null:
		_fail("Passenger upgrade should show Current stat card.")
		return
	if passenger_upgrade.next_stats_label == null:
		_fail("Passenger upgrade should show Next stat card.")
		return

	if service_upgrade.current_stats_label == null:
		_fail("Service upgrade should show Current stat card.")
		return
	if service_upgrade.next_stats_label == null:
		_fail("Service upgrade should show Next stat card.")
		return

	if return_summary.reward_panel == null or return_summary.result_badge_label == null:
		_fail("Flight return should expose a focused game reward panel and result badge.")
		return
	if return_summary.coin_tile_label == null:
		_fail("Flight return should show Coin reward tile.")
		return
	if return_summary.xp_tile_label == null:
		_fail("Flight return should show XP reward tile.")
		return
	if return_summary.mastery_tile_label == null:
		_fail("Flight return should show Mastery reward tile.")
		return

	for screen in [
		world.root,
		fleet.root,
		event.root,
		mission_control.root,
		social.root,
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
	var dock_button := Button.new()
	GameUIStyle.apply_button(dock_button, "dock_selected", true)
	if dock_button.get_theme_stylebox("normal") == null:
		_fail("Airport action dock selected style should exist.")
		return
	var screen_tab := Button.new()
	GameUIStyle.apply_button(screen_tab, "screen_tab_selected", true)
	if screen_tab.get_theme_stylebox("normal") == null:
		_fail("Secondary game screens should share a selected mode-tab style.")
		return

	var map := CountryMap.new()
	root.add_child(map)
	await process_frame
	if map.custom_minimum_size.x < 600:
		_fail("Country selection map should remain a dominant visual surface.")
		return

	print(
		"UI modernization passed: game-style airport HUD/build drawer, Route Control, "
		+ "Fleet Bay, Mission Control, Flight Complete rewards, upgrade cards, "
		+ "and shared control-room styling."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
