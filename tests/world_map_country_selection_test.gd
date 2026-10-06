extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.name = "SO-COUNTRY"
	plane.configure_aircraft_type("pico_p8")

	var screen := WorldMapScreen.new()
	root.add_child(screen)
	await process_frame

	var planes: Array[AircraftPrototype] = [plane]
	screen.open_map(
		planes,
		1,
		{},
		30,
		40,
		{},
		"country-selection-test",
		{},
		"NL"
	)

	if screen.selected_country_code != "BE":
		_fail("World Map should default to the first unlocked route country.")
		return
	if screen.selected_destination_id != "brussels":
		_fail("World Map should default to Brussels at level 1.")
		return
	if screen.country_badge_rect.texture == null:
		_fail("Selected country should render its country badge.")
		return
	if screen.country_resource_row.get_child_count() != 3:
		_fail("Selected country should show three visual resource cards.")
		return
	if screen.country_profile_panel == null:
		_fail("World Map should render the selected country in a dedicated profile panel.")
		return
	if not screen.country_status_label.text.contains("CONNECTED"):
		_fail("Unlocked route country should show CONNECTED country status.")
		return
	if not screen.country_network_label.text.contains("1 / 1"):
		_fail("Country profile should summarize unlocked routes versus total routes.")
		return
	if not screen.country_goods_label.text.contains("3 types"):
		_fail("Country profile should summarize its three regional goods.")
		return
	if screen.map_canvas.destinations.size() != DestinationCatalog.all().size():
		_fail("World Map should receive every configured route destination.")
		return
	if screen.map_canvas.selected_destination_id != "brussels":
		_fail("Selected airport marker should stay synced to Brussels.")
		return
	if String(screen.map_canvas.route_preview.get("city", "")) != "Brussels":
		_fail("Map route badge should receive the selected Brussels route.")
		return
	if int(screen.map_canvas.route_preview.get("distance_km", 0)) != 175:
		_fail("Map route badge should show the route's real distance.")
		return
	if String(screen.map_canvas.route_preview.get("duration_text", "")).is_empty():
		_fail("Map route badge should receive formatted flight time.")
		return
	if not screen.map_canvas.route_preview_text().contains("BRUSSELS"):
		_fail("Map route badge summary should identify the selected city.")
		return
	if WorldMapCanvas.GEOGRAPHY_DETAIL_COUNT < 10:
		_fail("World Map should keep detailed islands/coastline geography.")
		return

	var route_phase_before := screen.map_canvas.route_phase
	screen.map_canvas._process(0.5)
	if screen.map_canvas.route_phase <= route_phase_before:
		_fail("Selected international route should animate on the map.")
		return

	screen.map_canvas.zoom_in()
	if screen.map_canvas.zoom_level <= 1.0:
		_fail("World Map should support zooming in.")
		return
	screen.map_canvas.focus_country("DE", 2.05)
	if absf(screen.map_canvas.zoom_level - 2.05) > 0.01:
		_fail("Country focus should apply a close map zoom.")
		return
	var focused_center := screen.map_canvas.view_center
	screen.map_canvas._pan_by_screen_delta(Vector2(20, 0))
	if screen.map_canvas.view_center.is_equal_approx(focused_center):
		_fail("Zoomed World Map should support drag-style panning.")
		return
	screen.map_canvas.reset_view()
	if absf(screen.map_canvas.zoom_level - 1.0) > 0.001:
		_fail("World view reset should return to 100% zoom.")
		return
	if not screen.destination_buttons["brussels"].visible:
		_fail("Selected-country route button should be visible.")
		return
	if screen.destination_buttons["london"].visible:
		_fail("Routes from other countries should be hidden.")
		return

	if WorldMapCanvas.COUNTRY_HIT_RADIUS < 30.0:
		_fail("Country map touch target should remain mobile-friendly.")
		return
	if WorldMapCanvas.SELECTED_HALO_RADIUS < 22.0:
		_fail("Selected country highlight should remain visibly stronger than a normal marker.")
		return
	var belgium := CountryCatalog.get_country("BE")
	var netherlands := CountryCatalog.get_country("NL")
	var raw_be := Vector2(
		float(belgium.get("map_x", 0.0)) * screen.map_canvas.size.x,
		float(belgium.get("map_y", 0.0)) * screen.map_canvas.size.y
	)
	var raw_nl := Vector2(
		float(netherlands.get("map_x", 0.0)) * screen.map_canvas.size.x,
		float(netherlands.get("map_y", 0.0)) * screen.map_canvas.size.y
	)
	var display_be := screen.map_canvas.country_display_position("BE")
	var display_nl := screen.map_canvas.country_display_position("NL")
	if display_be.distance_to(display_nl) <= raw_be.distance_to(raw_nl):
		_fail("Dense Europe markers should be spaced farther apart than raw coordinates.")
		return
	if (
		screen.map_canvas.country_at_position(
			display_be + Vector2(-28, 0)
		) != "BE"
	):
		_fail("Expanded touch target should still select Belgium near its marker.")
		return

	screen._select_country("DE")
	if screen.selected_country_code != "DE":
		_fail("Country marker selection should update selected country.")
		return
	if screen.selected_destination_id != "frankfurt":
		_fail("Germany should preview its first route.")
		return
	if screen.map_canvas.selected_destination_id != "frankfurt":
		_fail("Selected airport marker should stay synced to Frankfurt.")
		return
	var germany_routes := screen.map_canvas._routes_for_selected_country()
	if germany_routes.size() != 2:
		_fail("Germany should expose Frankfurt and Berlin airport markers.")
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
	if not String(
		screen.map_canvas.route_preview.get("status", "")
	).begins_with("LOCKED"):
		_fail("Map route badge should mirror Frankfurt's locked route state.")
		return

	var germany_position := screen.map_canvas.country_display_position("DE")
	var berlin_marker := screen.map_canvas._destination_marker_position(
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
		_fail("Future countries should not keep a route from another country.")
		return
	if not screen.map_canvas.selected_destination_id.is_empty():
		_fail("Future country should clear the selected airport marker.")
		return
	if not screen.map_canvas.route_preview.is_empty():
		_fail("Future country should clear the in-map route briefing badge.")
		return
	if not screen.details_title.text.contains("NO ACTIVE ROUTE"):
		_fail("Future country selection should show a no-route state.")
		return
	if screen.resource_preview_row.get_child_count() != 3:
		_fail("Future countries should still preview all three resources.")
		return
	if screen.country_badge_rect.texture == null:
		_fail("Future countries should still show their country badge.")
		return
	if screen.country_resource_row.get_child_count() != 3:
		_fail("Future countries should keep the three-card country resource strip.")
		return
	if not screen.country_status_label.text.contains("FUTURE NETWORK"):
		_fail("Countries without routes should show a clear FUTURE NETWORK status.")
		return
	if not screen.country_network_label.text.contains("Future"):
		_fail("Country profile network card should identify future-route countries.")
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

	screen._select_country("NL")
	if not screen.country_status_label.text.contains("HOME HUB"):
		_fail("Home country should receive a distinct HOME HUB profile state.")
		return

	print(
		"World Map country selection passed: country-first filtering, larger touch "
		+ "targets, Europe spacing, profile states, zoom/pan, airport markers, "
		+ "animated routes, map route briefing, richer geography, resources, and picker sync."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
