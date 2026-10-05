extends SceneTree

const HUD_SCRIPT := preload("res://src/ui/HUD.gd")

const STARTER_VISUAL_IDS: Array[String] = [
	"small_terminal",
	"small_stand",
	"small_hangar",
	"basic_fuel",
	"ground_ops_depot",
	"travel_office",
	"shuttle_station",
	"passenger_service_hub"
]

const STARTER_LAYOUT_COUNTS := {
	"short_runway": 1,
	"taxiway": 3,
	"small_stand": 2,
	"small_terminal": 1,
	"travel_office": 1,
	"ground_ops_depot": 1,
	"basic_fuel": 1,
	"service_road": 10
}

const SERVICE_TYPES: Array[String] = [
	"fuel",
	"passenger",
	"cargo",
	"cleaning",
	"catering",
	"pushback"
]

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	_check_starter_world_art(grid)
	_check_starter_layout_and_reload(grid)
	_check_ground_service_atlas()
	await _check_build_drawer_uses_world_art()

	grid.queue_free()

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print("STARTER_VISUAL_INTEGRATION_OK")
	quit(0)


func _check_starter_world_art(grid: AirportGrid) -> void:
	for building_id in STARTER_VISUAL_IDS:
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s definition is missing." % building_id)
			continue

		if not grid._definition_has_world_sprite(definition):
			_fail("%s should have production world art." % building_id)
			continue

		var rotations := 2 if bool(definition.get("rotatable", false)) else 1
		for rotation in range(rotations):
			var path := grid._sprite_path_for_rotation(
				definition,
				rotation
			)
			if path.is_empty() or not ResourceLoader.exists(path):
				_fail(
					"%s rotation %d world texture is missing: %s"
					% [building_id, rotation, path]
				)
				continue

			var texture_resource = load(path)
			if not (texture_resource is Texture2D):
				_fail(
					"%s rotation %d world texture failed to load."
					% [building_id, rotation]
				)
				continue

			var region := grid._sprite_region_for_rotation(
				definition,
				rotation
			)
			if not String(
				definition.get("world_sprite_atlas_path", "")
			).is_empty():
				if region.size.x <= 0.0 or region.size.y <= 0.0:
					_fail(
						"%s rotation %d has no production atlas region."
						% [building_id, rotation]
					)
					continue
				var texture := texture_resource as Texture2D
				if (
					region.end.x > float(texture.get_width())
					or region.end.y > float(texture.get_height())
				):
					_fail(
						"%s rotation %d atlas region exceeds texture bounds."
						% [building_id, rotation]
					)

			var draw_size: Vector2 = definition.get(
				"world_sprite_size",
				Vector2.ZERO
			)
			if draw_size.x <= 0.0 or draw_size.y <= 0.0:
				_fail("%s has invalid world draw size." % building_id)

			var offset := grid._sprite_offset_for_rotation(
				definition,
				rotation
			)
			if not (offset is Vector2):
				_fail(
					"%s rotation %d has invalid sprite offset."
					% [building_id, rotation]
				)


func _check_starter_layout_and_reload(grid: AirportGrid) -> void:
	var layout := grid.export_airport_layout()
	var counts: Dictionary = {}
	for item_variant in layout:
		var item: Dictionary = item_variant
		var id := String(item.get("definition_id", ""))
		counts[id] = int(counts.get(id, 0)) + 1

	var expected_total := 0
	for id_variant in STARTER_LAYOUT_COUNTS.keys():
		var id := String(id_variant)
		var expected := int(STARTER_LAYOUT_COUNTS[id_variant])
		expected_total += expected
		if int(counts.get(id, 0)) != expected:
			_fail(
				"Starter layout %s count should be %d, got %d."
				% [id, expected, int(counts.get(id, 0))]
			)

	if layout.size() != expected_total:
		_fail(
			"Starter layout should contain %d placed objects, got %d."
			% [expected_total, layout.size()]
		)

	var airside := grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Starter airport should still expose one runway.")
	if int(airside.get("stands_total", 0)) != 2:
		_fail("Starter airport should still expose two stands.")
	if int(airside.get("stands_connected", 0)) != 2:
		_fail("Both starter stands should remain airside-connected.")

	var departure_routes := grid.get_departure_routes("S")
	if departure_routes.size() != 2:
		_fail("Starter airport should keep two S departure routes.")

	var fuel := grid.get_best_service_building("fuel", "S")
	if String(fuel.get("definition_id", "")) != "basic_fuel":
		_fail("Starter airport should still dispatch fuel from basic_fuel.")

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
		_fail("Starter airport visual changes must not break saved-layout reload.")
	else:
		var restored_layout := restored.export_airport_layout()
		if restored_layout.size() != saved_layout.size():
			_fail(
				"Reloaded starter layout changed object count (%d -> %d)."
				% [saved_layout.size(), restored_layout.size()]
			)
		var restored_airside := restored.get_airside_status()
		if int(restored_airside.get("stands_connected", 0)) != 2:
			_fail("Reloaded starter layout should keep both stands connected.")

	restored.queue_free()


