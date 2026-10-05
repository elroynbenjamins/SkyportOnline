class_name GroundServiceVehicleArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/ground_service_v1/skyport_ground_service_atlas.webp"
const CELL_SIZE := 256.0

const ROW_BY_SERVICE := {
	"fuel": 0,
	"passenger": 1,
	"cargo": 2,
	"cleaning": 3,
	"catering": 4,
	"pushback": 5
}

const COLUMN_BY_DIRECTION := {
	"ne": 0,
	"se": 1,
	"sw": 2,
	"nw": 3
}

const WORLD_SIZE_BY_SERVICE := {
	"fuel": Vector2(58, 58),
	"passenger": Vector2(60, 60),
	"cargo": Vector2(56, 56),
	"cleaning": Vector2(54, 54),
	"catering": Vector2(58, 58),
	"pushback": Vector2(50, 50)
}

static var _atlas: Texture2D


static func texture() -> Texture2D:
	if _atlas == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas = load(ATLAS_PATH) as Texture2D
	return _atlas


static func direction_for(angle: float) -> String:
	var direction := Vector2.RIGHT.rotated(angle)
	if direction.x >= 0.0:
		return "se" if direction.y >= 0.0 else "ne"
	return "sw" if direction.y >= 0.0 else "nw"


static func source_rect(service_type: String, angle: float) -> Rect2:
	var row := int(ROW_BY_SERVICE.get(service_type, 0))
	var direction := direction_for(angle)
	var column := int(COLUMN_BY_DIRECTION.get(direction, 0))
	return Rect2(
		Vector2(
			float(column) * CELL_SIZE,
			float(row) * CELL_SIZE
		),
		Vector2(CELL_SIZE, CELL_SIZE)
	)


static func world_size(service_type: String) -> Vector2:
	return WORLD_SIZE_BY_SERVICE.get(
		service_type,
		Vector2(54, 54)
	)


static func shadow_radius(service_type: String) -> float:
	var size := world_size(service_type)
	return clampf(size.x * 0.31, 13.0, 19.0)
