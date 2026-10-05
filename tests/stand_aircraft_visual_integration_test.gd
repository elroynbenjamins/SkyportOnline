extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var stand_definition := BuildingCatalog.get_definition(
		"small_stand"
	)
	if String(
		stand_definition.get("art_tier", "")
	) != "starter_v4":
		_fail("Small Stand should use the starter_v4 production art tier.")
		return
	if not String(
		stand_definition.get("world_sprite_atlas_path", "")
	).is_empty():
		_fail("Small Stand should no longer depend on the legacy building atlas.")
		return

	var stand_paths: PackedStringArray = stand_definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if stand_paths.size() != 2:
		_fail("Small Stand should expose two true isometric orientations.")
		return
	if stand_paths[0] == stand_paths[1]:
		_fail("Small Stand orientations should use distinct production files.")
		return
	for rotation in range(2):
		var path := String(stand_paths[rotation])
		if not ResourceLoader.exists(path):
			_fail("Small Stand rotation %d art is missing." % rotation)
			return
		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Small Stand rotation %d should import as Texture2D." % rotation)
			return
		if grid._sprite_path_for_rotation(
			stand_definition,
			rotation
		) != path:
			_fail("Stand rotation %d should resolve to its dedicated art." % rotation)
			return

	if stand_definition.get(
		"world_sprite_size",
		Vector2.ZERO
	) != Vector2(208, 156):
		_fail("Small Stand should retain its tuned starter-v4 world size.")
		return

	var starter_stands: Array[Dictionary] = []
	for building in grid.placed_buildings:
		if String(
			building.get("definition_id", "")
		) == "small_stand":
			starter_stands.append(building)
	if starter_stands.size() != 2:
		_fail("Starter airport should still contain exactly two Small Stands.")
		return

	for stand in starter_stands:
		var stand_uid := int(stand.get("uid", -1))
		var route_info := grid.get_departure_route_for_stand(
			stand_uid,
			"S"
		)
		if route_info.is_empty():
			_fail("Starter stand %d should keep an S-class departure route." % stand_uid)
			return
		var route: PackedVector2Array = route_info.get(
			"route",
			PackedVector2Array()
		)
		if route.is_empty():
			_fail("Starter stand route should include its parking point.")
			return
		var footprint: Vector2i = stand_definition.get(
			"footprint",
			Vector2i.ONE
		)
		var expected_center := grid._footprint_center_world(
			stand.get("origin", Vector2i.ZERO),
			footprint
		)
		if route[0].distance_to(expected_center) > 0.01:
			_fail("Parked aircraft should remain centered on the stand guidance geometry.")
			return
		if route[0].distance_to(
			route_info.get(
				"stand_world_position",
				Vector2.ZERO
			)
		) > 0.01:
			_fail("Stand route metadata should use the same parking center.")
			return

	var ids := [
		"pico_p8",
		"swift_s14",
		"comet_c22",
		"voyager_v32",
		"nimbus_n40"
	]
	var widths: Dictionary = {}
	var fuel_distances: Dictionary = {}
	var passenger_distances: Dictionary = {}

	for aircraft_id in ids:
		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)
		if plane.direction_textures.size() < 4:
			_fail("%s should load four directional production sprites." % aircraft_id)
			return
		var width := plane.get_directional_draw_width()
		widths[aircraft_id] = width
		fuel_distances[aircraft_id] = (
			plane.get_service_docking_local_offset("fuel").length()
		)
		passenger_distances[aircraft_id] = (
			plane.get_service_docking_local_offset("passenger").length()
		)
		if float(fuel_distances[aircraft_id]) <= width * 0.45:
			_fail("%s fuel vehicle should park outside the visible wing area." % aircraft_id)
			return
		plane.queue_free()

	if not (
		float(widths["pico_p8"])
		< float(widths["swift_s14"])
		and float(widths["swift_s14"])
		< float(widths["comet_c22"])
		and float(widths["comet_c22"])
		< float(widths["voyager_v32"])
	):
		_fail("Directional S-class sprites should grow from Pico through Voyager.")
		return

	if float(widths["voyager_v32"]) >= 96.0:
		_fail("Largest S aircraft should remain comfortably inside the 2x2 stand.")
		return
	if float(widths["nimbus_n40"]) <= float(widths["voyager_v32"]):
		_fail("First M aircraft should render larger than the largest S aircraft.")
		return

	if not (
		float(fuel_distances["pico_p8"])
		< float(fuel_distances["voyager_v32"])
		and float(
			passenger_distances["pico_p8"]
		) < float(
			passenger_distances["voyager_v32"]
		)
	):
		_fail("Service parking should move outward as S-class aircraft grow.")
		return

	var visitor := CareerAircraft.new()
	root.add_child(visitor)
	await process_frame
	visitor.configure_aircraft_type("pico_p8")
	visitor.configure_social_visit({
		"relationship": "npc",
		"airport_name": "NPC Test"
	})
	if not visitor.is_social_visitor():
		_fail("Directional production aircraft should retain visitor/NPC behavior.")
		return
	if visitor.direction_textures.size() < 4:
		_fail("Visitor/NPC aircraft should use the same directional production art.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog([stand_definition])
	await process_frame
	if not hud.catalog_buttons.has("small_stand"):
		_fail("Small Stand should remain available in the Build Tray.")
		return
	var stand_button: Button = hud.catalog_buttons["small_stand"]
	if stand_button.icon == null:
		_fail("Small Stand Build Tray card should show production art.")
		return
	if stand_button.icon is AtlasTexture:
		_fail("Small Stand Build Tray should not fall back to the legacy atlas.")
		return
	if String(stand_button.icon.resource_path) != String(stand_paths[0]):
		_fail("Small Stand Build Tray should preview its exact first world-art orientation.")
		return

	var card := BuildingContextCard.new()
	root.add_child(card)
	await process_frame
	card.show_building(
		starter_stands[0],
		{
			"role": "Infrastructure",
			"status": "Stand ready",
			"tone": "success",
			"stat_one": "AIRCRAFT\nS",
			"stat_two": "FOOTPRINT\n2x2"
		}
	)
	if card.building_image.texture == null:
		_fail("Small Stand context card should show production art.")
		return
	if card.building_image.texture is AtlasTexture:
		_fail("Small Stand context card should use starter-v4 art.")
		return
	if String(
		card.building_image.texture.resource_path
	) != String(stand_paths[0]):
		_fail("Small Stand context card should preview its exact world sprite.")
		return

	var apron_snapshot := grid.get_apron_micro_detail_snapshot()
	if int(apron_snapshot.get("stand_service_zones", 0)) != 4:
		_fail("Dedicated stand art must preserve two live service zones per starter stand.")
		return

	print(
		"STAND_AIRCRAFT_VISUAL_OK pico=%.1f voyager=%.1f nimbus=%.1f "
		+ "stand_angles=2 visitor_directional=true service_scale=true"
		% [
			float(widths["pico_p8"]),
			float(widths["voyager_v32"]),
			float(widths["nimbus_n40"])
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
