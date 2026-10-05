extends SceneTree


const STARTER_DEDICATED := {
	"small_terminal": {
		"rotations": 2,
		"size": Vector2(326, 244)
	},
	"basic_fuel": {
		"rotations": 2,
		"size": Vector2(206, 172)
	}
}

const CANONICAL_V2 := {
	"ground_ops_depot": {
		"regions": 2,
		"size": Vector2(116, 116),
		"first_region": Rect2(0, 896, 448, 448),
		"first_offset": Vector2(0, -31)
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for building_id_variant in STARTER_DEDICATED.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = STARTER_DEDICATED[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return

		if String(definition.get("art_tier", "")) != "starter_v3":
			_fail("%s should retain its dedicated starter-v3 art." % building_id)
			return
		if not String(
			definition.get("world_sprite_atlas_path", "")
		).is_empty():
			_fail("%s should use its newer dedicated world art." % building_id)
			return

		var rotations := int(expected.get("rotations", 1))
		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
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
			var sprite_path := String(paths[rotation])
			if not ResourceLoader.exists(sprite_path):
				_fail(
					"%s rotation %d art should exist."
					% [building_id, rotation]
				)
				return
			var texture = load(sprite_path)
			if not (texture is Texture2D):
				_fail(
					"%s rotation %d should import as Texture2D."
					% [building_id, rotation]
				)
				return
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != sprite_path:
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
				"%s should retain its tuned dedicated draw size."
				% building_id
			)
			return

	for building_id_variant in CANONICAL_V2.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = CANONICAL_V2[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if String(definition.get("art_tier", "")) != "canonical_v2":
			_fail("%s should use the canonical v2 quality tier." % building_id)
			return
		if String(
			definition.get("world_sprite_atlas_path", "")
		) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
			_fail("%s should resolve to the canonical production atlas." % building_id)
			return
		var regions: Array = definition.get(
			"world_sprite_regions",
			[]
		)
		if regions.size() != int(expected.get("regions", 0)):
			_fail("%s should retain both canonical atlas views." % building_id)
			return
		if regions[0] != expected.get("first_region", Rect2()):
			_fail("%s should use its approved canonical atlas cell." % building_id)
			return
		var atlas = load(BuildingCatalog.PRODUCTION_BUILDING_ATLAS)
		if not (atlas is Texture2D):
			_fail("Canonical production building atlas should load.")
			return
		if definition.get("world_sprite_size", Vector2.ZERO) != expected.get(
			"size",
			Vector2.ZERO
		):
			_fail("%s should retain its measured canonical draw size." % building_id)
			return
		if grid._sprite_offset_for_rotation(
			definition,
			0
		) != expected.get("first_offset", Vector2.ZERO):
			_fail("%s should retain its measured tile alignment." % building_id)
			return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	var definitions: Array[Dictionary] = []
	for building_id_variant in STARTER_DEDICATED.keys():
		definitions.append(
			BuildingCatalog.get_definition(
				String(building_id_variant)
			)
		)
	for building_id_variant in CANONICAL_V2.keys():
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

		var atlas_path := String(
			definition.get("world_sprite_atlas_path", "")
		)
		if not atlas_path.is_empty():
			if not (button.icon is AtlasTexture):
				_fail("%s Build Tray should use canonical atlas art." % building_id)
				return
			var atlas_texture := button.icon as AtlasTexture
			if atlas_texture.atlas == null:
				_fail("%s atlas preview should retain its atlas texture." % building_id)
				return
			if String(atlas_texture.atlas.resource_path) != atlas_path:
				_fail("%s Build Tray should preview the canonical atlas." % building_id)
				return
			var regions: Array = definition.get("world_sprite_regions", [])
			if regions.is_empty() or atlas_texture.region != regions[0]:
				_fail("%s Build Tray should use its exact first atlas region." % building_id)
				return
		else:
			if button.icon is AtlasTexture:
				_fail("%s should use its newer dedicated sprite." % building_id)
				return
			var paths: PackedStringArray = definition.get(
				"world_sprite_paths",
				PackedStringArray()
			)
			if paths.is_empty() or String(button.icon.resource_path) != String(paths[0]):
				_fail("%s Build Tray should preview its exact world sprite." % building_id)
				return

	print(
		"STARTER_BUILDING_ART_OK terminal=dedicated fuel=dedicated "
		+ "ground_ops=canonical_v2 build_tray=production_art"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
