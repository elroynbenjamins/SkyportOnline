class_name AircraftMotionArt
extends RefCounted


const ATLAS_PATH := "res://assets/production/aircraft_motion_v4/aircraft_motion_fx_v4.svg"
const CELL_SIZE := Vector2i(64, 64)
const COLUMNS := 4

const FRAME_INDEX := {
	"taxi_puff_a": 0,
	"taxi_puff_b": 1,
	"touchdown_a": 2,
	"touchdown_b": 3,
	"touchdown_c": 4,
	"takeoff_wake": 5,
	"stand_stop": 6,
	"pushback_roll": 7,
}

static var _atlas: Texture2D
static var _cache: Dictionary = {}


static func frame_count() -> int:
	return FRAME_INDEX.size()


static func texture(frame_name: String) -> Texture2D:
	if not FRAME_INDEX.has(frame_name):
		return null
	if _cache.has(frame_name):
		return _cache[frame_name] as Texture2D
	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		var loaded = load(ATLAS_PATH)
		if not (loaded is Texture2D):
			return null
		_atlas = loaded as Texture2D
	var index := int(FRAME_INDEX[frame_name])
	var result := AtlasTexture.new()
	result.atlas = _atlas
	result.region = Rect2(
		float(index % COLUMNS) * CELL_SIZE.x,
		float(int(index / COLUMNS)) * CELL_SIZE.y,
		CELL_SIZE.x,
		CELL_SIZE.y
	)
	_cache[frame_name] = result
	return result


static func taxi_texture(progress: float) -> Texture2D:
	return texture(
		"taxi_puff_a"
		if progress < 0.48
		else "taxi_puff_b"
	)


static func touchdown_texture(progress: float) -> Texture2D:
	if progress < 0.34:
		return texture("touchdown_a")
	if progress < 0.68:
		return texture("touchdown_b")
	return texture("touchdown_c")


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	if not ResourceLoader.exists(ATLAS_PATH):
		errors.append("Missing production aircraft motion FX atlas.")
	for frame_name in FRAME_INDEX.keys():
		if texture(String(frame_name)) == null:
			errors.append(
				"Missing aircraft motion FX frame: %s"
				% String(frame_name)
			)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}
