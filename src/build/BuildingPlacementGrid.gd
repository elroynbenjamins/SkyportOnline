class_name BuildingPlacementGrid
extends RefCounted

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 64.0


static func tile_to_world(tile: Vector2) -> Vector2:
	return Vector2(
		tile.x * TILE_WIDTH,
		tile.y * TILE_HEIGHT
	)


static func world_to_tile(world_position: Vector2) -> Vector2i:
	var tile := world_to_tile_float(world_position)
	return Vector2i(roundi(tile.x), roundi(tile.y))


static func world_to_tile_float(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x / TILE_WIDTH,
		world_position.y / TILE_HEIGHT
	)


static func footprint_for(
	definition: Dictionary,
	rotation: int
) -> Vector2i:
	var base: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and rotation % 2 == 1
	):
		return Vector2i(base.y, base.x)
	return base


static func cells_for(
	origin: Vector2i,
	footprint: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			cells.append(origin + Vector2i(x, y))
	return cells


static func cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


static func footprint_center_world(
	origin: Vector2i,
	footprint: Vector2i
) -> Vector2:
	var center_tile := Vector2(
		float(origin.x) + float(footprint.x - 1) * 0.5,
		float(origin.y) + float(footprint.y - 1) * 0.5
	)
	return tile_to_world(center_tile)


static func footprint_polygon(
	origin: Vector2i,
	footprint: Vector2i
) -> PackedVector2Array:
	if footprint.x <= 0 or footprint.y <= 0:
		return PackedVector2Array()

	var first_center := tile_to_world(
		Vector2(origin.x, origin.y)
	)
	var last_center := tile_to_world(
		Vector2(
			origin.x + footprint.x - 1,
			origin.y + footprint.y - 1
		)
	)
	var left := first_center.x - TILE_WIDTH * 0.5
	var top := first_center.y - TILE_HEIGHT * 0.5
	var right := last_center.x + TILE_WIDTH * 0.5
	var bottom := last_center.y + TILE_HEIGHT * 0.5

	return PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	])


static func tile_polygon(tile: Vector2i) -> PackedVector2Array:
	var center := tile_to_world(Vector2(tile.x, tile.y))
	var half := Vector2(
		TILE_WIDTH * 0.5,
		TILE_HEIGHT * 0.5
	)
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y)
	])


static func footprint_bounds(
	origin: Vector2i,
	footprint: Vector2i
) -> Rect2:
	var polygon := footprint_polygon(origin, footprint)
	if polygon.is_empty():
		return Rect2()

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point_variant in polygon:
		var point: Vector2 = point_variant
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)

	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)


static func footprint_front_anchor_world(
	origin: Vector2i,
	footprint: Vector2i
) -> Vector2:
	var bounds := footprint_bounds(origin, footprint)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y
	)


static func validate_asset_dimensions(
	asset_size_px: Vector2i,
	footprint: Vector2i
) -> Dictionary:
	var contract := visual_contract(footprint)
	if not bool(contract.get("valid", false)):
		return {
			"valid": false,
			"reason": "Invalid footprint."
		}

	var expected_width := int(
		contract.get("authoring_width_px", 0)
	)
	var minimum_height := int(
		contract.get("base_depth_px", 0)
	)
	if asset_size_px.x != expected_width:
		return {
			"valid": false,
			"reason": (
				"Asset width must be exactly %d px for footprint %dx%d."
				% [
					expected_width,
					footprint.x,
					footprint.y
				]
			),
			"expected_width_px": expected_width,
			"minimum_height_px": minimum_height
		}
	if asset_size_px.y < minimum_height:
		return {
			"valid": false,
			"reason": (
				"Asset height must be at least %d px so the full grid base fits."
				% minimum_height
			),
			"expected_width_px": expected_width,
			"minimum_height_px": minimum_height
		}
	return {
		"valid": true,
		"reason": "",
		"expected_width_px": expected_width,
		"minimum_height_px": minimum_height
	}


static func asset_draw_rect(
	origin: Vector2i,
	footprint: Vector2i,
	asset_size_px: Vector2i
) -> Rect2:
	var validation := validate_asset_dimensions(
		asset_size_px,
		footprint
	)
	if not bool(validation.get("valid", false)):
		return Rect2()

	var anchor := footprint_front_anchor_world(
		origin,
		footprint
	)
	var size := Vector2(
		float(asset_size_px.x),
		float(asset_size_px.y)
	)
	return Rect2(
		anchor - Vector2(size.x * 0.5, size.y),
		size
	)


static func visual_contract(
	footprint: Vector2i
) -> Dictionary:
	if footprint.x <= 0 or footprint.y <= 0:
		return {"valid": false}

	var bounds := footprint_bounds(
		Vector2i.ZERO,
		footprint
	)
	var base_width := bounds.size.x
	var base_depth := bounds.size.y
	var anchor_local := Vector2(
		base_width * 0.5,
		base_depth
	)
	var base_polygon_from_anchor := PackedVector2Array([
		Vector2(-base_width * 0.5, -base_depth),
		Vector2(base_width * 0.5, -base_depth),
		Vector2(base_width * 0.5, 0),
		Vector2(-base_width * 0.5, 0)
	])
	return {
		"valid": true,
		"contract_version": "square_grid_v1",
		"projection": "square_cartesian",
		"tile_width": TILE_WIDTH,
		"tile_height": TILE_HEIGHT,
		"footprint": footprint,
		"base_bounds": bounds,
		"base_size": bounds.size,
		"authoring_width_px": roundi(base_width),
		"base_depth_px": roundi(base_depth),
		"anchor_rule": "front_center",
		"anchor_local": anchor_local,
		"base_polygon_from_anchor": base_polygon_from_anchor,
		"asset_pixels_per_world_pixel": 1.0,
		"runtime_scale": Vector2.ONE,
		"draw_rect_rule": "asset_bottom_center_to_front_anchor",
		"horizontal_extent_rule": "inside_footprint_width",
		"vertical_extent_rule": "body_may_extend_up_only",
		"transparent_padding_rule": "top_only",
		"max_horizontal_overhang_px": 0.0,
		"grid_owns_footprint": true,
		"grid_owns_anchor": true,
		"grid_owns_scale": true
	}
