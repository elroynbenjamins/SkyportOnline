extends SceneTree


const RUNWAY_ICON := "res://assets/production/airfield_v2/runway_icon_v2.svg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not grid.has_method("_draw_runway_surface_v2"):
		_fail("AirportGrid should expose the runway-v2 surface renderer.")
		return
	if not grid.has_method("get_runway_surface_v2_snapshot"):
		_fail("AirportGrid should expose runway-v2 visual diagnostics.")
		return

	if not ResourceLoader.exists(RUNWAY_ICON):
		_fail("Runway v2 Build Tray icon should exist.")
		return
	var icon = load(RUNWAY_ICON)
	if not (icon is Texture2D):
		_fail("Runway v2 Build Tray icon should import as Texture2D.")
		return

	for runway_id in ["short_runway", "regional_runway"]:
		var definition := BuildingCatalog.get_definition(runway_id)
		if definition.is_empty():
			_fail("%s definition should exist." % runway_id)
			return
		if String(definition.get("art_tier", "")) != "surface_v2":
			_fail("%s should use the surface_v2 art tier." % runway_id)
			return
		if String(definition.get("surface_art", "")) != "runway_v2":
			_fail("%s should resolve to the runway_v2 renderer." % runway_id)
			return
		if String(definition.get("icon_path", "")) != RUNWAY_ICON:
			_fail("%s should use the v2 runway Build Tray icon." % runway_id)
			return

		if not String(definition.get("world_sprite_atlas_path", "")).is_empty():
			_fail("%s should not use a building atlas for its runway surface." % runway_id)
			return
		if not String(definition.get("world_sprite_path", "")).is_empty():
			_fail("%s should not use a standalone legacy world sprite." % runway_id)
			return
		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not paths.is_empty():
			_fail("%s should no longer use airport_v1 runway sprites." % runway_id)
			return

		var snapshot := grid.get_runway_surface_v2_snapshot(runway_id)
		if String(snapshot.get("art_tier", "")) != "surface_v2":
			_fail("%s visual snapshot should report surface_v2." % runway_id)
			return
		if String(snapshot.get("surface_art", "")) != "runway_v2":
			_fail("%s visual snapshot should report runway_v2." % runway_id)
			return
		if String(snapshot.get("icon_path", "")) != RUNWAY_ICON:
			_fail("%s visual snapshot should report the new icon." % runway_id)
			return
		if int(snapshot.get("edge_lights_min", 0)) < 5:
			_fail("%s should retain a minimum runway edge-light cadence." % runway_id)
			return

		var base_footprint: Vector2i = definition.get(
			"footprint",
			Vector2i.ZERO
		)
		if grid._footprint_for(definition, 0) != base_footprint:
			_fail("%s rotation 0 should retain its gameplay footprint." % runway_id)
			return
		if grid._footprint_for(definition, 1) != Vector2i(
			base_footprint.y,
			base_footprint.x
		):
			_fail("%s rotation 1 should swap the logical footprint." % runway_id)
			return

	var short_snapshot := grid.get_runway_surface_v2_snapshot("short_runway")
	if int(short_snapshot.get("threshold_bars", 0)) != 4:
		_fail("Short Runway should use four threshold bars per end.")
		return
	if int(short_snapshot.get("touchdown_zones", 0)) != 2:
		_fail("Short Runway should use the compact touchdown-zone treatment.")
		return

	var regional_snapshot := grid.get_runway_surface_v2_snapshot("regional_runway")
	if int(regional_snapshot.get("threshold_bars", 0)) != 6:
		_fail("Regional Runway should use denser threshold markings.")
		return
	if int(regional_snapshot.get("touchdown_zones", 0)) != 4:
		_fail("Regional Runway should use denser touchdown-zone markings.")
		return

	var airside := grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Starter airport should still expose exactly one runway.")
		return
	if int(airside.get("stands_connected", 0)) != 2:
		_fail("Runway visual replacement must preserve both starter departure routes.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog([
		BuildingCatalog.get_definition("short_runway"),
		BuildingCatalog.get_definition("regional_runway")
	])
	await process_frame
	for runway_id in ["short_runway", "regional_runway"]:
		if not hud.catalog_buttons.has(runway_id):
			_fail("%s should remain available in the Build Tray." % runway_id)
			return
		var button: Button = hud.catalog_buttons[runway_id]
		if button.icon == null:
			_fail("%s Build Tray card should show the v2 runway icon." % runway_id)
			return
		if button.icon is AtlasTexture:
			_fail("%s Build Tray icon should use the dedicated runway SVG." % runway_id)
			return
		if String(button.icon.resource_path) != RUNWAY_ICON:
			_fail("%s Build Tray should no longer show airport_v1 runway art." % runway_id)
			return

	print(
		"RUNWAY_SURFACE_V2_OK short=true regional=true legacy_world_sprites=false "
		+ "edge_lights=true thresholds=true touchdown=true build_tray=v2"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
