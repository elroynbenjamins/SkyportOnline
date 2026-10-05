extends SceneTree


const SERVICE_ART := {
	"cleaning_center": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_A,
		"regions": [
			Rect2(0, 0, 448, 448),
			Rect2(448, 0, 448, 448)
		],
		"size": Vector2(210, 210),
		"offsets": [
			Vector2(0, -38),
			Vector2(0, -38)
		]
	},
	"baggage_depot": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_A,
		"regions": [
			Rect2(0, 448, 448, 448),
			Rect2(448, 448, 448, 448)
		],
		"size": Vector2(210, 210),
		"offsets": [
			Vector2(0, -38),
			Vector2(0, -38)
		]
	},
	"catering_kitchen": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_A,
		"regions": [
			Rect2(0, 896, 448, 448),
			Rect2(448, 896, 448, 448)
		],
		"size": Vector2(210, 210),
		"offsets": [
			Vector2(0, -38),
			Vector2(0, -38)
		]
	},
	"tow_operations": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_B,
		"regions": [
			Rect2(0, 0, 448, 448),
			Rect2(448, 0, 448, 448)
		],
		"size": Vector2(210, 210),
		"offsets": [
			Vector2(0, -35),
			Vector2(0, -35)
		]
	},
	"rapid_small_fuel": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_B,
		"regions": [
			Rect2(0, 448, 448, 448),
			Rect2(448, 448, 448, 448)
		],
		"size": Vector2(220, 220),
		"offsets": [
			Vector2(0, -37),
			Vector2(0, -37)
		]
	},
	"atc_tower": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_B,
		"regions": [
			Rect2(0, 896, 448, 448),
			Rect2(448, 896, 448, 448)
		],
		"size": Vector2(228, 228),
		"offsets": [
			Vector2(0, -50),
			Vector2(0, -50)
		]
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for atlas_path in [
		BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_A,
		BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_B
	]:
		if not ResourceLoader.exists(atlas_path):
			_fail("Service-building v2 atlas should exist: %s" % atlas_path)
			return
		var atlas = load(atlas_path)
		if not (atlas is Texture2D):
			_fail("Service-building v2 atlas should import as Texture2D.")
			return
		if atlas.get_width() != 896 or atlas.get_height() != 1344:
			_fail("Service-building v2 atlases should import at 896x1344.")
			return
		var atlas_image := atlas.get_image()
		if atlas_image == null:
			_fail("Service-building v2 atlases should expose readable image data.")
			return
		for corner in [
			Vector2i(0, 0),
			Vector2i(895, 0),
			Vector2i(0, 1343),
			Vector2i(895, 1343)
		]:
			if atlas_image.get_pixelv(corner).a > 0.05:
				_fail("Service-building v2 atlas corners should remain transparent.")
				return
		for row in range(3):
			for column in range(2):
				var center := Vector2i(
					column * 448 + 224,
					row * 448 + 224
				)
				if atlas_image.get_pixelv(center).a < 0.50:
					_fail("Each service-building v2 cell should contain visible art.")
					return

	var definitions: Array[Dictionary] = []
	for building_id_variant in SERVICE_ART.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = SERVICE_ART[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return
		definitions.append(definition)

		if String(definition.get("art_tier", "")) != "canonical_v2":
			_fail("%s should use canonical v2 production art." % building_id)
			return
		var atlas_path := String(definition.get("world_sprite_atlas_path", ""))
		if atlas_path != String(expected.get("atlas", "")):
			_fail("%s should resolve to its approved service atlas." % building_id)
			return
		var legacy_paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not legacy_paths.is_empty():
			_fail("%s should no longer use airport_v1 world sprites." % building_id)
			return
		if not String(definition.get("world_sprite_path", "")).is_empty():
			_fail("%s should not use a standalone world sprite." % building_id)
			return

		var expected_regions: Array = expected.get("regions", [])
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions != expected_regions:
			_fail("%s should retain both approved v2 atlas views." % building_id)
			return
		for rotation in range(2):
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != atlas_path:
				_fail("%s rotation %d should resolve to its service atlas." % [building_id, rotation])
				return
			if grid._sprite_region_for_rotation(
				definition,
				rotation
			) != expected_regions[rotation]:
				_fail("%s rotation %d should resolve to the correct atlas cell." % [building_id, rotation])
				return

		if definition.get(
			"world_sprite_size",
			Vector2.ZERO
		) != expected.get("size", Vector2.ZERO):
			_fail("%s should retain its tuned v2 draw size." % building_id)
			return
		var offsets: Array = expected.get("offsets", [])
		for rotation in range(2):
			if grid._sprite_offset_for_rotation(
				definition,
				rotation
			) != offsets[rotation]:
				_fail("%s rotation %d should retain its tuned tile alignment." % [building_id, rotation])
				return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(definitions)
	await process_frame

	for definition in definitions:
		var building_id := String(definition.get("id", ""))
		if not hud.catalog_buttons.has(building_id):
			_fail("%s should remain available in the Build Tray." % building_id)
			return
		var button: Button = hud.catalog_buttons[building_id]
		if button.icon == null or not (button.icon is AtlasTexture):
			_fail("%s Build Tray card should use v2 atlas art." % building_id)
			return
		var preview := button.icon as AtlasTexture
		var atlas_path := String(definition.get("world_sprite_atlas_path", ""))
		if preview.atlas == null or String(preview.atlas.resource_path) != atlas_path:
			_fail("%s Build Tray should preview its exact service atlas." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty() or preview.region != regions[0]:
			_fail("%s Build Tray should preview the first v2 orientation." % building_id)
			return

	print(
		"SERVICE_BUILDING_ART_V2_OK cleaning=true baggage=true catering=true "
		+ "tow=true rapid_fuel=true atc=true views=12"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
