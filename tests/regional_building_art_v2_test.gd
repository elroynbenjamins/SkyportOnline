extends SceneTree


const REGIONAL_ART := {
	"medium_stand": {
		"regions": [
			Rect2(0, 0, 384, 384),
			Rect2(384, 0, 384, 384)
		],
		"size": Vector2(300, 300),
		"offsets": [
			Vector2(0, -77),
			Vector2(0, -77)
		]
	},
	"regional_fuel": {
		"regions": [
			Rect2(0, 384, 384, 384),
			Rect2(384, 384, 384, 384)
		],
		"size": Vector2(306, 306),
		"offsets": [
			Vector2(0, -81),
			Vector2(0, -81)
		]
	},
	"rapid_regional_fuel": {
		"regions": [
			Rect2(0, 768, 384, 384),
			Rect2(384, 768, 384, 384)
		],
		"size": Vector2(348, 348),
		"offsets": [
			Vector2(0, -98),
			Vector2(0, -98)
		]
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var atlas_path := BuildingCatalog.PRODUCTION_REGIONAL_FACILITIES_ATLAS
	if not ResourceLoader.exists(atlas_path):
		_fail("Regional facilities v2 atlas should exist.")
		return
	var atlas = load(atlas_path)
	if not (atlas is Texture2D):
		_fail("Regional facilities v2 atlas should import as Texture2D.")
		return
	if atlas.get_width() != 768 or atlas.get_height() != 1152:
		_fail("Regional facilities v2 atlas should import at 768x1152.")
		return

	var atlas_image: Image = atlas.get_image()
	if atlas_image == null:
		_fail("Regional facilities v2 atlas should expose readable image data.")
		return
	for corner in [
		Vector2i(0, 0),
		Vector2i(767, 0),
		Vector2i(0, 1151),
		Vector2i(767, 1151)
	]:
		if atlas_image.get_pixelv(corner).a > 0.05:
			_fail("Regional facilities v2 atlas corners should remain transparent.")
			return

	var definitions: Array[Dictionary] = []
	for building_id_variant in REGIONAL_ART.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = REGIONAL_ART[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return
		definitions.append(definition)

		if String(definition.get("art_tier", "")) != "regional_v2":
			_fail("%s should use its unique regional_v2 art tier." % building_id)
			return
		if bool(definition.get("world_ground_pad", true)):
			_fail("%s should use its authored regional ground base." % building_id)
			return

		if String(definition.get("world_sprite_atlas_path", "")) != atlas_path:
			_fail("%s should resolve to the unique regional facilities atlas." % building_id)
			return

		var legacy_paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not legacy_paths.is_empty():
			_fail("%s should not use legacy or starter world sprites." % building_id)
			return
		if not String(definition.get("world_sprite_path", "")).is_empty():
			_fail("%s should not use a standalone legacy world sprite." % building_id)
			return
		if not String(definition.get("icon_path", "")).is_empty():
			_fail("%s should not retain an airport_v1 fallback icon." % building_id)
			return

		var expected_regions: Array = expected.get("regions", [])
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions != expected_regions:
			_fail("%s should expose both authored regional orientations." % building_id)
			return

		for rotation in range(2):
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != atlas_path:
				_fail("%s rotation %d should resolve to the regional atlas." % [building_id, rotation])
				return
			if grid._sprite_region_for_rotation(
				definition,
				rotation
			) != expected_regions[rotation]:
				_fail("%s rotation %d should resolve to the correct regional atlas cell." % [building_id, rotation])
				return

		if definition.get(
			"world_sprite_size",
			Vector2.ZERO
		) != expected.get("size", Vector2.ZERO):
			_fail("%s should retain its tuned regional draw size." % building_id)
			return

		var offsets: Array = expected.get("offsets", [])
		for rotation in range(2):
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
			_fail("%s should remain available in the Build Tray." % building_id)
			return
		var button: Button = hud.catalog_buttons[building_id]
		if button.icon == null or not (button.icon is AtlasTexture):
			_fail("%s Build Tray card should use unique regional atlas art." % building_id)
			return
		var preview := button.icon as AtlasTexture
		if preview.atlas == null or String(preview.atlas.resource_path) != atlas_path:
			_fail("%s Build Tray should preview the regional facilities atlas." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty() or preview.region != regions[0]:
			_fail("%s Build Tray should preview its first authored orientation." % building_id)
			return

	if BuildingCatalog.get_definition("medium_stand").get("footprint", Vector2i.ZERO) != Vector2i(4, 3):
		_fail("Medium Stand should use the roomier 4x3 gameplay footprint.")
		return
	if BuildingCatalog.get_definition("regional_fuel").get("footprint", Vector2i.ZERO) != Vector2i(4, 3):
		_fail("Regional Fuel should use the roomier 4x3 gameplay footprint.")
		return
	if BuildingCatalog.get_definition("rapid_regional_fuel").get("footprint", Vector2i.ZERO) != Vector2i(5, 4):
		_fail("Regional Rapid Fuel should use the roomier 5x4 gameplay footprint.")
		return
	if int(BuildingCatalog.get_definition("regional_fuel").get("vehicle_capacity", 0)) != 2:
		_fail("Regional Fuel gameplay capacity must remain two vehicles.")
		return
	if int(BuildingCatalog.get_definition("rapid_regional_fuel").get("vehicle_capacity", 0)) != 3:
		_fail("Regional Rapid Fuel gameplay capacity must remain three vehicles.")
		return

	print(
		"REGIONAL_BUILDING_ART_V2_OK unique=true medium_stand=true regional_fuel=true "
		+ "rapid_regional_fuel=true views=6 scale_rebalanced=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
