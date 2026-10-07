class_name BuildingSpritePlacement
extends RefCounted

const ALPHA_THRESHOLD := 0.03
const MIN_VISIBLE_WIDTH_SCALE := 0.25
const MAX_VISIBLE_WIDTH_SCALE := 1.0


static func visible_bounds(
	image: Image,
	source_region: Rect2 = Rect2()
) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()

	var source := Rect2i(
		0,
		0,
		image.get_width(),
		image.get_height()
	)
	if source_region.size.x > 0.0 and source_region.size.y > 0.0:
		source = Rect2i(
			int(source_region.position.x),
			int(source_region.position.y),
			int(source_region.size.x),
			int(source_region.size.y)
		)

	var min_x := source.size.x
	var min_y := source.size.y
	var max_x := -1
	var max_y := -1

	for local_y in range(source.size.y):
		for local_x in range(source.size.x):
			var pixel := Vector2i(
				source.position.x + local_x,
				source.position.y + local_y
			)
			if (
				pixel.x < 0
				or pixel.y < 0
				or pixel.x >= image.get_width()
				or pixel.y >= image.get_height()
			):
				continue
			if image.get_pixelv(pixel).a <= ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, local_x)
			min_y = mini(min_y, local_y)
			max_x = maxi(max_x, local_x)
			max_y = maxi(max_y, local_y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()

	return Rect2i(
		min_x,
		min_y,
		max_x - min_x + 1,
		max_y - min_y + 1
	)


static func grounded_rect(
	visible_bounds_local: Rect2i,
	source_size: Vector2,
	footprint_polygon: PackedVector2Array,
	footprint_center: Vector2,
	visible_width_scale: float = 1.0,
	extra_offset: Vector2 = Vector2.ZERO
) -> Rect2:
	if (
		visible_bounds_local.size.x <= 0
		or visible_bounds_local.size.y <= 0
		or source_size.x <= 0.0
		or source_size.y <= 0.0
		or footprint_polygon.size() < 4
	):
		return Rect2(
			footprint_center + extra_offset,
			Vector2.ONE
		)

	var min_x := INF
	var max_x := -INF
	var front_y := -INF
	for point_variant in footprint_polygon:
		var point: Vector2 = point_variant
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		front_y = maxf(front_y, point.y)

	var footprint_width := maxf(max_x - min_x, 1.0)
	# A placeable object's visible art may be narrower than its logical
	# footprint, but never wider. This makes the grid authoritative even when
	# atlas files contain oversized bases, shadows or hand-tuned legacy sizes.
	var strict_width_scale := clampf(
		visible_width_scale,
		MIN_VISIBLE_WIDTH_SCALE,
		MAX_VISIBLE_WIDTH_SCALE
	)
	var target_visible_width := (
		footprint_width
		* strict_width_scale
	)
	var pixel_scale := (
		target_visible_width
		/ float(visible_bounds_local.size.x)
	)
	var draw_size := source_size * pixel_scale
	var visible_center_x := (
		float(visible_bounds_local.position.x)
		+ float(visible_bounds_local.size.x) * 0.5
	)
	var visible_bottom_y := float(
		visible_bounds_local.end.y
	)

	return Rect2(
		Vector2(
			footprint_center.x
				- visible_center_x * pixel_scale,
			front_y
				- visible_bottom_y * pixel_scale
		) + extra_offset,
		draw_size
	)
