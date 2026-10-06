extends SceneTree


const REGIONAL_ART := {
	"medium_stand": {
		"atlas": BuildingCatalog.PRODUCTION_BUILDING_ATLAS,
		"regions": [
			Rect2(896, 0, 448, 448),
			Rect2(1344, 0, 448, 448)
		],
		"size": Vector2(276, 276),
		"offsets": [
			Vector2(0, -40),
			Vector2(0, -47)
		]
	},
	"regional_fuel": {
		"atlas": BuildingCatalog.PRODUCTION_BUILDING_ATLAS,
		"regions": [
			Rect2(896, 448, 448, 448),
			Rect2(1344, 448, 448, 448)
		],
		"size": Vector2(280, 280),
		"offsets": [
			Vector2(0, -52),
			Vector2(0, -67)
		]
	},
	"rapid_regional_fuel": {
		"atlas": BuildingCatalog.PRODUCTION_SERVICE_BUILDING_ATLAS_B,
		"regions": [
			Rect2(0, 448, 448, 448),
			Rect2(448, 448, 448, 448)
		],
		"size": Vector2(330, 330),
		"offsets": [
			Vector2(0, -93),
			Vector2(0, -91)
		]
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var definitions: Array[Dictionary] = []
	for building_id_variant in REGIONAL_ART.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = REGIONAL_ART[building_id_variant]
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
			_fail("%s should resolve to its approved canonical atlas." % building_id)
			return
		if not ResourceLoader.exists(atlas_path):
			_fail("%s canonical atlas should exist." % building_id)
			return

		var legacy_paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not legacy_paths.is_empty():
			_fail("%s should no longer use airport_v1 world sprites." % building_id)
			return
		if not String(definition.get("world_sprite_path", "")).is_empty():
			_fail("%s should not use a standalone legacy world sprite." % building_id)
			return

		var expected_regions: Array = expected.get("regions", [])
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions != expected_regions:
			_fail("%s should expose both approved v2 atlas views." % building_id)
			return

		for rotation in range(2):
			if grid._sprite_path_for_rotation(
				definition,
				rotation
			) != atlas_path:
				_fail("%s rotation %d should resolve to its canonical atlas." % [building_id, rotation])
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
			_fail("%s should retain its tuned regional v2 draw size." % building_id)
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
			_fail("%s Build Tray card should use canonical atlas art." % building_id)
			return
		var preview := button.icon as AtlasTexture
		var atlas_path := String(definition.get("world_sprite_atlas_path", ""))
		if preview.atlas == null or String(preview.atlas.resource_path) != atlas_path:
			_fail("%s Build Tray should preview its exact canonical atlas." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty() or preview.region != regions[0]:
			_fail("%s Build Tray should preview its first v2 orientation." % building_id)
			return

	if BuildingCatalog.get_definition("medium_stand").get("footprint", Vector2i.ZERO) != Vector2i(3, 3):
		_fail("Medium Stand gameplay footprint must remain 3x3.")
		return
	if int(BuildingCatalog.get_definition("regional_fuel").get("vehicle_capacity", 0)) != 2:
		_fail("Regional Fuel gameplay capacity must remain two vehicles.")
		return
	if int(BuildingCatalog.get_definition("rapid_regional_fuel").get("vehicle_capacity", 0)) != 3:
		_fail("Regional Rapid Fuel gameplay capacity must remain three vehicles.")
		return

	print(
		"REGIONAL_BUILDING_ART_V2_OK medium_stand=true regional_fuel=true "
		+ "rapid_regional_fuel=true views=6 gameplay_unchanged=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
