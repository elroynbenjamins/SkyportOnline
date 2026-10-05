extends SceneTree

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const ALPHA_THRESHOLD := 0.03
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
var checked_atlas := 0
var checked_paths := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for definition in BuildingCatalog.all():
		_validate_art_coverage(definition)
		var atlas_path := String(
			definition.get("world_sprite_atlas_path", "")
		)
		if not atlas_path.is_empty():
			_check_atlas_definition(definition)
			continue

		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if paths.is_empty():
			var single_path := String(
				definition.get("world_sprite_path", "")
			)
			if not single_path.is_empty():
				paths = PackedStringArray([single_path])

		for rotation in range(paths.size()):
			var sprite_path := String(paths[rotation])
			var texture_resource = load(sprite_path)
			if not (texture_resource is Texture2D):
				_fail(
					"%s rotation %d sprite failed to load: %s"
					% [
						String(definition.get("id", "")),
						rotation,
						sprite_path
					]
				)
				continue

			var sprite_image: Image = (
				texture_resource as Texture2D
			).get_image()
			if sprite_image == null or sprite_image.is_empty():
				_fail(
					"%s rotation %d sprite has no readable image."
					% [
						String(definition.get("id", "")),
						rotation
					]
				)
				continue

			var source_size := Vector2(
				sprite_image.get_width(),
				sprite_image.get_height()
			)
			var draw_size: Vector2 = definition.get(
				"world_sprite_size",
				source_size
			)
			var offset := _offset_for_rotation(
				definition,
				rotation
			)
			if _validate_view(
				definition,
				rotation,
				sprite_image,
				source_size,
				draw_size,
				offset,
				"path"
			):
				checked_paths += 1

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var large_behind := {
		"definition_id": "small_terminal",
		"origin": Vector2i(0, 0),
		"rotation": 0
	}
	var small_in_front := {
		"definition_id": "ground_ops_depot",
		"origin": Vector2i(2, 0),
		"rotation": 0
	}
	if grid._building_front_depth(large_behind) != 3:
		_fail("Terminal front-depth should include its full 3x2 footprint.")
	if grid._building_front_depth(small_in_front) != 2:
		_fail("1x1 building front-depth should end at its occupied tile.")
	if not grid._sort_buildings_by_depth(
		small_in_front,
		large_behind
	):
		_fail(
			"Smaller front building should render before the deeper large building."
		)

	# These starter integration checks were added with the production-art pass
	# but must be executed here to make the green CI signal meaningful.
	_check_starter_world_art(grid)
	await _check_starter_layout_reload(grid)
	_check_ground_service_art()
	await _check_build_drawer_art()

	grid.queue_free()

	var checked := checked_atlas + checked_paths
	if checked_atlas < 10:
		_fail(
			"Expected at least 10 retained atlas building views; checked %d."
			% checked_atlas
		)
	if checked_paths < 25:
		_fail(
			"Expected at least 25 standalone building views after starter-v3 art migration; checked %d."
			% checked_paths
		)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"BUILDING_ART_ALIGNMENT_DIAGNOSTIC_OK coverage=complete atlas=%d paths=%d total=%d"
		% [checked_atlas, checked_paths, checked]
	)
	quit(0)



func _validate_art_coverage(
	definition: Dictionary
) -> void:
	var id := String(definition.get("id", ""))
	if bool(definition.get("event_decoration", false)):
		return
	if id in ["taxiway", "service_road"]:
		return

	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	var paths: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	var single_path := String(
		definition.get("world_sprite_path", "")
	)
	if (
		atlas_path.is_empty()
		and paths.is_empty()
		and single_path.is_empty()
	):
		_fail(
			"%s has no dedicated world building art."
			% id
		)


func _check_atlas_definition(
	definition: Dictionary
) -> void:
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	var texture_resource = load(atlas_path)
	if not (texture_resource is Texture2D):
		_fail(
			"%s production atlas failed to load."
			% String(definition.get("id", ""))
		)
		return

	var atlas_image: Image = (
		texture_resource as Texture2D
	).get_image()
	if atlas_image == null or atlas_image.is_empty():
		_fail(
			"%s production atlas has no readable image."
			% String(definition.get("id", ""))
		)
		return

	var regions: Array = definition.get(
		"world_sprite_regions",
		[]
	)
	if regions.is_empty():
		_fail(
			"%s production atlas has no sprite regions."
			% String(definition.get("id", ""))
		)
		return

	var draw_size: Vector2 = definition.get(
		"world_sprite_size",
		Vector2.ZERO
	)
	for rotation in range(regions.size()):
		var source_rect: Rect2 = regions[rotation]
		var source_rect_i := Rect2i(
			int(source_rect.position.x),
			int(source_rect.position.y),
			int(source_rect.size.x),
			int(source_rect.size.y)
		)
		var sprite_image := atlas_image.get_region(
			source_rect_i
		)
		var offset := _offset_for_rotation(
			definition,
			rotation
		)
		if _validate_view(
			definition,
			rotation,
			sprite_image,
			Vector2(source_rect_i.size),
			draw_size,
			offset,
			"atlas"
		):
			checked_atlas += 1


