class_name AirsideGroundArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/airside_ground_v2/airside_ground_atlas_v2.webp"
const CELL_SIZE := Vector2i(64, 32)
const COLUMNS := 5

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

const FRAME_INDEX := {
	"taxi_straight_0": 0,
	"taxi_straight_90": 1,
	"taxi_corner_0": 2,
	"taxi_corner_90": 3,
	"taxi_corner_180": 4,
	"taxi_corner_270": 5,
	"taxi_t_0": 6,
	"taxi_t_90": 7,
	"taxi_t_180": 8,
	"taxi_t_270": 9,
	"taxi_cross": 10,
	"taxi_end_0": 11,
	"taxi_end_90": 12,
	"taxi_end_180": 13,
	"taxi_end_270": 14,
	"taxi_runway_connector_0": 15,
	"taxi_runway_connector_90": 16,
	"taxi_runway_connector_180": 17,
	"taxi_runway_connector_270": 18,
	"service_straight_0": 19,
	"service_straight_90": 20,
	"service_corner_0": 21,
	"service_corner_90": 22,
	"service_corner_180": 23,
	"service_corner_270": 24,
	"service_t_0": 25,
	"service_t_90": 26,
	"service_t_180": 27,
	"service_t_270": 28,
	"service_cross": 29,
	"service_end_0": 30,
	"service_end_90": 31,
	"service_end_180": 32,
	"service_end_270": 33,
	"hold_short_0": 34,
	"hold_short_90": 35,
	"hold_short_180": 36,
	"hold_short_270": 37,
	"stand_s": 38,
	"stand_m": 39,
	"pushback": 40,
	"guidance": 41,
	"cargo": 42,
	"runway_edge": 43,
	"safety_stripe": 44,
}

static var _atlas: Texture2D
static var _cache: Dictionary = {}


static func frame_count() -> int:
	return FRAME_INDEX.size()


static func texture_for_frame(frame_name: String) -> Texture2D:
	if not FRAME_INDEX.has(frame_name):
		return null
	if _cache.has(frame_name):
		return _cache[frame_name] as Texture2D
	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		var resource = load(ATLAS_PATH)
		if not (resource is Texture2D):
			return null
		_atlas = resource as Texture2D
	var index := int(FRAME_INDEX[frame_name])
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = Rect2(
		float(index % COLUMNS) * CELL_SIZE.x,
		float(int(index / COLUMNS)) * CELL_SIZE.y,
		CELL_SIZE.x,
		CELL_SIZE.y
	)
	_cache[frame_name] = texture
	return texture


static func taxi_texture(mask: int, runway_direction: Vector2i = Vector2i.ZERO) -> Texture2D:
	if runway_direction != Vector2i.ZERO:
		return texture_for_frame(
			"taxi_runway_connector_%d" % _direction_rotation(runway_direction)
		)
	return texture_for_frame(_shape_frame("taxi", mask))


static func service_texture(mask: int) -> Texture2D:
	return texture_for_frame(_shape_frame("service", mask))


static func hold_short_texture(runway_direction: Vector2i) -> Texture2D:
	return texture_for_frame(
		"hold_short_%d" % _direction_rotation(runway_direction)
	)


static func stand_texture(size_class: String) -> Texture2D:
	return texture_for_frame("stand_m" if size_class == "M" else "stand_s")


static func _shape_frame(prefix: String, mask: int) -> String:
	var count := _bit_count(mask)
	if count >= 4:
		return "%s_cross" % prefix
	if count == 3:
		var missing := 15 ^ mask
		return "%s_t_%d" % [prefix, _missing_rotation(missing)]
	if count == 2:
		if mask == (NORTH | SOUTH):
			return "%s_straight_90" % prefix
		if mask == (EAST | WEST):
			return "%s_straight_0" % prefix
		if mask == (EAST | SOUTH):
			return "%s_corner_0" % prefix
		if mask == (SOUTH | WEST):
			return "%s_corner_90" % prefix
		if mask == (WEST | NORTH):
			return "%s_corner_180" % prefix
		return "%s_corner_270" % prefix
	var direction := _first_direction(mask)
	return "%s_end_%d" % [prefix, _direction_rotation(direction)]


static func _first_direction(mask: int) -> Vector2i:
	if (mask & EAST) != 0:
		return Vector2i(1, 0)
	if (mask & SOUTH) != 0:
		return Vector2i(0, 1)
	if (mask & WEST) != 0:
		return Vector2i(-1, 0)
	if (mask & NORTH) != 0:
		return Vector2i(0, -1)
	return Vector2i(1, 0)


static func _direction_rotation(direction: Vector2i) -> int:
	if direction == Vector2i(1, 0):
		return 0
	if direction == Vector2i(0, 1):
		return 90
	if direction == Vector2i(-1, 0):
		return 180
	return 270


static func _missing_rotation(missing_bit: int) -> int:
	if missing_bit == NORTH:
		return 0
	if missing_bit == EAST:
		return 90
	if missing_bit == SOUTH:
		return 180
	return 270


static func _bit_count(mask: int) -> int:
	var count := 0
	for bit in [NORTH, EAST, SOUTH, WEST]:
		if (mask & bit) != 0:
			count += 1
	return count


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	if not ResourceLoader.exists(ATLAS_PATH):
		errors.append("Missing airside ground atlas.")
	for frame_name in FRAME_INDEX.keys():
		if texture_for_frame(String(frame_name)) == null:
			errors.append("Missing airside ground frame: %s" % frame_name)
	return {"valid": errors.is_empty(), "errors": errors}
