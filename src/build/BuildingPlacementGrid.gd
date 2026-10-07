class_name BuildingPlacementGrid
extends RefCounted

# Gameplay cells are always true squares. The projected dimensions only
# describe how those squares are drawn in the fixed Skyrama-style view.
const LOGICAL_TILE_SIZE := 64.0
const TILE_WIDTH := LOGICAL_TILE_SIZE
const TILE_HEIGHT := LOGICAL_TILE_SIZE
const PROJECTED_TILE_WIDTH := 64.0
const PROJECTED_TILE_HEIGHT := 32.0


static func tile_to_world(tile: Vector2) -> Vector2:
	return Vector2(
		(tile.x - tile.y) * PROJECTED_TILE_WIDTH * 0.5,
		(tile.x + tile.y) * PROJECTED_TILE_HEIGHT * 0.5
	)


static func world_to_tile(world_position: Vector2) -> Vector2i:
	var tile := world_to_tile_float(world_position)
	return Vector2i(roundi(tile.x), roundi(tile.y))


static func world_to_tile_float(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x / PROJECTED_TILE_WIDTH
			+ world_position.y / PROJECTED_TILE_HEIGHT,
		world_position.y / PROJECTED_TILE_HEIGHT
			- world_position.x / PROJECTED_TILE_WIDTH
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

	var a := tile_to_world(Vector2(origin.x, origin.y))
	var b := tile_to_world(
		Vector2(origin.x + footprint.x - 1, origin.y)
	)
	var c := tile_to_world(
		Vector2(
			origin.x + footprint.x - 1,
			origin.y + footprint.y - 1
		)
	)
	var d := tile_to_world(
		Vector2(origin.x, origin.y + footprint.y - 1)
	)

	return PackedVector2Array([
		a + Vector2(0, -PROJECTED_TILE_HEIGHT * 0.5),
		b + Vector2(PROJECTED_TILE_WIDTH * 0.5, 0),
		c + Vector2(0, PROJECTED_TILE_HEIGHT * 0.5),
		d + Vector2(-PROJECTED_TILE_WIDTH * 0.5, 0)
	])


static func tile_polygon(tile: Vector2i) -> PackedVector2Array:
	var center := tile_to_world(Vector2(tile.x, tile.y))
	return PackedVector2Array([
		center + Vector2(0, -PROJECTED_TILE_HEIGHT * 0.5),
		center + Vector2(PROJECTED_TILE_WIDTH * 0.5, 0),
		center + Vector2(0, PROJECTED_TILE_HEIGHT * 0.5),
		center + Vector2(-PROJECTED_TILE_WIDTH * 0.5, 0)
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
	var polygon := footprint_polygon(origin, footprint)
	if polygon.size() < 4:
		return Vector2.ZERO
	return polygon[2]


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

	var contract := visual_contract(footprint)
	var anchor := footprint_front_anchor_world(
		origin,
		footprint
	)
	var base_anchor_local: Vector2 = contract.get(
		"anchor_local",
		Vector2.ZERO
	)
	var size := Vector2(
		float(asset_size_px.x),
		float(asset_size_px.y)
	)

	# The projected front corner is not the horizontal center of an
	# asymmetric W×H footprint. Using bottom-center shifts 5×2 art by 48 px.
	# Preserve the contract's exact X anchor; extra asset height is top-only.
	var asset_anchor_local := Vector2(
		base_anchor_local.x,
		size.y
	)
	return Rect2(
		anchor - asset_anchor_local,
		size
	)


static func visual_contract(
	footprint: Vector2i
) -> Dictionary:
	if footprint.x <= 0 or footprint.y <= 0:
		return {"valid": false}

	var polygon := footprint_polygon(
		Vector2i.ZERO,
		footprint
	)
	var bounds := footprint_bounds(
		Vector2i.ZERO,
		footprint
	)
	var base_width := bounds.size.x
	var base_depth := bounds.size.y
	var anchor_world := polygon[2]
	var base_polygon_from_anchor := PackedVector2Array()
	for point in polygon:
		base_polygon_from_anchor.append(
			point - anchor_world
		)
	var anchor_local := Vector2(
		anchor_world.x - bounds.position.x,
		anchor_world.y - bounds.position.y
	)
	return {
		"valid": true,
		"contract_version": "square_grid_iso_v1",
		"projection": "skyrama_isometric_2_to_1",
		"logical_tile_size": Vector2(
			LOGICAL_TILE_SIZE,
			LOGICAL_TILE_SIZE
		),
		"tile_width": TILE_WIDTH,
		"tile_height": TILE_HEIGHT,
		"projected_tile_width": PROJECTED_TILE_WIDTH,
		"projected_tile_height": PROJECTED_TILE_HEIGHT,
		"footprint": footprint,
		"base_bounds": bounds,
		"base_size": bounds.size,
		"authoring_width_px": roundi(base_width),
		"base_depth_px": roundi(base_depth),
		"anchor_rule": "projected_front_corner",
		"anchor_local": anchor_local,
		"base_polygon_from_anchor": base_polygon_from_anchor,
		"asset_pixels_per_world_pixel": 1.0,
		"runtime_scale": Vector2.ONE,
		"draw_rect_rule": "asset_contract_anchor_to_projected_front_corner",
		"horizontal_extent_rule": "inside_projected_footprint_width",
		"vertical_extent_rule": "body_may_extend_up_only",
		"transparent_padding_rule": "top_only",
		"max_horizontal_overhang_px": 0.0,
		"grid_owns_footprint": true,
		"grid_owns_anchor": true,
		"grid_owns_scale": true
	}
