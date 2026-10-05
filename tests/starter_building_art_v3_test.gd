extends SceneTree


const STARTER_V3 := {
	"small_terminal": {
		"rotations": 2,
		"size": Vector2(326, 244)
	},
	"basic_fuel": {
		"rotations": 2,
		"size": Vector2(206, 172)
	},
	"ground_ops_depot": {
		"rotations": 1,
		"size": Vector2(132, 132)
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for building_id_variant in STARTER_V3.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = STARTER_V3[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return

		if String(definition.get("art_tier", "")) != "starter_v3":
			_fail("%s should use the starter_v3 production art tier." % building_id)
			return
		if not String(
			definition.get("world_sprite_atlas_path", "")
		).is_empty():
			_fail("%s should no longer depend on the legacy building atlas." % building_id)
			return

		var rotations := int(expected.get("rotations", 1))
		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		var single_path := String(definition.get("world_sprite_path", ""))
		if rotations == 1:
			if single_path.is_empty():
				_fail("%s should expose one dedicated world-art path." % building_id)
				return
			if not ResourceLoader.exists(single_path):
				_fail("%s dedicated world art should exist." % building_id)
				return
			var texture = load(single_path)
			if not (texture is Texture2D):
				_fail("%s dedicated world art should import as Texture2D." % building_id)
				return
		else:
			if paths.size() != rotations:
				_fail(
					"%s should expose %d distinct orientations."
					% [building_id, rotations]
				)
				return
			if paths[0] == paths[1]:
				_fail("%s orientations must use distinct art files." % building_id)
				return
			for rotation in range(rotations):
				var path := String(paths[rotation])
				if not ResourceLoader.exists(path):
					_fail(
						"%s rotation %d art should exist."
						% [building_id, rotation]
					)
					return
				var texture = load(path)
				if not (texture is Texture2D):
					_fail(
						"%s rotation %d should import as Texture2D."
						% [building_id, rotation]
					)
					return
				if grid._sprite_path_for_rotation(
					definition,
					rotation
				) != path:
					_fail(
						"%s rotation %d should resolve to its dedicated sprite."
						% [building_id, rotation]
					)
					return

		var draw_size: Vector2 = definition.get(
			"world_sprite_size",
			Vector2.ZERO
		)
		if draw_size != expected.get("size", Vector2.ZERO):
			_fail(
				"%s should retain its tuned starter-v3 draw size."
				% building_id
			)
			return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	var definitions: Array[Dictionary] = []
	for building_id_variant in STARTER_V3.keys():
		definitions.append(
			BuildingCatalog.get_definition(
				String(building_id_variant)
			)
		)
	hud.set_build_catalog(definitions)
	await process_frame

	for definition in definitions:
		var building_id := String(definition.get("id", ""))
		if not hud.catalog_buttons.has(building_id):
			_fail("%s should appear in the Build Tray." % building_id)
			return
		var button: Button = hud.catalog_buttons[building_id]
		if button.icon == null:
			_fail("%s Build Tray card should show production art." % building_id)
			return
		if button.icon is AtlasTexture:
			_fail("%s Build Tray should not fall back to the legacy atlas." % building_id)
			return
		var expected_path := String(
			definition.get("world_sprite_path", "")
		)
		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not paths.is_empty():
			expected_path = String(paths[0])
		if String(button.icon.resource_path) != expected_path:
			_fail(
				"%s Build Tray should preview its exact first world-art sprite."
				% building_id
			)
			return

	print(
		"STARTER_BUILDING_V3_OK terminal=2_angles fuel=2_angles ground_ops=dedicated "
		+ "build_tray=world_art"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
