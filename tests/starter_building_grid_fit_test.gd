extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check_round_trip():
		return
	if not _check_footprint_geometry():
		return
	if not _check_rotation_contract():
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not grid.is_grid_first_visual_reset_enabled():
		_fail("Airport must remain in grid-first visual reset mode.")
		return

	var expected_footprints := {
		"airport_office": Vector2i(2, 2),
		"short_runway": Vector2i(5, 2),
		"small_stand": Vector2i(2, 2),
		"small_terminal": Vector2i(3, 2),
		"small_hangar": Vector2i(3, 2),
		"basic_fuel": Vector2i(2, 2),
		"taxiway": Vector2i(1, 1),
		"service_road": Vector2i(1, 1),
		"regional_runway": Vector2i(12, 3)
	}
	for definition_id_variant in expected_footprints.keys():
		var definition_id := String(definition_id_variant)
		var definition := BuildingCatalog.get_definition(definition_id)
		var actual: Vector2i = definition.get("footprint", Vector2i.ZERO)
		var expected: Vector2i = expected_footprints[definition_id_variant]
		if actual != expected:
			_fail(
				"%s footprint %s should be %s for the square-grid scale."
				% [definition_id, str(actual), str(expected)]
			)
			return

	var unit_contract := BuildingPlacementGrid.visual_contract(Vector2i.ONE)
	if unit_contract.get("logical_tile_size", Vector2.ZERO) != Vector2(64, 64):
		_fail("Gameplay cells must remain true 64x64 logical squares.")
		return
	if absf(float(unit_contract.get("projected_tile_width", 0.0)) - 64.0) > 0.01:
		_fail("Skyrama ground projection should draw a 64 px wide cell diamond.")
		return
	if absf(float(unit_contract.get("projected_tile_height", 0.0)) - 32.0) > 0.01:
		_fail("Skyrama ground projection should draw a 32 px deep cell diamond.")
		return
	if String(unit_contract.get("projection", "")) != "skyrama_isometric_2_to_1":
		_fail("Grid contract should explicitly expose the Skyrama-style projection.")
		return

	for menu_definition in BuildingCatalog.get_menu_definitions():
		if String(menu_definition.get("id", "")) == "airport_office":
			_fail("Fixed Airport Office must not be purchasable.")
			return

	var terminal := BuildingCatalog.get_definition("small_terminal")
	var terminal_contract := grid.get_grid_visual_contract_for_definition(
		terminal,
		0
	)
	if not bool(terminal_contract.get("valid", false)):
		_fail("Terminal should expose a valid grid visual contract.")
		return
	if terminal_contract.get("footprint", Vector2i.ZERO) != Vector2i(3, 2):
		_fail("Terminal visual contract must use its exact 3x2 logical footprint.")
		return

	var terminal_asset_size := Vector2i(160, 180)
	var terminal_asset_check := BuildingPlacementGrid.validate_asset_dimensions(
		terminal_asset_size,
		Vector2i(3, 2)
	)
	if not bool(terminal_asset_check.get("valid", false)):
		_fail("A 160 px wide 3x2 asset should satisfy the projected square-grid contract.")
		return
	if bool(
		BuildingPlacementGrid.validate_asset_dimensions(
			Vector2i(161, 180),
			Vector2i(3, 2)
		).get("valid", true)
	):
		_fail("A 3x2 asset with the wrong width must be rejected.")
		return
	var terminal_origin := Vector2i(4, 5)
	var terminal_draw_rect := BuildingPlacementGrid.asset_draw_rect(
		terminal_origin,
		Vector2i(3, 2),
		terminal_asset_size
	)
	var terminal_anchor := BuildingPlacementGrid.footprint_front_anchor_world(
		terminal_origin,
		Vector2i(3, 2)
	)
	if terminal_draw_rect.size != Vector2(160, 180):
		_fail("Grid-native asset draw rect must preserve exact source dimensions.")
		return
	if (
		terminal_draw_rect.position
		+ Vector2(
			terminal_draw_rect.size.x * 0.5,
			terminal_draw_rect.size.y
		)
	).distance_to(terminal_anchor) > 0.01:
		_fail("Asset bottom-center must land exactly on the grid front anchor.")
		return

	print(
		"GRID_VISUAL_CONTRACT_OK projection=skyrama_iso logical=64x64 projected=64x32 "
		+ "nearest_cell_snap=true grid_owns_footprint=true "
		+ "grid_owns_anchor=true grid_owns_scale=true "
		+ "authoring_1_to_1=true padding=top_only "
		+ "draw=bottom_center_to_front_anchor"
	)
	quit(0)


