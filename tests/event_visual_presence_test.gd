extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var base_menu := BuildingCatalog.get_menu_definitions({})
	if _contains_building(base_menu, "autumn_event_flag"):
		_fail("Autumn flag should stay hidden before cosmetic unlock.")
		return
	if _contains_building(base_menu, "autumn_leaf_garden"):
		_fail("Leaf Garden should stay hidden before cosmetic unlock.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Visual Event Test",
		"EVV",
		"NL"
	)
	if profile.is_empty():
		_fail("Event visual test profile should be created.")
		return

	for cosmetic_id in [
		"event_autumn_terminal_skin",
		"event_autumn_airport_border",
		"event_autumn_pico_livery",
		"event_autumn_alliance_flag",
		"event_autumn_leaf_garden"
	]:
		profile = ProfileStore.add_owned_cosmetic(cosmetic_id)
		if profile.is_empty():
			_fail("Cosmetic unlock should persist: %s" % cosmetic_id)
			return

	var cosmetics: Dictionary = profile.get(
		"owned_cosmetics",
		{}
	)
	var unlocked_menu := BuildingCatalog.get_menu_definitions(
		cosmetics
	)
	if not _contains_building(unlocked_menu, "autumn_event_flag"):
		_fail("Unlocked Autumn flag should appear in Build catalog.")
		return
	if not _contains_building(unlocked_menu, "autumn_leaf_garden"):
		_fail("Unlocked Leaf Garden should appear in Build catalog.")
		return

	var now_unix := 1791072000
	var event := EventCatalog.get_event("autumn_airbridge_2026")
	if event.is_empty():
		_fail("Autumn archive event should exist for visual regression.")
		return
	event["enabled"] = true
	event["start_unix"] = 1790812800

	var manager := EventManager.new()
	root.add_child(manager)

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 20.0)

	manager.set_now_override(now_unix)
	manager.configure(economy, event)
	var snapshot := manager.get_snapshot()

	if String(snapshot.get("theme", "")) != "autumn":
		_fail("Autumn visual override should expose autumn theme.")
		return

	grid.set_event_visual_state(snapshot, cosmetics)
	await process_frame

	if String(
		grid.event_visual_snapshot.get("theme", "")
	) != "autumn":
		_fail("AirportGrid should receive Autumn visual state.")
		return
	if not bool(
		grid.event_owned_cosmetics.get(
			"event_autumn_terminal_skin",
			false
		)
	):
		_fail("AirportGrid should receive owned terminal skin cosmetic.")
		return
	if not bool(
		grid.event_owned_cosmetics.get(
			"event_autumn_airport_border",
			false
		)
	):
		_fail("AirportGrid should receive owned airport border cosmetic.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")

	var brussels := DestinationCatalog.get_destination("brussels")
	var plan := FlightRules.create_flight_plan(
		plane.get_aircraft_profile(),
		brussels
	)
	plane.assign_flight_plan(plan)
	plane.set_event_visual(true, "autumn", "+5", true)
	await process_frame

	if not plane.event_featured:
		_fail("Featured route aircraft should carry event marker state.")
		return
	if plane.event_marker_text != "+5":
		_fail("Featured route marker should show +5 voucher reward.")
		return
	if not plane.event_livery_enabled:
		_fail("Owned Harvest Pico livery should enable on Pico P8.")
		return
	if plane.event_theme != "autumn":
		_fail("Featured aircraft should receive Autumn theme.")
		return

	var non_featured_plan := FlightRules.create_flight_plan(
		plane.get_aircraft_profile(),
		DestinationCatalog.get_destination("frankfurt")
	)
	plane.assign_flight_plan(non_featured_plan)
	plane.set_event_visual(false, "autumn", "", true)
	if plane.event_featured:
		_fail("Non-featured route should remove event flight badge.")
		return
	if not plane.event_livery_enabled:
		_fail("Owned event livery should remain independent of route badge.")
		return

	_cleanup_profile()
	print(
		"Event visual presence passed: hidden/unlocked decorations, "
		+ "airport theme cosmetics, featured-flight badge and Pico livery."
	)
	quit(0)


func _contains_building(
	definitions: Array[Dictionary],
	building_id: String
) -> bool:
	for definition in definitions:
		if String(definition.get("id", "")) == building_id:
			return true
	return false


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
