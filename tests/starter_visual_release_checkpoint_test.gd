extends SceneTree

const FIRST_PRODUCTION_SET := [
	{
		"id": "small_terminal",
		"footprint": Vector2i(3, 2),
		"rotatable": true
	},
	{
		"id": "small_stand",
		"footprint": Vector2i(2, 2),
		"rotatable": true
	},
	{
		"id": "small_hangar",
		"footprint": Vector2i(3, 3),
		"rotatable": true
	},
	{
		"id": "basic_fuel",
		"footprint": Vector2i(2, 2),
		"rotatable": true
	},
	{
		"id": "ground_ops_depot",
		"footprint": Vector2i(1, 1),
		"rotatable": false
	},
	{
		"id": "travel_office",
		"footprint": Vector2i(2, 2),
		"rotatable": true
	},
	{
		"id": "shuttle_station",
		"footprint": Vector2i(3, 2),
		"rotatable": true
	},
	{
		"id": "passenger_service_hub",
		"footprint": Vector2i(2, 2),
		"rotatable": true
	}
]

const STARTER_PLACED_COUNTS := {
	"small_terminal": 1,
	"small_stand": 2,
	"basic_fuel": 1,
	"ground_ops_depot": 1,
	"travel_office": 1
}

const SERVICE_ROWS := {
	"fuel": 0,
	"passenger": 1,
	"cargo": 2,
	"cleaning": 3,
	"catering": 4,
	"pushback": 5
}

