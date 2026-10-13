extends SceneTree

# Verifies that the rendered hangar is actually wired to the playable
# square-grid isometric construction system, rather than a mock-up image.
const SPRITE := "res://assets/production/airport_buildings_v4/small_hangar_render.webp"

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var building := BuildingCatalog.get_definition("small_hangar")
	if building.is_empty():
		_fail("Small Hangar definition missing.")
		return
	if building.get("footprint", Vector2i.ZERO) != Vector2i(3, 2):
		_fail("Small Hangar must remain 3x2 square cells.")
		return
	if not bool(building.get("grid_first_world_sprite", false)):
		_fail("Rendered hangar must be visible during grid-first reset.")
		return
	if not bool(building.get("grid_first_structure_flip_odd_rotations", false)):
		_fail("Rotated hangar must mirror the same production sprite.")
		return
	var paths: PackedStringArray = building.get(
		"grid_first_structure_paths", PackedStringArray()
	)
	if paths.size() != 2 or paths[0] != SPRITE or paths[1] != SPRITE:
		_fail("Both orientation slots must point at generated WebP.")
		return
	var resource = load(SPRITE)
	if not (resource is Texture2D):
		_fail("Godot could not import the rendered hangar WebP.")
		return
	if resource.get_size() != Vector2(160, 119):
		_fail("Rendered hangar source dimensions changed.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	for rotation in [0, 1]:
		var contract := grid.get_grid_visual_contract_for_definition(
			building, rotation
		)
		var expected := (
			Vector2i(3, 2) if rotation == 0 else Vector2i(2, 3)
		)
		if contract.get("footprint", Vector2i.ZERO) != expected:
			_fail("Hangar rotated footprint is incorrect.")
			return
		if int(contract.get("authoring_width_px", 0)) != 160 or int(contract.get("base_depth_px", 0)) != 80:
			_fail("Hangar projected base width changed.")
			return
		var preview := grid.set_build_preview(
			"small_hangar",
			grid.tile_to_world(Vector2(8, 6)),
			rotation
		)
		if not bool(preview.get("valid", false)):
			_fail("Hangar must snap onto a free 3x2/2x3 grid area.")
			return
		var draw_rect := grid.get_grid_visual_draw_rect_for_definition(
			building, Vector2i(4, 4), rotation, Vector2i(160, 180)
		)
		if draw_rect.size != Vector2(160, 180):
			_fail("Hangar art must be sized from projected grid width.")
			return

	print(
		"GENERATED_HANGAR_GRID_OK source=webp "
		+ "footprint=3x2 rotated=2x3 base=160x80 mirror=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
