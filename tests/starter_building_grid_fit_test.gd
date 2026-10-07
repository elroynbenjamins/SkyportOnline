extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if AirportGrid.WORLD_SPRITE_MAX_FOOTPRINT_OVERHANG != 1.0:
		_fail("World sprites must never be allowed to exceed their grid footprint.")
		return

	if not grid.has_method("_draw_canonical_building_foundation"):
		_fail("All placeable buildings should use a canonical grid foundation.")
		return
	var terminal_profile := grid.get_foundation_profile_for_definition(
		BuildingCatalog.get_definition("small_terminal")
	)
	if (
		not bool(terminal_profile.get("enabled", false))
		or String(terminal_profile.get("style", "")) != "passenger"
	):
		_fail("Terminal should resolve to the passenger foundation profile.")
		return
	var fuel_profile := grid.get_foundation_profile_for_definition(
		BuildingCatalog.get_definition("basic_fuel")
	)
	if String(fuel_profile.get("style", "")) != "fuel":
		_fail("Fuel stations should resolve to the fuel foundation profile.")
		return
	var decor_profile := grid.get_foundation_profile_for_definition(
		BuildingCatalog.get_definition("autumn_event_flag")
	)
	if bool(decor_profile.get("enabled", true)):
		_fail("Decorations should not receive a hard airport foundation.")
		return

	var normal_checked := 0
	for definition in BuildingCatalog.all():
		if not grid._definition_has_world_sprite(definition):
			continue
		if not _check_definition(grid, definition, "building"):
			return
		normal_checked += 1

	var charter_checked := 0
	for base_definition in (
		CharterVisualCatalog.building_visuals()
		+ CharterVisualCatalog.surface_visuals()
	):
		var visual_id := String(base_definition.get("id", ""))
		var definition := CharterVisualCatalog.visual_for(visual_id)
		if definition.is_empty():
			_fail("%s charter definition should resolve." % visual_id)
			return
		if not _check_definition(grid, definition, "charter"):
			return
		charter_checked += 1

	# Preview/construction motion may lift a sprite vertically, but it must never
	# change the footprint-based scale or horizontal grounding.
	var hangar := BuildingCatalog.get_definition("small_hangar")
	var hangar_fp := grid._footprint_for(hangar, 0)
	var final_rect := grid._building_sprite_rect(
		hangar,
		Vector2i(2, 2),
		hangar_fp,
		0
	)
	var preview_rect := grid._building_sprite_rect(
		hangar,
		Vector2i(2, 2),
		hangar_fp,
		0,
		Vector2(0, -10)
	)
	if absf(final_rect.position.x - preview_rect.position.x) > 0.01:
		_fail("Preview must keep the exact final grid X position.")
		return
	if final_rect.size.distance_to(preview_rect.size) > 0.01:
		_fail("Preview and final building must use the exact same grid-fit scale.")
		return
	if absf((preview_rect.position.y - final_rect.position.y) + 10.0) > 0.01:
		_fail("Preview lift may only move the sprite vertically.")
		return

	# Starter layout remains intentionally spaced; strict visual fitting should
	# not mutate logical building positions or occupied cells.
	var travel_origin := Vector2i(-1, -1)
	var terminal_origin := Vector2i(-1, -1)
	for building in grid.placed_buildings:
		match String(building.get("definition_id", "")):
			"travel_office":
				travel_origin = building.get("origin", Vector2i(-1, -1))
			"small_terminal":
				terminal_origin = building.get("origin", Vector2i(-1, -1))
	if travel_origin != Vector2i(7, 12):
		_fail("Strict sprite fitting must not move the Travel Office grid cells.")
		return
	if terminal_origin != Vector2i(11, 12):
		_fail("Strict sprite fitting must not move the Terminal grid cells.")
		return

	print(
		(
			"STRICT_GRID_FOOTPRINTS_OK buildings=%d charter=%d "
			+ "width_bounded=true centered=true grounded=true "
			+ "preview_same_geometry=true"
		) % [normal_checked, charter_checked]
	)
	quit(0)


func _check_definition(
	grid: AirportGrid,
	definition: Dictionary,
	group_name: String
) -> bool:
	var id := String(definition.get("id", "unknown"))
	var rotations := (
		2
		if bool(definition.get("rotatable", false))
		else 1
	)
	for rotation in range(rotations):
		var snapshot := grid.get_grid_fit_snapshot_for_definition(
			definition,
			Vector2i(3, 3),
			rotation
		)
		if not bool(snapshot.get("valid", false)):
			_fail(
				"%s %s rotation %d should produce a measurable grid-fit sprite."
				% [group_name, id, rotation]
			)
			return false

		var footprint_width := float(snapshot.get("footprint_width", 0.0))
		var visible_width := float(snapshot.get("visible_width", 999999.0))
		if visible_width > footprint_width + 0.10:
			_fail(
				"%s %s rotation %d visible width %.2f exceeds footprint %.2f."
				% [
					group_name,
					id,
					rotation,
					visible_width,
					footprint_width
				]
			)
			return false

		var bottom_delta := absf(float(snapshot.get("bottom_delta", 999.0)))
		if bottom_delta > 0.10:
			_fail(
				"%s %s rotation %d base is %.2f px off the grid."
				% [group_name, id, rotation, bottom_delta]
			)
			return false

		var center_delta := absf(float(snapshot.get("center_delta", 999.0)))
		if center_delta > 0.10:
			_fail(
				"%s %s rotation %d is %.2f px off footprint center."
				% [group_name, id, rotation, center_delta]
			)
			return false

	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
