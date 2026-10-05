extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var snapshot := grid.get_starter_apron_visual_snapshot()
	if not bool(snapshot.get("active", false)):
		_fail("Default starter airport should render the unified apron.")
		return
	if int(snapshot.get("stand_count", 0)) != 2:
		_fail("Starter apron should include both default Small Stands.")
		return
	if int(snapshot.get("terminal_uid", -1)) <= 0:
		_fail("Starter apron should identify the Small Terminal.")
		return
	if int(snapshot.get("floodlights", 0)) != 4:
		_fail("Starter apron should expose four perimeter floodlights.")
		return
	if int(snapshot.get("service_bays", 0)) != 4:
		_fail("Two starter stands should expose four service staging bays.")
		return

	var origin: Vector2i = snapshot.get("origin", Vector2i(-1, -1))
	var footprint: Vector2i = snapshot.get("footprint", Vector2i.ZERO)
	if origin != Vector2i(8, 10):
		_fail("Starter apron should stop at the western owned-land boundary.")
		return
	if footprint != Vector2i(8, 6):
		_fail("Starter apron should form one compact 8x6 visual slab.")
		return

	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			var parcel := grid._parcel_for_tile(Vector2i(x, y))
			if parcel.is_empty() or not bool(parcel.get("owned", false)):
				_fail("Decorative starter apron must never spill onto unowned land.")
				return

	var stand_definition := BuildingCatalog.get_definition("small_stand")
	var stand_pad := grid._building_ground_color(stand_definition)
	if stand_pad.a >= 0.40:
		_fail("Small Stand ground pad should blend into the unified apron.")
		return

	var terminal_definition := BuildingCatalog.get_definition("small_terminal")
	var terminal_pad := grid._building_ground_color(terminal_definition)
	if terminal_pad.a >= 0.30:
		_fail("Small Terminal pad should not look like a separate concrete island.")
		return

	var runway_definition := BuildingCatalog.get_definition("short_runway")
	var runway_pad := grid._building_ground_color(runway_definition)
	if runway_pad.a < 0.70:
		_fail("Runway surface must remain visually distinct from apron concrete.")
		return

	# Moving the two stands away from the terminal should disable the starter
	# campus slab rather than stretching a giant decorative apron across land.
	for index in range(grid.placed_buildings.size()):
		var building: Dictionary = grid.placed_buildings[index]
		if String(building.get("definition_id", "")) != "small_stand":
			continue
		grid.placed_buildings[index]["origin"] = Vector2i(
			0 + index,
			0
		)
	var moved := grid.get_starter_apron_visual_snapshot()
	if bool(moved.get("active", true)):
		_fail("Separated stands should not stretch the starter apron across the map.")
		return

	print(
		"Starter apron visuals passed: unified owned-land slab, subtle building pads, "
		+ "service staging and non-stretching layout behavior."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
