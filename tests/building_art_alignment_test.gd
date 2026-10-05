extends SceneTree

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const ALPHA_THRESHOLD := 0.03

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked := 0
	for definition in BuildingCatalog.all():
		var atlas_path := String(
			definition.get("world_sprite_atlas_path", "")
		)
		if atlas_path.is_empty():
			continue

		var texture_resource = load(atlas_path)
		if not (texture_resource is Texture2D):
			_fail("%s production atlas failed to load." % String(definition.get("id", "")))
			continue

		var atlas_image: Image = (texture_resource as Texture2D).get_image()
		if atlas_image == null or atlas_image.is_empty():
			_fail("%s production atlas has no readable image." % String(definition.get("id", "")))
			continue

		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty():
			_fail("%s production atlas has no sprite regions." % String(definition.get("id", "")))
			continue

		var draw_size: Vector2 = definition.get(
			"world_sprite_size",
			Vector2.ZERO
		)
		var fallback_offset: Vector2 = definition.get(
			"world_sprite_offset",
			Vector2.ZERO
		)
		var sprite_offsets: Array = definition.get(
			"world_sprite_offsets",
			[]
		)
		var base_footprint: Vector2i = definition.get(
			"footprint",
			Vector2i.ONE
		)

		for rotation in range(regions.size()):
			var source_rect: Rect2 = regions[rotation]
			var offset := fallback_offset
			if not sprite_offsets.is_empty():
				var offset_value = sprite_offsets[
					rotation % sprite_offsets.size()
				]
				if offset_value is Vector2:
					offset = offset_value
			var source_rect_i := Rect2i(
				int(source_rect.position.x),
				int(source_rect.position.y),
				int(source_rect.size.x),
				int(source_rect.size.y)
			)
			var sprite_image := atlas_image.get_region(source_rect_i)
			var used := _alpha_used_rect(sprite_image)
			if used.size.x <= 0 or used.size.y <= 0:
				_fail(
					"%s rotation %d has no visible pixels."
					% [String(definition.get("id", "")), rotation]
				)
				continue

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
				draw_size.x / float(source_rect_i.size.x),
				draw_size.y / float(source_rect_i.size.y)
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
			var bottom_delta := visible_bottom - footprint_bottom

			var visible_center_x := (
				-draw_size.x * 0.5
				+ offset.x
				+ (
					float(used.position.x)
					+ float(used.size.x) * 0.5
				) * scale.x
			)
			var visible_width := float(used.size.x) * scale.x
			var footprint_width := (
				float(footprint.x + footprint.y)
				* TILE_WIDTH
				* 0.5
			)
			var width_ratio := (
				visible_width / maxf(footprint_width, 1.0)
			)

			var diagnostic := (
				"BUILDING_ART_ALIGN id=%s rot=%d fp=%dx%d used=%s "
				+ "bottom_delta=%.2f center_x=%.2f width_ratio=%.2f"
			) % [
				String(definition.get("id", "")),
				rotation,
				footprint.x,
				footprint.y,
				str(used),
				bottom_delta,
				visible_center_x,
				width_ratio
			]
			print(diagnostic)

			if absf(bottom_delta) > 1.25:
				_fail(
					"%s rotation %d visible base is %.2f px off its tile footprint."
					% [
						String(definition.get("id", "")),
						rotation,
						bottom_delta
					]
				)
			if absf(visible_center_x) > 8.0:
				_fail(
					"%s rotation %d is horizontally miscentered by %.2f px."
					% [
						String(definition.get("id", "")),
						rotation,
						visible_center_x
					]
				)
			if width_ratio > 1.80:
				_fail(
					"%s rotation %d is too wide for its gameplay footprint (%.2fx)."
					% [
						String(definition.get("id", "")),
						rotation,
						width_ratio
					]
				)
			checked += 1


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
		_fail("Smaller front building should render before the deeper large building.")
	grid.queue_free()

	if checked < 16:
		_fail("Expected at least 16 production building views; checked %d." % checked)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print("BUILDING_ART_ALIGNMENT_DIAGNOSTIC_OK views=%d" % checked)
	quit(0)


func _alpha_used_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
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
