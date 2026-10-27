extends SceneTree

# Pixel pilot must use true native ground footprints, never pasted art.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var items := [
		["short_runway", Vector2i(6, 2), Vector2i(256, 128), 2],
		["small_hangar", Vector2i(4, 3), Vector2i(224, 112), 2],
		["apron_tile", Vector2i(1, 1), Vector2i(64, 32), 1],
		["airport_office", Vector2i(3, 2), Vector2i(160, 80), 1]
	]
	for spec in items:
		var id := String(spec[0])
		var definition := BuildingCatalog.get_definition(id)
		if definition.get("footprint", Vector2i.ZERO) != spec[1]:
			_fail("Pixel pilot changed logical footprint: %s" % id)
			return
		var paths: PackedStringArray = definition.get(
			"grid_native_surface_paths", PackedStringArray()
		)
		if paths.size() != int(spec[3]):
			_fail("Missing art orientations: %s" % id)
			return
		for path in paths:
			var texture := load(path)
			if not (texture is Texture2D):
				_fail("Pixel art asset failed to import: %s" % path)
				return
			if texture.get_size() != Vector2(spec[2]):
				_fail("Art dimensions not grid-native: %s" % path)
				return

	var office := BuildingCatalog.get_definition("airport_office")
	var office_sprite: Texture2D = load(
		"res://assets/production/airport_buildings_pixel_v1/airport_office_3x2.svg"
	)
	if office_sprite == null or office_sprite.get_size() != Vector2(160, 190):
		_fail("New-pilot headquarters is not a valid exact-grid sprite.")
		return
	if not bool(office.get("grid_first_world_sprite", false)):
		_fail("Starter office still falls back to a primitive rectangle.")
		return

	# Real Blender exports must be independently imported and grid-sized.
	var hangar := BuildingCatalog.get_definition("small_hangar")
	var sprites: PackedStringArray = hangar.get(
		"grid_first_structure_paths", PackedStringArray()
	)
	if sprites.size() != 2:
		_fail("Both Blender hangar orientations required.")
		return
	for sprite_path in sprites:
		if not sprite_path.ends_with(".png") or not sprite_path.contains(
			"airport_buildings_blender_v1"
		):
			_fail("Small hangar isn't using the Blender-rendered PNG.")
			return
		var imported = load(sprite_path)
		if not (imported is Texture2D) or imported.get_size() != Vector2(
			224, 260
		):
			_fail("Blender sprite import or dimensions invalid.")
			return

	var pilot := AirportPixelTerrain.new()
	root.add_child(pilot)
	await process_frame
	if not bool(pilot.get_visual_snapshot().get("grass_texture", false)):
		_fail("Pixel terrain texture wasn't initialized.")
		return
	if int(pilot.get_visual_snapshot().get("authored_tree_variants", 0)) != 4:
		_fail("All four authored forest variants must import.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	if grid.is_placement_grid_visible():
		_fail("Normal play still shows full debug grid.")
		return
	print("PIXEL_AIRPORT_ART_OK footprints=unchanged terrain=ready")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
