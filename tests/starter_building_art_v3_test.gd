extends SceneTree


const CANONICAL_V2 := {
	"small_terminal": {
		"regions": [
			Rect2(0, 0, 448, 448),
			Rect2(448, 0, 448, 448)
		],
		"size": Vector2(300, 300),
		"offsets": [
			Vector2(0, -55),
			Vector2(0, -60)
		]
	},
	"basic_fuel": {
		"regions": [
			Rect2(896, 448, 448, 448),
			Rect2(1344, 448, 448, 448)
		],
		"size": Vector2(188, 188),
		"offsets": [
			Vector2(0, -35),
			Vector2(0, -45)
		]
	},
	"ground_ops_depot": {
		"regions": [
			Rect2(0, 896, 448, 448),
			Rect2(448, 896, 448, 448)
		],
		"size": Vector2(116, 116),
		"offsets": [
			Vector2(0, -31),
			Vector2(0, -29)
		]
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var atlas = load(BuildingCatalog.PRODUCTION_BUILDING_ATLAS)
	if not (atlas is Texture2D):
		_fail("Canonical production building atlas should load.")
		return
	if atlas.get_width() != 1792 or atlas.get_height() != 1792:
		_fail("Canonical v2 building atlas should remain 1792x1792.")
		return

	var definitions: Array[Dictionary] = []
	for building_id_variant in CANONICAL_V2.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = CANONICAL_V2[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return
		definitions.append(definition)

		if String(definition.get("art_tier", "")) != "canonical_v2":
			_fail("%s should use the canonical v2 quality tier." % building_id)
			return
		if String(
			definition.get("world_sprite_atlas_path", "")
		) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
			_fail("%s should resolve to the canonical production atlas." % building_id)
			return
		if not String(
			definition.get("world_sprite_path", "")
		).is_empty():
			_fail("%s should not fall back to standalone legacy world art." % building_id)
			return
		var legacy_paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not legacy_paths.is_empty():
			_fail("%s should not fall back to starter-v3/v4 world art." % building_id)
			return

		var expected_regions: Array = expected.get("regions", [])
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.size() != expected_regions.size():
			_fail("%s should expose its approved canonical atlas views." % building_id)
			return
		for rotation in range(expected_regions.size()):
			if regions[rotation] != expected_regions[rotation]:
				_fail(
					"%s rotation %d should use its approved canonical atlas cell."
					% [building_id, rotation]
				)
				return
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
				_fail(
					"%s rotation %d should resolve to the canonical atlas."
					% [building_id, rotation]
				)
				return
			if grid._sprite_region_for_rotation(
				definition,
				rotation
			) != expected_regions[rotation]:
				_fail(
					"%s rotation %d should resolve to its canonical atlas region."
					% [building_id, rotation]
				)
				return

		if definition.get(
			"world_sprite_size",
			Vector2.ZERO
		) != expected.get("size", Vector2.ZERO):
			_fail("%s should retain its measured canonical draw size." % building_id)
			return

		var expected_offsets: Array = expected.get("offsets", [])
		for rotation in range(expected_offsets.size()):
			if grid._sprite_offset_for_rotation(
				definition,
				rotation
			) != expected_offsets[rotation]:
				_fail(
					"%s rotation %d should retain measured tile alignment."
					% [building_id, rotation]
				)
				return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(definitions)
	await process_frame

	for definition in definitions:
		var building_id := String(definition.get("id", ""))
		if not hud.catalog_buttons.has(building_id):
			_fail("%s should appear in the Build Tray." % building_id)
			return
		var button: Button = hud.catalog_buttons[building_id]
		if button.icon == null:
			_fail("%s Build Tray card should show canonical production art." % building_id)
			return
		if not (button.icon is AtlasTexture):
			_fail("%s Build Tray should use canonical v2 atlas art." % building_id)
			return
		var atlas_texture := button.icon as AtlasTexture
		if atlas_texture.atlas == null:
			_fail("%s atlas preview should retain its atlas texture." % building_id)
			return
		if String(
			atlas_texture.atlas.resource_path
		) != BuildingCatalog.PRODUCTION_BUILDING_ATLAS:
			_fail("%s Build Tray should preview the canonical atlas." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty() or atlas_texture.region != regions[0]:
			_fail("%s Build Tray should use its exact first atlas region." % building_id)
			return

	print(
		"STARTER_BUILDING_ART_OK terminal=canonical_v2 fuel=canonical_v2 "
		+ "ground_ops=canonical_v2 build_tray=canonical_atlas"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
