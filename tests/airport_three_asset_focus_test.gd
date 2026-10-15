extends SceneTree

# Release-art contract for V1 Skyrama tap / teleport handling:
# no taxiway purchase or connected road is required for these structures.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := BuildingCatalog.get_menu_definitions()
	for def in catalog:
		var id := String(def.get("id", ""))
		if id == "taxiway":
			_fail("Legacy taxiways must not appear in the shop.")
			return

	var cases := [
		["small_hangar", Vector2i(4, 3), Vector2i(224, 112), 2],
		["medium_hangar", Vector2i(5, 4), Vector2i(288, 144), 2],
		["short_runway", Vector2i(6, 2), Vector2i(256, 128), 2]
	]
	for item in cases:
		var id: String = item[0]
		var def := BuildingCatalog.get_definition(id)
		if def.get("footprint", Vector2i.ZERO) != item[1]:
			_fail("Wrong logical footprint for %s." % id)
			return
		var size: Vector2i = def.get(
			"grid_native_surface_size", Vector2i.ZERO
		)
		if size != item[2]:
			_fail("Wrong projected base for %s." % id)
			return
		var pads: PackedStringArray = def.get(
			"grid_native_surface_paths", PackedStringArray()
		)
		if pads.size() != item[3]:
			_fail("Expected two rotation surfaces for %s." % id)
			return
		for path in pads:
			var texture = load(path)
			if not (texture is Texture2D):
				_fail("Missing production pad: %s" % path)
				return
			if texture.get_size() != Vector2(size):
				_fail("Incorrect in-game pad dimensions: %s" % path)
				return
		if id.contains("hangar"):
			var sprites: PackedStringArray = def.get(
				"grid_first_structure_paths", PackedStringArray()
			)
			if sprites.size() != 2:
				_fail("Hangar missing its two polished facing variants.")
				return
			for path in sprites:
				if not (load(path) is Texture2D):
					_fail("Missing actual in-game hangar sprite: %s" % path)
					return

	print(
		"THREE_ASSET_FOCUS_OK small_hangar=4x3 "
		+ "medium_hangar=5x4 runway=6x2 taxiway_shop=false"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
