extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var site := grid.get_airport_site_foundation_snapshot()
	if bool(site.get("active", false)):
		_fail(
			"Roomier showcase airport should not draw one giant foundation across "
			+ "multiple locked districts."
		)
		return
	if int(site.get("building_count", 0)) <= 0:
		_fail("Foundation snapshot should still report starter building coverage.")
		return

	for building_id in [
		"small_terminal",
		"basic_fuel",
		"ground_ops_depot",
		"travel_office"
	]:
		var definition := BuildingCatalog.get_definition(building_id)
		var found: Dictionary = {}
		for building in grid.placed_buildings:
			if String(building.get("definition_id", "")) == building_id:
				found = building
				break
		if found.is_empty():
			_fail("%s should exist in the starter airport." % building_id)
			return

		var fp := grid._footprint_for(
			definition,
			int(found.get("rotation", 0))
		)
		var origin: Vector2i = found.get("origin", Vector2i.ZERO)
		var fill := grid._world_art_ground_fill(
			definition,
			origin,
			fp
		)
		if fill.a < 0.45:
			_fail(
				"%s should retain a readable individual grid foundation."
				% building_id
			)
			return

		var polygon := grid._footprint_polygon(origin, fp)
		if polygon.size() != 4:
			_fail(
				"%s foundation should match one exact isometric footprint."
				% building_id
			)
			return

	if not grid.has_method("_draw_building_contact_shadow"):
		_fail("Buildings should retain a dedicated contact-shadow grounding pass.")
		return

	print(
		"AIRPORT_GROUNDING_OK roomier_plots=true individual_pads=true "
		+ "contact_shadows=true placement_grid_exact=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
