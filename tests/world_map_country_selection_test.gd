extends SceneTree

var airport_id := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()

	var main_scene = load("res://src/main/Main.tscn")
	if main_scene == null:
		_fail("Main scene could not load for World Map navigation test.")
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var profile_store = load("res://src/profile/ProfileStore.gd")
	if profile_store == null:
		_fail("ProfileStore script could not load.")
		return

	var profile: Dictionary = profile_store.create_guest_airport(
		"World Map Test",
		"MAP",
		"NL"
	)
	if profile.is_empty():
		_fail("Could not create a World Map test airport.")
		return
	airport_id = String(profile.get("airport_id", ""))

	main._on_airport_created(profile)
	main.airport_setup.close()
	await process_frame

	if main.aircraft_demos.is_empty():
		_fail("World Map test requires the starter aircraft.")
		return

	main._on_navigation_requested("world")
	await process_frame

	var screen = main.world_map
	if screen == null or screen.root == null or not screen.root.visible:
		_fail("World Map should open through the real navigation flow.")
		return

	if screen.selected_country_code != "BE":
		_fail("World Map should default to the first unlocked route country.")
		return
	if screen.selected_destination_id != "brussels":
		_fail("World Map should default to Brussels at level 1.")
		return
	if screen.map_canvas.destinations.is_empty():
		_fail("World Map should receive configured route destinations.")
		return
	if screen.map_canvas.selected_destination_id != "brussels":
		_fail("Map airport selection should sync with Brussels.")
		return
	if not screen.destination_buttons["brussels"].visible:
		_fail("Selected-country route button should be visible.")
		return
	if screen.destination_buttons["london"].visible:
		_fail("Routes from other countries should be hidden.")
		return

	var route_phase_before: float = screen.map_canvas.route_phase
	screen.map_canvas._process(0.5)
	if screen.map_canvas.route_phase <= route_phase_before:
		_fail("Selected international route should animate on the map.")
		return

	screen.map_canvas.zoom_in()
	if screen.map_canvas.zoom_level <= 1.0:
		_fail("World Map zoom controls should increase map zoom.")
		return

	screen.map_canvas.focus_country("DE", 2.05)
	if absf(screen.map_canvas.zoom_level - 2.05) > 0.01:
		_fail("Country focus should apply the requested close zoom.")
		return
	var focused_center: Vector2 = screen.map_canvas.view_center
	screen.map_canvas._pan_by_screen_delta(Vector2(20, 0))
	if screen.map_canvas.view_center.is_equal_approx(focused_center):
		_fail("Zoomed World Map should support drag-style panning.")
		return
	screen.map_canvas.reset_view()
	if absf(screen.map_canvas.zoom_level - 1.0) > 0.001:
		_fail("World view reset should return to 100% zoom.")
		return

	screen._select_country("DE")
	if screen.selected_country_code != "DE":
		_fail("Country marker selection should update selected country.")
		return
	if screen.selected_destination_id != "frankfurt":
		_fail("Germany should preview its first route.")
		return
	if screen.map_canvas.selected_destination_id != "frankfurt":
		_fail("Selected airport marker should sync to Frankfurt.")
		return
	var germany_routes: Array = screen.map_canvas._routes_for_selected_country()
	if germany_routes.size() != 2:
		_fail("Germany should expose both Frankfurt and Berlin map airports.")
		return
	if not screen.destination_buttons["frankfurt"].visible:
		_fail("Frankfurt should appear after selecting Germany.")
		return
	if not screen.destination_buttons["frankfurt"].disabled:
		_fail("Frankfurt should remain visibly level-locked at level 1.")
		return
	if not screen.assign_button.text.contains("UNLOCKS AT LV 2"):
		_fail("Locked country route should explain its unlock level.")
		return

	var germany_country: Dictionary = {}
	for country in screen.map_canvas.countries:
		if String(country.get("id", "")) == "DE":
			germany_country = country
			break
	if germany_country.is_empty():
		_fail("Germany should exist in the map country dataset.")
		return

	var germany_position: Vector2 = screen.map_canvas._country_position(
		germany_country
	)
	var berlin_marker: Vector2 = screen.map_canvas._destination_marker_position(
		germany_position,
		1,
		germany_routes.size()
	)
	screen.map_canvas._begin_pointer(berlin_marker)
	screen.map_canvas._end_pointer(berlin_marker)
	if screen.selected_destination_id != "berlin":
		_fail("Airport marker taps should select the matching route directly.")
		return

	screen._select_country("JP")
	if screen.selected_country_code != "JP":
		_fail("Countries without active routes should still be selectable.")
		return
	if not screen.selected_destination_id.is_empty():
		_fail("Future countries should not keep another country's route.")
		return
	if not screen.map_canvas.selected_destination_id.is_empty():
		_fail("Future country should clear the selected airport marker.")
		return
	if not screen.details_title.text.contains("NO ACTIVE ROUTE"):
		_fail("Future country selection should show a no-route state.")
		return
	if screen.resource_preview_row.get_child_count() != 3:
		_fail("Future countries should still preview all three resources.")
		return
	if not screen.assign_button.disabled:
		_fail("Dispatch should be disabled when the country has no route.")
		return

	var selected_picker_code := String(
		screen.country_picker.get_item_metadata(
			screen.country_picker.selected
		)
	)
	if selected_picker_code != "JP":
		_fail("Country picker should stay synchronized with map selection.")
		return

	main.queue_free()
	await process_frame
	await process_frame
	_cleanup()

	print(
		"World Map country selection passed: country-first filtering, "
		+ "route markers, zoom/pan, motion, locked routes, resources, "
		+ "and picker sync."
	)
	quit(0)


func _cleanup() -> void:
	var profile_store = load("res://src/profile/ProfileStore.gd")
	if profile_store != null:
		var save_path := String(profile_store.SAVE_PATH)
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
	if not airport_id.is_empty():
		var progression_store = load(
			"res://src/progression/AirportProgressionStore.gd"
		)
		if progression_store != null:
			var path := String(progression_store.save_path(airport_id))
			for suffix in ["", ".tmp", ".bak"]:
				if FileAccess.file_exists(path + suffix):
					DirAccess.remove_absolute(path + suffix)


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
