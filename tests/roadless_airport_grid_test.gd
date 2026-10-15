extends SceneTree

# The grid first. No taxi/service roads or physical adjacency restrictions.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for obsolete in ["taxiway", "service_road"]:
		if not BuildingCatalog.get_definition(obsolete).is_empty():
			_fail("Retired road still in catalog: %s" % obsolete)
			return

	var expectations := [
		["small_hangar", Vector2i(3, 2), Vector2i(160, 80), Vector2i(160, 190)],
		["medium_hangar", Vector2i(4, 3), Vector2i(224, 112), Vector2i(224, 260)],
		["short_runway", Vector2i(5, 2), Vector2i(224, 112), Vector2i.ZERO]
	]
	for spec in expectations:
		var def := BuildingCatalog.get_definition(String(spec[0]))
		if def.get("footprint", Vector2i.ZERO) != spec[1]:
			_fail("Incorrect logical footprint for %s" % spec[0])
			return
		var surfaces: PackedStringArray = def.get(
			"grid_native_surface_paths", PackedStringArray()
		)
		if surfaces.size() != 2:
			_fail("Expected authored art for both rotations: %s" % spec[0])
			return
		for path in surfaces:
			var image = load(path)
			if not (image is Texture2D) or image.get_size() != Vector2(spec[2]):
				_fail("Projected surface/import mismatch: %s" % path)
				return
		if spec[3] != Vector2i.ZERO:
			var sprites: PackedStringArray = def.get(
				"grid_first_structure_paths", PackedStringArray()
			)
			if sprites.size() != 2:
				_fail("Missing building rotations: %s" % spec[0])
				return
			for p in sprites:
				var sprite = load(p)
				if not (sprite is Texture2D) or sprite.get_size() != Vector2(spec[3]):
					_fail("Invalid building art dimensions: %s" % p)
					return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	for spec in expectations:
		var definition := BuildingCatalog.get_definition(String(spec[0]))
		for rotation in [0, 1]:
			var expected: Vector2i = (
				spec[1] if rotation == 0
				else Vector2i(spec[1].y, spec[1].x)
			)
			var visual := grid.get_grid_visual_contract_for_definition(
				definition, rotation
			)
			if visual.get("footprint", Vector2i.ZERO) != expected:
				_fail("Rotation changed projected footprint for %s" % spec[0])
				return
			var point := (
				Vector2i(4, 5) if rotation == 0 else Vector2i(5, 6)
			)
			var preview := grid.set_build_preview(
				String(spec[0]),
				grid.tile_to_world(Vector2(point.x, point.y)),
				rotation
			)
			if not bool(preview.get("valid", false)):
				_fail("Roadless placement should work for %s" % spec[0])
				return

	if grid.get_airside_status().get("taxiways", -1) != 0:
		_fail("Road reachability should not exist.")
		return
	print("ROADLESS_AIRPORT_GRID_OK small=3x2 medium=4x3 runway=5x2")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