func _validate_view(
	definition: Dictionary,
	rotation: int,
	sprite_image: Image,
	source_size: Vector2,
	draw_size: Vector2,
	offset: Vector2,
	source_kind: String
) -> bool:
	var used := _alpha_used_rect(sprite_image)
	if used.size.x <= 0 or used.size.y <= 0:
		_fail(
			"%s rotation %d has no visible pixels."
			% [
				String(definition.get("id", "")),
				rotation
			]
		)
		return false

	var base_footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	var footprint := base_footprint
	if (
		bool(definition.get("rotatable", false))
		and rotation % 2 == 1
	):
		footprint = Vector2i(
			base_footprint.y,
			base_footprint.x
		)

	var scale := Vector2(
		draw_size.x / maxf(source_size.x, 1.0),
		draw_size.y / maxf(source_size.y, 1.0)
	)
	var visible_bottom := (
		-draw_size.y * 0.5
		+ offset.y
		+ float(used.end.y) * scale.y
	)
	var footprint_bottom := (
		float(footprint.x + footprint.y)
		* TILE_HEIGHT
		* 0.25
	)
	var bottom_delta := (
		visible_bottom - footprint_bottom
	)

	var visible_center_x := (
		-draw_size.x * 0.5
		+ offset.x
		+ (
			float(used.position.x)
			+ float(used.size.x) * 0.5
		) * scale.x
	)
	var visible_width := (
		float(used.size.x) * scale.x
	)
	var footprint_width := (
		float(footprint.x + footprint.y)
		* TILE_WIDTH
		* 0.5
	)
	var width_ratio := (
		visible_width / maxf(
			footprint_width,
			1.0
		)
	)

	print(
		(
			"BUILDING_ART_ALIGN kind=%s id=%s rot=%d "
			+ "fp=%dx%d used=%s bottom_delta=%.2f "
			+ "center_x=%.2f width_ratio=%.2f"
		) % [
			source_kind,
			String(definition.get("id", "")),
			rotation,
			footprint.x,
			footprint.y,
			str(used),
			bottom_delta,
			visible_center_x,
			width_ratio
		]
	)

	if absf(bottom_delta) > 1.25:
		_fail(
			(
				"%s rotation %d visible base is "
				+ "%.2f px off its tile footprint."
			) % [
				String(definition.get("id", "")),
				rotation,
				bottom_delta
			]
		)
	if absf(visible_center_x) > 8.0:
		_fail(
			(
				"%s rotation %d is horizontally "
				+ "miscentered by %.2f px."
			) % [
				String(definition.get("id", "")),
				rotation,
				visible_center_x
			]
		)
	if width_ratio > 1.80:
		_fail(
			(
				"%s rotation %d is too wide for "
				+ "its gameplay footprint (%.2fx)."
			) % [
				String(definition.get("id", "")),
				rotation,
				width_ratio
			]
		)
	return true


func _offset_for_rotation(
	definition: Dictionary,
	rotation: int
) -> Vector2:
	var offsets: Array = definition.get(
		"world_sprite_offsets",
		[]
	)
	if not offsets.is_empty():
		var value = offsets[
			rotation % offsets.size()
		]
		if value is Vector2:
			return value
	return definition.get(
		"world_sprite_offset",
		Vector2.ZERO
	)


func _alpha_used_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if (
				image.get_pixel(x, y).a
				<= ALPHA_THRESHOLD
			):
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