func _check_ground_service_atlas() -> void:
	var atlas := GroundServiceVehicleArt.texture()
	if atlas == null:
		_fail("Ground-service production atlas failed to load.")
		return

	if atlas.get_width() != 1024 or atlas.get_height() != 1536:
		_fail(
			"Ground-service atlas should be 1024x1536, got %dx%d."
			% [atlas.get_width(), atlas.get_height()]
		)

	var image := atlas.get_image()
	if image == null or image.is_empty():
		_fail("Ground-service atlas has no readable image.")
		return

	var direction_angles := {
		"ne": -PI / 4.0,
		"se": PI / 4.0,
		"sw": 3.0 * PI / 4.0,
		"nw": -3.0 * PI / 4.0
	}

	for service_type in SERVICE_TYPES:
		for direction_variant in direction_angles.keys():
			var direction := String(direction_variant)
			var angle := float(direction_angles[direction_variant])
			if GroundServiceVehicleArt.direction_for(angle) != direction:
				_fail(
					"%s heading mapping should resolve to %s."
					% [service_type, direction]
				)
				continue

			var source := GroundServiceVehicleArt.source_rect(
				service_type,
				angle
			)
			var source_i := Rect2i(
				int(source.position.x),
				int(source.position.y),
				int(source.size.x),
				int(source.size.y)
			)
			if (
				source_i.position.x < 0
				or source_i.position.y < 0
				or source_i.end.x > image.get_width()
				or source_i.end.y > image.get_height()
			):
				_fail(
					"%s %s sprite region exceeds service atlas."
					% [service_type, direction]
				)
				continue

			var cell := image.get_region(source_i)
			if _alpha_used_rect(cell).size == Vector2i.ZERO:
				_fail(
					"%s %s service sprite has no visible pixels."
					% [service_type, direction]
				)


func _check_build_drawer_uses_world_art() -> void:
	var hud = HUD_SCRIPT.new()
	root.add_child(hud)
	await process_frame

	var definitions: Array[Dictionary] = []
	for building_id in STARTER_VISUAL_IDS:
		definitions.append(
			BuildingCatalog.get_definition(building_id)
		)

	hud.set_build_catalog(definitions)
	await process_frame

	for definition in definitions:
		var id := String(definition.get("id", ""))
		if not hud.catalog_buttons.has(id):
			_fail("%s should appear in the build drawer." % id)
			continue

		var button: Button = hud.catalog_buttons[id]
		if button.icon == null:
			_fail("%s build card should have an art thumbnail." % id)
			continue

		if (
			not String(
				definition.get("world_sprite_atlas_path", "")
			).is_empty()
			and not (button.icon is AtlasTexture)
		):
			_fail(
				"%s build card should use its production atlas art."
				% id
			)

		if (
			button.texture_filter
			!= CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		):
			_fail(
				"%s build card should use smooth production-art filtering."
				% id
			)

	hud.queue_free()


func _alpha_used_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.03:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()

	return Rect2i(
		min_x,
		min_y,
		max_x - min_x + 1,
		max_y - min_y + 1
	)


func _fail(message: String) -> void:
	errors.append(message)
