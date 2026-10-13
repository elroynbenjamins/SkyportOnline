extends SceneTree

# Production checks for hand-aligned 3x2/2x3 sprite views.
# The sprites contain only building art. The grid owns ground, collision,
# placement outline, contact point and the 160x80 projected service pad.

const NORMAL := "res://assets/production/airport_buildings_v5/small_hangar_3x2.webp"
const ROTATED := "res://assets/production/airport_buildings_v5/small_hangar_2x3.webp"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := BuildingCatalog.get_definition("small_hangar")
	if definition.is_empty():
		_fail("Small Hangar definition missing.")
		return
	if definition.get("footprint", Vector2i.ZERO) != Vector2i(3, 2):
		_fail("Small Hangar must occupy exactly 3x2 square grid cells.")
		return
	if not bool(definition.get("grid_first_world_sprite", false)):
		_fail("Small Hangar must render over the grid-native pad.")
		return
	if bool(definition.get("grid_first_structure_flip_odd_rotations", true)):
		_fail("V5 has two authored views and must not mirror one view.")
		return
	if bool(definition.get("world_art_has_integrated_base", true)):
		_fail("Illustrated apron must not be baked into the V5 sprites.")
		return
	if bool(definition.get("grid_first_structure_clip_base_to_footprint", false)):
		_fail("V5 sprites must fit without runtime clipping hacks.")
		return

	var paths: PackedStringArray = definition.get(
		"grid_first_structure_paths", PackedStringArray()
	)
	if paths != PackedStringArray([NORMAL, ROTATED]):
		_fail("Hangar must use independent 3x2 and 2x3 WebP sprite views.")
		return

	for asset_path in paths:
		var texture = load(asset_path)
		if not (texture is Texture2D):
			_fail("Godot could not import authored image: %s" % asset_path)
			return
		if texture.get_size() != Vector2(160, 150):
			_fail("Hangar sprite canvas must be 160x150: %s" % asset_path)
			return
		var pixels: Image = texture.get_image()
		if pixels.get_pixel(80, 100).a < 0.5:
			_fail("Hangar building door/body unexpectedly cut: %s" % asset_path)
			return
		if pixels.get_pixel(80, 145).a > 0.05:
			_fail("Hangar has extra apron beneath its grid footprint.")
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	for rotation in [0, 1]:
		var contract := grid.get_grid_visual_contract_for_definition(
			definition, rotation
		)
		var expected := (
			Vector2i(3, 2) if rotation == 0 else Vector2i(2, 3)
		)
		if contract.get("footprint", Vector2i.ZERO) != expected:
			_fail("Hangar rotation must change occupied cells 3x2 ↔ 2x3.")
			return
		if (
			int(contract.get("authoring_width_px", 0)) != 160
			or int(contract.get("base_depth_px", 0)) != 80
		):
			_fail("Hangar projection must remain 160x80.")
			return
		var placement := grid.set_build_preview(
			"small_hangar",
			grid.tile_to_world(Vector2(8, 6)),
			rotation
		)
		if not bool(placement.get("valid", false)):
			_fail("Hangar should snap onto empty tiles in either rotation.")
			return
		var draw_rect := grid.get_grid_visual_draw_rect_for_definition(
			definition, Vector2i(4, 4), rotation, Vector2i(160, 150)
		)
		if draw_rect.size != Vector2(160, 150):
			_fail("Grid-authored sprite draw rect should have native width.")
			return

	print(
		"GENERATED_HANGAR_GRID_OK views=2 "
		+ "base=160x80 sprites=160x150 "
		+ "footprints=3x2,2x3 runtime_clip=false"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
