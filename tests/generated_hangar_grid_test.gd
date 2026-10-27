extends SceneTree

# The hangar is the first grid-geometry-driven building, not an illustration
# deformed to fit a tile. Both sprite corners and build occupancy agree.

const NORMAL := "res://assets/production/airport_buildings_pixel_v2/small_hangar_4x3.png"
const ROTATED := "res://assets/production/airport_buildings_pixel_v2/small_hangar_3x4.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := BuildingCatalog.get_definition("small_hangar")
	if definition.get("footprint", Vector2i.ZERO) != Vector2i(4, 3):
		_fail("The hangar's logical footprint must remain 4x3.")
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
		_fail("Missing independently authored 4x3 and 3x4 image paths.")
		return
	for asset_path in paths:
		var sprite := load(asset_path)
		if not (sprite is Texture2D):
			_fail("Hangar did not import as Godot Texture2D: %s" % asset_path)
			return
		if sprite.get_size() != Vector2(224, 260):
			_fail("Sprite should use 224x260 pixel canvas: %s" % asset_path)
			return
		var image: Image = sprite.get_image()
		if image.get_pixel(112, 155).a < 0.25:
			_fail("Hangar body missing on the upgraded 4x3 sprite.")
			return
		if image.get_pixel(2, 258).a > 0.05 or image.get_pixel(221, 258).a > 0.05:
			_fail("Hangar ground artwork spills outside the grid-native pad.")
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
			Vector2i(4, 3) if rotation == 0 else Vector2i(3, 4)
		)
		if contract.get("footprint", Vector2i.ZERO) != expected:
			_fail("Hangar footprint rotation is incorrect.")
			return
		if (
			int(contract.get("authoring_width_px", 0)) != 224
			or int(contract.get("base_depth_px", 0)) != 112
		):
			_fail("Wrong 224x112 isometric hangar ground projection.")
			return
		var preview := grid.set_build_preview(
			"small_hangar", grid.tile_to_world(Vector2(8, 6)), rotation
		)
		if not bool(preview.get("valid", false)):
			_fail("Hangar needs to snap to an empty 4x3 or 3x4 area.")
			return
		var draw_rect := grid.get_grid_visual_draw_rect_for_definition(
			definition, Vector2i(4, 4), rotation, Vector2i(224, 260)
		)
		if draw_rect.size != Vector2(224, 260):
			_fail("Sprite should render at its grid-authored native width.")
			return

	print(
		"GENERATED_HANGAR_GRID_OK raster_pilot=true footprint=4x3 rotations=2 "
		+ "pad=224x112 art=224x260 grid_geometry=true runtime_clip=false"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
