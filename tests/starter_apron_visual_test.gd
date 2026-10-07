extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var snapshot := grid.get_starter_apron_visual_snapshot()
	if bool(snapshot.get("active", false)):
		_fail(
			"Roomier starter layout should not stretch one giant apron between "
			+ "the terminal and separated stands."
		)
		return

	var starter_stands: Array[Dictionary] = []
	var starter_terminal: Dictionary = {}
	for building in grid.placed_buildings:
		var id := String(building.get("definition_id", ""))
		if id == "small_stand":
			starter_stands.append(building)
		elif id == "small_terminal":
			starter_terminal = building

	if starter_stands.size() != 2:
		_fail("Starter airport should still contain both Small Stands.")
		return
	if starter_terminal.is_empty():
		_fail("Starter airport should still contain the Small Terminal.")
		return

	var stand_definition := BuildingCatalog.get_definition("small_stand")
	for stand in starter_stands:
		var stand_footprint := grid._footprint_for(
			stand_definition,
			int(stand.get("rotation", 0))
		)
		var stand_pad := grid._world_art_ground_fill(
			stand_definition,
			stand.get("origin", Vector2i.ZERO),
			stand_footprint
		)
		if stand_pad.a < 0.40:
			_fail(
				"Separated Small Stands should retain a strong readable concrete pad."
			)
			return

	var terminal_definition := BuildingCatalog.get_definition("small_terminal")
	var terminal_footprint := grid._footprint_for(
		terminal_definition,
		int(starter_terminal.get("rotation", 0))
	)
	var terminal_pad := grid._world_art_ground_fill(
		terminal_definition,
		starter_terminal.get("origin", Vector2i.ZERO),
		terminal_footprint
	)
	if terminal_pad.a < 0.40:
		_fail(
			"Roomier Small Terminal should retain its own readable grid foundation."
		)
		return

	var runway_definition := BuildingCatalog.get_definition("short_runway")
	var runway_pad := grid._building_ground_color(runway_definition)
	if runway_pad.a < 0.70:
		_fail("Runway surface must remain visually distinct from building pads.")
		return

	print(
		"Starter apron visuals passed: roomier separated stands, exact grid pads, "
		+ "terminal grounding and no stretched decorative apron."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
