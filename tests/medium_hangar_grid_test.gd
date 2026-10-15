extends SceneTree

# Grid-authored medium-hangar regression:
# 5x4 occupancy, distinct 4x5 rotation, concrete pads, imported textures,
# and a genuinely larger visual footprint than the 4x3 Small Hangar.
const ART_PATHS := [
	"res://assets/production/airport_buildings_v8/medium_hangar_5x4.svg",
	"res://assets/production/airport_buildings_v8/medium_hangar_4x5.svg"
]
const PAD_PATHS := [
	"res://assets/production/airfield_v8/service/medium_hangar_pad_5x4.svg",
	"res://assets/production/airfield_v8/service/medium_hangar_pad_4x5.svg"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var small := BuildingCatalog.get_definition("small_hangar")
	var medium := BuildingCatalog.get_definition("medium_hangar")
	if small.is_empty() or medium.is_empty():
		_fail("Hangar catalog definitions missing.")
		return
	if small.get("footprint") != Vector2i(4, 3):
		_fail("Small hangar footprint unexpectedly changed.")
		return
	if medium.get("footprint") != Vector2i(5, 4):
		_fail("Medium hangar must occupy exactly 5x4 squares.")
		return
	if int(medium.get("level", 0)) <= int(small.get("level", 0)):
		_fail("Medium hangar needs a later progression unlock.")
		return
	if medium.get("sizes", PackedStringArray()) != PackedStringArray(["S", "M"]):
		_fail("Medium hangar must accept small and medium planes.")
		return
	if medium.get("grid_first_structure_paths", PackedStringArray()) != PackedStringArray(ART_PATHS):
		_fail("The medium hangar must have separate 5x4 and 4x5 artwork.")
		return
	if medium.get("grid_native_surface_paths", PackedStringArray()) != PackedStringArray(PAD_PATHS):
		_fail("Both rotations must have grid-authored concrete pads.")
		return
	if not bool(medium.get("grid_first_world_sprite", false)):
		_fail("Medium hangar production artwork is not enabled.")
		return
	if bool(medium.get("grid_first_structure_flip_odd_rotations", true)):
		_fail("Medium hangar rotations must use their own production view.")
		return
	for art_path in ART_PATHS:
		var sprite = load(art_path)
		if not (sprite is Texture2D) or sprite.get_size() != Vector2(288, 336):
			_fail("Invalid 288x336 production artwork: %s" % art_path)
			return
	for pad_path in PAD_PATHS:
		var pad = load(pad_path)
		if not (pad is Texture2D) or pad.get_size() != Vector2(288, 144):
			_fail("Invalid 288x144 concrete grid pad: %s" % pad_path)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	for rotation in [0, 1]:
		var expected := Vector2i(5, 4) if rotation == 0 else Vector2i(4, 5)
		var visual := grid.get_grid_visual_contract_for_definition(
			medium, rotation
		)
		if visual.get("footprint", Vector2i.ZERO) != expected:
			_fail("Medium hangar rotation must be 5x4 or 4x5.")
			return
		if (
			int(visual.get("authoring_width_px", 0)) != 288
			or int(visual.get("base_depth_px", 0)) != 144
		):
			_fail("Medium hangar projection should be exactly 288x144.")
			return
		var preview := grid.set_build_preview(
			"medium_hangar",
			grid.tile_to_world(Vector2(7, 7)),
			rotation
		)
		if not bool(preview.get("valid", false)):
			_fail("Medium hangar cannot snap to free cells.")
			return
		var draw_rect := grid.get_grid_visual_draw_rect_for_definition(
			medium, Vector2i(7, 7), rotation, Vector2i(288, 336)
		)
		if draw_rect.size != Vector2(288, 336):
			_fail("Medium art must render at its grid-native size.")
			return

	print(
		"MEDIUM_HANGAR_GRID_OK footprint=5x4 rotated=4x5 "
		+ "base=288x144 art=288x336 small=4x3 "
		+ "concrete=true sizes=SM"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