func _check_round_trip() -> bool:
	for cell in [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(3, 5),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-4, 2)
	]:
		var world := BuildingPlacementGrid.tile_to_world(
			Vector2(cell.x, cell.y)
		)
		var recovered := BuildingPlacementGrid.world_to_tile(world)
		if recovered != cell:
			_fail(
				"Grid round-trip failed for %s -> %s."
				% [str(cell), str(recovered)]
			)
			return false

	# Square-grid picking snaps to the nearest cell center.
	var near_center := (
		BuildingPlacementGrid.tile_to_world(Vector2(2, 2))
		+ Vector2(5, 2)
	)
	if BuildingPlacementGrid.world_to_tile(near_center) != Vector2i(2, 2):
		_fail("Pointer snapping must use nearest logical square-cell rounding in the projected view.")
		return false
	return true


func _check_footprint_geometry() -> bool:
	for footprint in [
		Vector2i(1, 1),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(5, 2)
	]:
		var contract := BuildingPlacementGrid.visual_contract(
			footprint
		)
		if not bool(contract.get("valid", false)):
			_fail("Footprint %s should produce a valid contract." % str(footprint))
			return false

		var expected_width := (
			float(footprint.x + footprint.y)
			* BuildingPlacementGrid.PROJECTED_TILE_WIDTH
			* 0.5
		)
		var expected_height := (
			float(footprint.x + footprint.y)
			* BuildingPlacementGrid.PROJECTED_TILE_HEIGHT
			* 0.5
		)
		var size: Vector2 = contract.get(
			"base_size",
			Vector2.ZERO
		)
		if absf(size.x - expected_width) > 0.01:
			_fail(
				"Footprint %s width %.2f should be %.2f."
				% [str(footprint), size.x, expected_width]
			)
			return false
		if absf(size.y - expected_height) > 0.01:
			_fail(
				"Footprint %s height %.2f should be %.2f."
				% [str(footprint), size.y, expected_height]
			)
			return false
		if float(contract.get("max_horizontal_overhang_px", -1.0)) != 0.0:
			_fail("Grid-native visuals may not define horizontal footprint overhang.")
			return false
		if int(contract.get("authoring_width_px", 0)) != roundi(expected_width):
			_fail("Authoring width must equal the exact grid footprint width.")
			return false
		if int(contract.get("base_depth_px", 0)) != roundi(expected_height):
			_fail("Authoring base depth must equal the exact grid footprint depth.")
			return false
		if contract.get("runtime_scale", Vector2.ZERO) != Vector2.ONE:
			_fail("Grid-native assets must render at 1:1 world scale.")
			return false
		if String(contract.get("transparent_padding_rule", "")) != "top_only":
			_fail("Any transparent visual padding may exist above the base only.")
			return false
		var anchor_shape: PackedVector2Array = contract.get(
			"base_polygon_from_anchor",
			PackedVector2Array()
		)
		if anchor_shape.size() != 4:
			_fail("Visual contract must expose a four-point base polygon from anchor.")
			return false
		if anchor_shape[2].distance_to(Vector2.ZERO) > 0.01:
			_fail("Projected front anchor must be the zero point of the authoring base.")
			return false
	return true


func _check_rotation_contract() -> bool:
	var definition := {
		"footprint": Vector2i(3, 2),
		"rotatable": true
	}
	if BuildingPlacementGrid.footprint_for(definition, 0) != Vector2i(3, 2):
		_fail("Rotation 0 must preserve a 3x2 footprint.")
		return false
	if BuildingPlacementGrid.footprint_for(definition, 1) != Vector2i(2, 3):
		_fail("Rotation 1 must swap a 3x2 footprint to 2x3.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
