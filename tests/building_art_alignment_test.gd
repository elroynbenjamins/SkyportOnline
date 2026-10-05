extends SceneTree

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const ALPHA_THRESHOLD := 0.03

var errors: Array[String] = []
var checked_atlas := 0
var checked_paths := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for definition in BuildingCatalog.all():
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
	grid.queue_free()

	var checked := checked_atlas + checked_paths
	if checked_atlas < 16:
		_fail(
			"Expected at least 16 atlas building views; checked %d."
			% checked_atlas
		)
	if checked_paths < 20:
		_fail(
			"Expected at least 20 standalone building views; checked %d."
			% checked_paths
		)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"BUILDING_ART_ALIGNMENT_DIAGNOSTIC_OK atlas=%d paths=%d total=%d"
		% [checked_atlas, checked_paths, checked]
	)
	quit(0)


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


func _fail(message: String) -> void:
	errors.append(message)