const DIRECTION_CASES := [
	{"name": "ne", "angle": -PI * 0.25, "column": 0},
	{"name": "se", "angle": PI * 0.25, "column": 1},
	{"name": "sw", "angle": PI * 0.75, "column": 2},
	{"name": "nw", "angle": -PI * 0.75, "column": 3}
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not _check_first_production_buildings(grid):
		return
	if not _check_starter_layout(grid):
		return
	if not _check_starter_routes(grid):
		return
	if not _check_environment_assets(grid):
		return
	if not _check_ground_service_art():
		return
	if not await _check_live_vehicle_heading_selection():
		return
	if not await _check_save_reload(grid):
		return

	print(
		"STARTER_VISUAL_RELEASE_CHECKPOINT_OK "
		+ "buildings=8 vehicles=6 directions=4 "
		+ "starter_routes=ok save_reload=ok"
	)
	quit(0)


func _check_first_production_buildings(
	grid: AirportGrid
) -> bool:
	for expected in FIRST_PRODUCTION_SET:
		var id := String(expected["id"])
		var definition := BuildingCatalog.get_definition(id)
		if definition.is_empty():
			return _fail_bool(
				"First production building missing from catalog: %s"
				% id
			)

		if definition.get(
			"footprint",
			Vector2i.ZERO
		) != expected["footprint"]:
			return _fail_bool(
				"%s footprint changed from the approved first set."
				% id
			)

		if bool(
			definition.get("rotatable", false)
		) != bool(expected["rotatable"]):
			return _fail_bool(
				"%s rotation behavior changed from the approved first set."
				% id
			)

		var icon_path := String(
			definition.get("icon_path", "")
		)
		if (
			icon_path.is_empty()
			or not ResourceLoader.exists(icon_path)
		):
			return _fail_bool(
				"%s has no loadable build-menu icon." % id
			)

		var draw_size: Vector2 = definition.get(
			"world_sprite_size",
			Vector2.ZERO
		)
		if draw_size.x <= 0.0 or draw_size.y <= 0.0:
			return _fail_bool(
				"%s has no valid world draw size." % id
			)

		if not grid._definition_has_world_sprite(
			definition
		):
			return _fail_bool(
				"%s would fall back to procedural world art."
				% id
			)

		var view_count := _world_view_count(definition)
		var required_views := (
			2 if bool(expected["rotatable"]) else 1
		)
		if view_count < required_views:
			return _fail_bool(
				"%s needs %d production view(s), found %d."
				% [id, required_views, view_count]
			)

		if not _check_world_sources(
			definition,
			required_views
		):
			return false

		if bool(expected["rotatable"]):
			var path_a := grid._sprite_path_for_rotation(
				definition,
				0
			)
			var path_b := grid._sprite_path_for_rotation(
				definition,
				1
			)
			var region_a := grid._sprite_region_for_rotation(
				definition,
				0
			)
			var region_b := grid._sprite_region_for_rotation(
				definition,
				1
			)

			var distinct := path_a != path_b
			if (
				region_a.size.x > 0.0
				and region_b.size.x > 0.0
			):
				distinct = distinct or region_a != region_b
			if not distinct:
				return _fail_bool(
					"%s A/B rotations resolve to the same art."
					% id
				)

			var footprint_a: Vector2i = grid._footprint_for(
				definition,
				0
			)
			var footprint_b: Vector2i = grid._footprint_for(
				definition,
				1
			)
			var expected_base: Vector2i = expected[
				"footprint"
			]
			if footprint_a != expected_base:
				return _fail_bool(
					"%s rotation A footprint is wrong." % id
				)
			var expected_b := Vector2i(
				expected_base.y,
				expected_base.x
			)
			if footprint_b != expected_b:
				return _fail_bool(
					"%s rotation B footprint is wrong." % id
				)

	return true


func _world_view_count(definition: Dictionary) -> int:
	var regions: Array = definition.get(
		"world_sprite_regions",
		[]
	)
	if not regions.is_empty():
		return regions.size()

	var paths: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if not paths.is_empty():
		return paths.size()

	return (
		1
		if not String(
			definition.get("world_sprite_path", "")
		).is_empty()
		else 0
	)


func _check_world_sources(
	definition: Dictionary,
	required_views: int
) -> bool:
	var id := String(definition.get("id", ""))
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	if not atlas_path.is_empty():
		if not ResourceLoader.exists(atlas_path):
			return _fail_bool(
				"%s production atlas path is missing." % id
			)
		var texture = load(atlas_path)
		if not (texture is Texture2D):
			return _fail_bool(
				"%s production atlas failed to import." % id
			)
		var regions: Array = definition.get(
			"world_sprite_regions",
			[]
		)
		if regions.size() < required_views:
			return _fail_bool(
				"%s production atlas has too few regions." % id
			)
		for index in range(required_views):
			var rect: Rect2 = regions[index]
			if (
				rect.position.x < 0.0
				or rect.position.y < 0.0
				or rect.size.x <= 0.0
				or rect.size.y <= 0.0
				or rect.end.x > float(texture.get_width())
				or rect.end.y > float(texture.get_height())
			):
				return _fail_bool(
					"%s atlas region %d lies outside the texture."
					% [id, index]
				)
		return true

	var paths: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if paths.is_empty():
		var one_path := String(
			definition.get("world_sprite_path", "")
		)
		if not one_path.is_empty():
			paths = PackedStringArray([one_path])

	if paths.size() < required_views:
		return _fail_bool(
			"%s standalone art has too few paths." % id
		)
	for index in range(required_views):
		var path := String(paths[index])
		if (
			path.is_empty()
			or not ResourceLoader.exists(path)
		):
			return _fail_bool(
				"%s rotation %d path is missing."
				% [id, index]
			)
		if not (load(path) is Texture2D):
			return _fail_bool(
				"%s rotation %d failed to import."
				% [id, index]
			)
	return true


func _check_starter_layout(grid: AirportGrid) -> bool:
	var counts := {}
	for building in grid.placed_buildings:
		var id := String(
			building.get("definition_id", "")
		)
		counts[id] = int(counts.get(id, 0)) + 1

	for id_variant in STARTER_PLACED_COUNTS.keys():
		var id := String(id_variant)
		if int(
			counts.get(id, 0)
		) != int(STARTER_PLACED_COUNTS[id]):
			return _fail_bool(
				"Starter airport expected %d x %s, found %d."
				% [
					int(STARTER_PLACED_COUNTS[id]),
					id,
					int(counts.get(id, 0))
				]
			)

	if int(counts.get("short_runway", 0)) < 1:
		return _fail_bool(
			"Starter airport lost its short runway."
		)
	if int(counts.get("taxiway", 0)) < 3:
		return _fail_bool(
			"Starter airport lost its taxiway spine."
		)
	if int(counts.get("service_road", 0)) < 1:
		return _fail_bool(
			"Starter airport lost its service-road network."
		)
	return true


func _check_starter_routes(grid: AirportGrid) -> bool:
	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		return _fail_bool(
			"Starter airport should expose two usable S stands."
		)

	var fuel_station := grid.get_best_service_building(
		"fuel",
		"S"
	)
	if String(
		fuel_station.get("definition_id", "")
	) != "basic_fuel":
		return _fail_bool(
			"Starter fuel route no longer resolves to Basic Fuel."
		)

	for route_info_variant in routes.slice(0, 2):
		var route_info: Dictionary = route_info_variant
		var stand_uid := int(
			route_info.get("stand_uid", -1)
		)
		var fuel_route := grid.get_service_route(
			int(fuel_station.get("uid", -1)),
			stand_uid
		)
		if fuel_route.size() < 2:
			return _fail_bool(
				"Basic Fuel cannot reach starter stand %d."
				% stand_uid
			)

		for service_type in [
			"passenger",
			"cargo",
			"cleaning",
			"catering",
			"pushback"
		]:
			var station := grid.get_best_service_building(
				service_type,
				"S"
			)
			if String(
				station.get("definition_id", "")
			) != "ground_ops_depot":
				return _fail_bool(
					"Starter %s should dispatch from Ground Ops."
					% service_type
				)
			var service_route := grid.get_service_route(
				int(station.get("uid", -1)),
				stand_uid
			)
			if service_route.size() < 2:
				return _fail_bool(
					"Ground Ops %s cannot reach starter stand %d."
					% [service_type, stand_uid]
				)
	return true


func _check_environment_assets(grid: AirportGrid) -> bool:
	var runway := BuildingCatalog.get_definition(
		"short_runway"
	)
	var runway_paths: PackedStringArray = runway.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if runway_paths.size() < 2:
		return _fail_bool(
			"Short runway needs both approved orientations."
		)
	if runway_paths[0] == runway_paths[1]:
		return _fail_bool(
			"Short runway A/B art must be distinct."
		)
	for path in runway_paths:
		if not ResourceLoader.exists(String(path)):
			return _fail_bool(
				"Short runway art is missing: %s"
				% String(path)
			)

	var taxiway := BuildingCatalog.get_definition("taxiway")
	var service_road := BuildingCatalog.get_definition(
		"service_road"
	)
	for definition in [taxiway, service_road]:
		var icon_path := String(
			definition.get("icon_path", "")
		)
		if (
			icon_path.is_empty()
			or not ResourceLoader.exists(icon_path)
		):
			return _fail_bool(
				"%s build icon is missing."
				% String(definition.get("id", ""))
			)

	var connected_taxiways := 0
	for building in grid.placed_buildings:
		if String(
			building.get("definition_id", "")
		) != "taxiway":
			continue
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		if grid.get_taxiway_connection_count(origin) > 0:
			connected_taxiways += 1
	if connected_taxiways < 3:
		return _fail_bool(
			"Starter taxiway visuals/network are not connected."
		)
	return true


func _check_ground_service_art() -> bool:
	var texture := GroundServiceVehicleArt.texture()
	if texture == null:
		return _fail_bool(
			"Ground-service production atlas failed to load."
		)

	var required_width := int(
		GroundServiceVehicleArt.CELL_SIZE * 4.0
	)
	var required_height := int(
		GroundServiceVehicleArt.CELL_SIZE * 6.0
	)
	if (
		texture.get_width() < required_width
		or texture.get_height() < required_height
	):
		return _fail_bool(
			"Ground-service atlas is smaller than its 4x6 layout."
		)

	var seen_rects := {}
	for service_variant in SERVICE_ROWS.keys():
		var service := String(service_variant)
		var world_size := GroundServiceVehicleArt.world_size(
			service
		)
		if (
			world_size.x < 40.0
			or world_size.y < 40.0
			or world_size.x > 80.0
			or world_size.y > 80.0
		):
			return _fail_bool(
				"%s service vehicle has an invalid world size."
				% service
			)

		for case_variant in DIRECTION_CASES:
			var case: Dictionary = case_variant
			var direction := GroundServiceVehicleArt.direction_for(
				float(case["angle"])
			)
			if direction != String(case["name"]):
				return _fail_bool(
					"Direction mapping failed for %s."
					% String(case["name"])
				)

			var rect := GroundServiceVehicleArt.source_rect(
				service,
				float(case["angle"])
			)
			var expected_pos := Vector2(
				float(case["column"])
				* GroundServiceVehicleArt.CELL_SIZE,
				float(SERVICE_ROWS[service])
				* GroundServiceVehicleArt.CELL_SIZE
			)
			if rect.position != expected_pos:
				return _fail_bool(
					"%s %s resolves to wrong atlas cell."
					% [service, String(case["name"])]
				)
			if rect.size != Vector2(
				GroundServiceVehicleArt.CELL_SIZE,
				GroundServiceVehicleArt.CELL_SIZE
			):
				return _fail_bool(
					"%s %s cell has wrong dimensions."
					% [service, String(case["name"])]
				)
			if (
				rect.end.x > float(texture.get_width())
				or rect.end.y > float(texture.get_height())
			):
				return _fail_bool(
					"%s %s cell exceeds atlas bounds."
					% [service, String(case["name"])]
				)

			var key := "%d,%d" % [
				int(rect.position.x),
				int(rect.position.y)
			]
			if seen_rects.has(key):
				return _fail_bool(
					"Two service/direction sprites share atlas cell %s."
					% key
				)
			seen_rects[key] = true

	if seen_rects.size() != 24:
		return _fail_bool(
			"Expected 24 unique service vehicle views, found %d."
			% seen_rects.size()
		)
	return true


func _check_live_vehicle_heading_selection() -> bool:
	for case_variant in DIRECTION_CASES:
		var case: Dictionary = case_variant
		var angle := float(case["angle"])
		var direction_vector := Vector2.RIGHT.rotated(angle)
		var route := PackedVector2Array([
			Vector2.ZERO,
			direction_vector * 100.0
		])

		var vehicle := GroundServiceVehiclePrototype.new()
		root.add_child(vehicle)
		await process_frame
		if (
			vehicle.texture_filter
			!= CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		):
			return _fail_bool(
				"Ground service vehicle is not using smooth filtering."
			)
		vehicle.position = Vector2.ZERO
		vehicle.route_index = 0
		vehicle._follow_route(route, 0.01)
		var selected := GroundServiceVehicleArt.direction_for(
			vehicle.rotation
		)
		if selected != String(case["name"]):
			return _fail_bool(
				"Live vehicle heading did not select %s sprite."
				% String(case["name"])
			)
		vehicle.queue_free()

	var fuel := FuelTruckPrototype.new()
	root.add_child(fuel)
	await process_frame
	if (
		fuel.texture_filter
		!= CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	):
		return _fail_bool(
			"Fuel tanker is not using smooth filtering."
		)
	fuel.queue_free()
	return true


func _check_save_reload(grid: AirportGrid) -> bool:
	var saved_layout := grid.export_airport_layout()
	var saved_parcels := grid.export_owned_parcels()
	var saved_storage := grid.export_airport_storage()

	var restored := AirportGrid.new()
	root.add_child(restored)
	await process_frame
	if not restored.apply_saved_airport_layout(
		saved_layout,
		saved_parcels,
		saved_storage
	):
		return _fail_bool(
			"Starter airport failed its save/reload cycle."
		)

	var before := _layout_signature(saved_layout)
	var after := _layout_signature(
		restored.export_airport_layout()
	)
	if before != after:
		return _fail_bool(
			"Starter airport layout changed after save/reload."
		)

	for expected in FIRST_PRODUCTION_SET:
		var definition := BuildingCatalog.get_definition(
			String(expected["id"])
		)
		if definition.is_empty():
			return _fail_bool(
				"Production definition disappeared after reload."
			)

	restored.queue_free()
	return true


func _layout_signature(layout: Array) -> String:
	var parts: Array[String] = []
	for item_variant in layout:
		var item: Dictionary = item_variant
		parts.append(
			"%d:%s:%d:%d:%d:%d"
			% [
				int(item.get("uid", -1)),
				String(item.get("definition_id", "")),
				int(item.get("x", -1)),
				int(item.get("y", -1)),
				int(item.get("rotation", 0)),
				int(item.get("upgrade_level", 1))
			]
		)
	parts.sort()
	return "|".join(parts)


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
