extends SceneTree

# The hangar is the first grid-geometry-driven building, not an illustration
# deformed to fit a tile. Both sprite corners and build occupancy agree.

const NORMAL := "res://assets/production/airport_buildings_v6/small_hangar_3x2.svg"
const ROTATED := "res://assets/production/airport_buildings_v6/small_hangar_2x3.svg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := BuildingCatalog.get_definition("small_hangar")
	if definition.get("footprint", Vector2i.ZERO) != Vector2i(3, 2):
		_fail("The hangar's logical footprint must remain 3x2.")
		return
	if not bool(definition.get("grid_first_world_sprite", false)):
		_fail("Hangar must be displayed as an authored sprite on the pad.")
		return
	if bool(definition.get("grid_first_structure_flip_odd_rotations", true)):
		_fail("Both hangar orientations must have their own authored source.")
		return
	if bool(definition.get("grid_first_structure_clip_base_to_footprint", false)):
		_fail("Do not clip mismatched hangar sprites at runtime.")
		return

	var paths: PackedStringArray = definition.get(
		"grid_first_structure_paths", PackedStringArray()
	)
	if paths != PackedStringArray([NORMAL, ROTATED]):
		_fail("Missing independently authored 3x2 and 2x3 image paths.")
		return
	for asset_path in paths:
		var sprite := load(asset_path)
		if not (sprite is Texture2D):
			_fail("Hangar did not import as Godot Texture2D: %s" % asset_path)
			return
		if sprite.get_size() != Vector2(160, 190):
			_fail("Sprite should use 160x190 pixel canvas: %s" % asset_path)
			return
		var image: Image = sprite.get_image()
		if image.get_pixel(70, 145).a < 0.60:
			_fail("Closed hangar door/base did not render: %s" % asset_path)
			return
		var gable_x := 51 if asset_path == NORMAL else 109
		if image.get_pixel(gable_x, 85).a < 0.65:
			_fail("Curved roof gable must be solid, not expose terrain.")
			return
		if image.get_pixel(10, 185).a > 0.05:
			_fail("Ground art overhangs the bottom-left tile: %s" % asset_path)
			return
		if image.get_pixel(151, 183).a > 0.05:
			_fail("Ground art overhangs the bottom-right tile: %s" % asset_path)
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
			_fail("Hangar footprint rotation is incorrect.")
			return
		if (
			int(contract.get("authoring_width_px", 0)) != 160
			or int(contract.get("base_depth_px", 0)) != 80
		):
			_fail("Wrong 160x80 isometric hangar ground projection.")
			return
		var preview := grid.set_build_preview(
			"small_hangar", grid.tile_to_world(Vector2(8, 6)), rotation
		)
		if not bool(preview.get("valid", false)):
			_fail("Hangar needs to snap to an empty 3x2 or 2x3 area.")
			return
		var draw_rect := grid.get_grid_visual_draw_rect_for_definition(
			definition, Vector2i(4, 4), rotation, Vector2i(160, 190)
		)
		if draw_rect.size != Vector2(160, 190):
			_fail("Sprite should render at its grid-authored native width.")
			return

	print(
		"GENERATED_HANGAR_GRID_OK v6=true footprint=3x2 rotations=2 "
		+ "pad=160x80 art=160x190 grid_geometry=true runtime_clip=false"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
