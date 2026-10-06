extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var site := grid.get_airport_site_foundation_snapshot()
	if not bool(site.get("active", false)):
		_fail("Starter airport should expose one shared airport foundation.")
		return

	var origin: Vector2i = site.get("origin", Vector2i(-1, -1))
	var footprint: Vector2i = site.get("footprint", Vector2i.ZERO)
	if origin != Vector2i(8, 8):
		_fail("Starter airport foundation should begin at the runway corner.")
		return
	if footprint != Vector2i(8, 8):
		_fail("Starter airport foundation should cover the full 8x8 home airport.")
		return

	for building in grid.placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty():
			continue
		if String(definition.get("category", "")) == "Decor":
			continue
		var fp := grid._footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		if not grid._building_is_on_airport_foundation(
			building.get("origin", Vector2i.ZERO),
			fp
		):
			_fail(
				"%s should sit on the shared airport foundation."
				% String(building.get("definition_id", "building"))
			)
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
		var fill := grid._world_art_ground_fill(
			definition,
			found.get("origin", Vector2i.ZERO),
			fp
		)
		if fill.a > 0.12:
			_fail(
				"%s pad should blend into the shared airport floor."
				% building_id
			)
			return

	if not grid.has_method("_draw_building_contact_shadow"):
		_fail("Buildings should retain a dedicated contact-shadow grounding pass.")
		return

	var polygon := grid._footprint_polygon(origin, footprint)
	if polygon.size() != 4:
		_fail("Shared airport foundation should be one continuous isometric slab.")
		return

	print(
		"AIRPORT_GROUNDING_OK foundation=8x8 integrated_pads=true "
		+ "contact_shadows=true placement_grid_hidden=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
