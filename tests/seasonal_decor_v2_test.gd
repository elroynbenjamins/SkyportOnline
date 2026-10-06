extends SceneTree


const DECOR := {
	"autumn_event_flag": {
		"regions": [
			Rect2(0, 0, 256, 256)
		],
		"size": Vector2(112, 112),
		"offsets": [
			Vector2(0, -37)
		]
	},
	"autumn_leaf_garden": {
		"regions": [
			Rect2(256, 0, 256, 256),
			Rect2(512, 0, 256, 256)
		],
		"size": Vector2(150, 150),
		"offsets": [
			Vector2(0, -35),
			Vector2(0, -35)
		]
	},
	"winter_event_flag": {
		"regions": [
			Rect2(768, 0, 256, 256)
		],
		"size": Vector2(112, 112),
		"offsets": [
			Vector2(0, -37)
		]
	},
	"winter_snow_globe_garden": {
		"regions": [
			Rect2(0, 256, 256, 256),
			Rect2(256, 256, 256, 256)
		],
		"size": Vector2(154, 154),
		"offsets": [
			Vector2(0, -37),
			Vector2(0, -37)
		]
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var atlas_path := BuildingCatalog.PRODUCTION_SEASONAL_DECOR_ATLAS
	if not ResourceLoader.exists(atlas_path):
		_fail("Seasonal v2 decoration atlas should exist.")
		return
	var atlas = load(atlas_path)
	if not (atlas is Texture2D):
		_fail("Seasonal v2 decoration atlas should import as Texture2D.")
		return
	if atlas.get_width() != 1024 or atlas.get_height() != 512:
		_fail("Seasonal v2 decoration atlas should import at 1024x512.")
		return

	var atlas_image: Image = atlas.get_image()
	if atlas_image == null:
		_fail("Seasonal v2 decoration atlas should expose readable image data.")
		return
	for corner in [
		Vector2i(0, 0),
		Vector2i(1023, 0),
		Vector2i(0, 511),
		Vector2i(1023, 511)
	]:
		if atlas_image.get_pixelv(corner).a > 0.05:
			_fail("Seasonal v2 atlas corners should remain transparent.")
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var definitions: Array[Dictionary] = []
	for building_id_variant in DECOR.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = DECOR[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return
		definitions.append(definition)

		if String(definition.get("art_tier", "")) != "seasonal_v2":
			_fail("%s should use seasonal_v2 art." % building_id)
			return
		if bool(definition.get("world_ground_pad", true)):
			_fail("%s should use its authored decorative ground base." % building_id)
			return
		if String(
			definition.get("world_sprite_atlas_path", "")
		) != atlas_path:
			_fail("%s should resolve to the seasonal v2 atlas." % building_id)
			return
		if not grid._definition_has_world_sprite(definition):
			_fail("%s should render through authored world art." % building_id)
			return

		var expected_regions: Array = expected.get("regions", [])
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions != expected_regions:
			_fail("%s should retain its approved seasonal atlas views." % building_id)
			return
		for rotation in range(maxi(regions.size(), 1)):
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != atlas_path:
				_fail("%s rotation %d should resolve to the seasonal atlas." % [building_id, rotation])
				return
			if grid._sprite_region_for_rotation(
				definition,
				rotation
			) != regions[rotation % regions.size()]:
				_fail("%s rotation %d should resolve to its seasonal atlas region." % [building_id, rotation])
				return

		if definition.get(
			"world_sprite_size",
			Vector2.ZERO
		) != expected.get("size", Vector2.ZERO):
			_fail("%s should retain its tuned seasonal draw size." % building_id)
			return

		var offsets: Array = expected.get("offsets", [])
		for rotation in range(offsets.size()):
			if grid._sprite_offset_for_rotation(
				definition,
				rotation
			) != offsets[rotation]:
				_fail("%s rotation %d should retain tuned tile alignment." % [building_id, rotation])
				return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(definitions)
	await process_frame

	for definition in definitions:
		var building_id := String(definition.get("id", ""))
		if not hud.catalog_buttons.has(building_id):
			_fail("%s should render when explicitly present in the Build Tray." % building_id)
			return
		var button: Button = hud.catalog_buttons[building_id]
		if button.icon == null or not (button.icon is AtlasTexture):
			_fail("%s Build Tray should preview seasonal v2 atlas art." % building_id)
			return
		var preview := button.icon as AtlasTexture
		if preview.atlas == null or String(preview.atlas.resource_path) != atlas_path:
			_fail("%s Build Tray should use the exact seasonal v2 atlas." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if preview.region != regions[0]:
			_fail("%s Build Tray should preview its first seasonal orientation." % building_id)
			return

	print(
		"SEASONAL_DECOR_V2_OK autumn_flag=true autumn_garden=true "
		+ "winter_flag=true snow_globe=true authored_ground=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
