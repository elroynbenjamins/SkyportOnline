extends SceneTree


const PAVEMENT_ART := {
	"taxiway": {
		"surface_art": "taxiway_v2",
		"icon": "res://assets/production/airfield_v2/taxiway_icon_v2.svg"
	},
	"service_road": {
		"surface_art": "service_road_v2",
		"icon": "res://assets/production/airfield_v2/service_road_icon_v2.svg"
	},
	"apron_tile": {
		"surface_art": "apron_v2",
		"icon": "res://assets/production/airfield_v2/apron_icon_v2.svg"
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not grid.has_method("_draw_pavement_tile"):
		_fail("AirportGrid should retain the shared v2 pavement renderer.")
		return
	if not grid.has_method("_draw_taxiway_detail"):
		_fail("Taxiway should retain connectivity-aware centerline detail.")
		return
	if not grid.has_method("_draw_service_road_detail"):
		_fail("Service Road should retain connectivity-aware road detail.")
		return
	if not grid.has_method("_draw_apron_tile"):
		_fail("Apron Concrete should render as connected airport hardscape.")
		return
	if not grid.has_method("_apron_visually_connects_to"):
		_fail("Apron Concrete should merge cleanly with adjacent hardscape.")
		return

	var definitions: Array[Dictionary] = []
	for building_id_variant in PAVEMENT_ART.keys():
		var building_id := String(building_id_variant)
		var expected: Dictionary = PAVEMENT_ART[building_id_variant]
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition should exist." % building_id)
			return
		definitions.append(definition)

		if building_id == "apron_tile" and bool(definition.get("movable", true)):
			_fail("Apron Concrete should behave as fixed pavement after placement.")
			return

		if String(definition.get("art_tier", "")) != "surface_v2":
			_fail("%s should use the surface_v2 art tier." % building_id)
			return
		if String(definition.get("surface_art", "")) != String(
			expected.get("surface_art", "")
		):
			_fail("%s should resolve to its v2 pavement renderer." % building_id)
			return

		var icon_path := String(definition.get("icon_path", ""))
		if icon_path != String(expected.get("icon", "")):
			_fail("%s should use its production v2 Build Tray icon." % building_id)
			return
		if icon_path.contains("airport_v1"):
			_fail("%s should no longer expose an airport_v1 icon." % building_id)
			return
		if not ResourceLoader.exists(icon_path):
			_fail("%s v2 Build Tray icon should exist." % building_id)
			return
		var icon = load(icon_path)
		if not (icon is Texture2D):
			_fail("%s v2 Build Tray icon should import as Texture2D." % building_id)
			return

		if not String(definition.get("world_sprite_atlas_path", "")).is_empty():
			_fail("%s should remain a connectivity-aware surface, not a building atlas." % building_id)
			return
		if not String(definition.get("world_sprite_path", "")).is_empty():
			_fail("%s should not use a standalone world sprite." % building_id)
			return
		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not paths.is_empty():
			_fail("%s should not use legacy world-sprite variants." % building_id)
			return

	var snapshot := grid.get_airfield_detail_snapshot()
	if int(snapshot.get("taxiway_tiles", 0)) <= 0:
		_fail("Starter airport should still contain rendered taxiway tiles.")
		return
	if int(snapshot.get("taxiway_open_edges", -1)) < 0:
		_fail("Taxiway v2 should retain connectivity diagnostics.")
		return
	if int(snapshot.get("service_road_tiles", -1)) < 0:
		_fail("Service Road v2 should retain connectivity diagnostics.")
		return
	if int(snapshot.get("apron_tiles", -1)) < 0:
		_fail("Apron Concrete should expose surface diagnostics.")
		return
	if not grid._service_road_visually_connects_to(Vector2i(14, 13)):
		_fail("Service roads should visually terminate into service facilities.")
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
		if button.icon == null:
			_fail("%s Build Tray should show its v2 pavement icon." % building_id)
			return
		if button.icon is AtlasTexture:
			_fail("%s should use its dedicated production SVG icon." % building_id)
			return
		if String(button.icon.resource_path) != String(
			definition.get("icon_path", "")
		):
			_fail("%s Build Tray should preview the exact v2 icon." % building_id)
			return

	print(
		"AIRFIELD_PAVEMENT_V2_OK taxiway=true service_road=true apron=true "
		+ "legacy_icons=false connectivity=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
