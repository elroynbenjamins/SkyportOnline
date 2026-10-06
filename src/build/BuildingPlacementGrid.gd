class_name BuildingPlacementGrid
extends RefCounted

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0


static func tile_to_world(tile: Vector2) -> Vector2:
	return Vector2(
		(tile.x - tile.y) * TILE_WIDTH * 0.5,
		(tile.x + tile.y) * TILE_HEIGHT * 0.5
	)


static func world_to_tile(world_position: Vector2) -> Vector2i:
	var tile := world_to_tile_float(world_position)
	return Vector2i(floori(tile.x), floori(tile.y))


static func world_to_tile_float(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x / TILE_WIDTH
			+ world_position.y / TILE_HEIGHT,
		world_position.y / TILE_HEIGHT
			- world_position.x / TILE_WIDTH
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
		a + Vector2(0, -TILE_HEIGHT * 0.5),
		b + Vector2(TILE_WIDTH * 0.5, 0),
		c + Vector2(0, TILE_HEIGHT * 0.5),
		d + Vector2(-TILE_WIDTH * 0.5, 0)
	])