func _check_starter_world_art(grid: AirportGrid) -> void:
	for building_id in STARTER_VISUAL_IDS:
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s starter visual definition is missing." % building_id)
			continue
		if not grid._definition_has_world_sprite(definition):
			_fail("%s starter building should have world art." % building_id)
			continue

		var rotations := 2 if bool(
			definition.get("rotatable", false)
		) else 1
		for rotation in range(rotations):
			var path := grid._sprite_path_for_rotation(
				definition,
				rotation
			)
			if path.is_empty() or not ResourceLoader.exists(path):
				_fail(
					"%s rotation %d world texture is missing."
					% [building_id, rotation]
				)
				continue
			var texture_resource = load(path)
			if not (texture_resource is Texture2D):
				_fail(
					"%s rotation %d world texture failed to load."
					% [building_id, rotation]
				)
				continue

			var offset := grid._sprite_offset_for_rotation(
				definition,
				rotation
			)
			var draw_size: Vector2 = definition.get(
				"world_sprite_size",
				Vector2.ZERO
			)
			if draw_size.x <= 0.0 or draw_size.y <= 0.0:
				_fail("%s has invalid world draw size." % building_id)
			if not (offset is Vector2):
				_fail(
					"%s rotation %d has invalid world offset."
					% [building_id, rotation]
				)

			var atlas_path := String(
				definition.get("world_sprite_atlas_path", "")
			)
			if atlas_path.is_empty():
				continue
			var region := grid._sprite_region_for_rotation(
				definition,
				rotation
			)
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
					"%s rotation %d production region exceeds atlas bounds."
					% [building_id, rotation]
				)


func _check_starter_layout_reload(grid: AirportGrid) -> void:
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
			"Starter layout should contain %d objects, got %d."
			% [expected_total, layout.size()]
		)

	var airside := grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Starter airport should keep one runway.")
	if int(airside.get("stands_total", 0)) != 2:
		_fail("Starter airport should keep two stands.")
	if int(airside.get("stands_connected", 0)) != 2:
		_fail("Both starter stands should remain runway-connected.")

	var routes := grid.get_departure_routes("S")
	if routes.size() != 2:
		_fail("Starter airport should keep two S-class departure routes.")

	var fuel := grid.get_best_service_building("fuel", "S")
	if String(fuel.get("definition_id", "")) != "basic_fuel":
		_fail("Starter fuel assignment should still resolve to basic_fuel.")

	var restored := AirportGrid.new()
	root.add_child(restored)
	await process_frame
	if not restored.apply_saved_airport_layout(
		grid.export_airport_layout(),
		grid.export_owned_parcels(),
		grid.export_airport_storage()
	):
		_fail("Starter airport should reload after visual changes.")
	else:
		if (
			restored.export_airport_layout().size()
			!= layout.size()
		):
			_fail("Starter save reload changed placed-building count.")
		var restored_airside := restored.get_airside_status()
		if int(restored_airside.get("stands_connected", 0)) != 2:
			_fail("Starter save reload should keep both stands connected.")
	restored.queue_free()


func _check_ground_service_art() -> void:
	var atlas := GroundServiceVehicleArt.texture()
	if atlas == null:
		_fail("Ground-service production atlas failed to load.")
		return
	if atlas.get_width() != 1024 or atlas.get_height() != 1536:
		_fail(
			"Ground-service atlas should be 1024x1536, got %dx%d."
			% [atlas.get_width(), atlas.get_height()]
		)
		return

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
					"%s heading should map to %s."
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
					"%s %s source region exceeds service atlas."
					% [service_type, direction]
				)
				continue
			if not _region_has_visible_pixel(image, source_i):
				_fail(
					"%s %s service cell has no visible art."
					% [service_type, direction]
				)


func _check_build_drawer_art() -> void:
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
			_fail("%s should appear in starter build drawer." % id)
			continue
		var button: Button = hud.catalog_buttons[id]
		if button.icon == null:
			_fail("%s build card should have a thumbnail." % id)
			continue
		if (
			not String(
				definition.get("world_sprite_atlas_path", "")
			).is_empty()
			and not (button.icon is AtlasTexture)
		):
			_fail(
				"%s build card should use production atlas art."
				% id
			)
		if (
			button.texture_filter
			!= CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		):
			_fail(
				"%s build card should use smooth art filtering."
				% id
			)

	hud.queue_free()


func _region_has_visible_pixel(
	image: Image,
	region: Rect2i
) -> bool:
	# Coarse sampling is enough to catch missing/empty atlas cells and
	# keeps this regression fast alongside the pixel-accurate building check.
	for y in range(region.position.y, region.end.y, 8):
		for x in range(region.position.x, region.end.x, 8):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				return true
	return false


func _fail(message: String) -> void:
	errors.append(message)
