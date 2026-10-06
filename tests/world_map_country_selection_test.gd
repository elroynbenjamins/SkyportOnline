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
	if not screen.destination_buttons["brussels"].visible:
		_fail("Selected-country route button should be visible.")
		return
	if screen.destination_buttons["london"].visible:
		_fail("Routes from other countries should be hidden.")
		return

	screen._select_country("DE")
	if screen.selected_country_code != "DE":
		_fail("Country marker selection should update selected country.")
		return
	if screen.selected_destination_id != "frankfurt":
		_fail("Germany should preview its first route.")
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

	screen._select_country("JP")
	if screen.selected_country_code != "JP":
		_fail("Countries without active routes should still be selectable.")
		return
	if not screen.selected_destination_id.is_empty():
		_fail("Future countries should not keep a route from another country.")
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

	print(
		"World Map country selection passed: country-first filtering, "
		+ "locked-route preview, future-country resources, and picker sync."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
