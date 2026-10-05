class_name AirportAmbientLifeArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/ambient_life_v1/airport_ambient_atlas_v1.svg"
const CELL_SIZE := 256.0

const CELLS := {
	"crew_a": Vector2i(0, 0),
	"crew_b": Vector2i(1, 0),
	"marshaller_a": Vector2i(2, 0),
	"marshaller_b": Vector2i(3, 0),
	"civilian_a": Vector2i(0, 1),
	"civilian_b": Vector2i(1, 1),
	"utility_right": Vector2i(2, 1),
	"utility_left": Vector2i(3, 1),
	"baggage_right": Vector2i(0, 2),
	"baggage_left": Vector2i(1, 2),
	"windsock_a": Vector2i(2, 2),
	"windsock_b": Vector2i(3, 2),
	"flag_a": Vector2i(0, 3),
	"flag_b": Vector2i(1, 3)
}

const WORLD_SIZES := {
	"crew": Vector2(42, 42),
	"marshaller": Vector2(48, 48),
	"civilian": Vector2(39, 39),
	"utility": Vector2(58, 58),
	"baggage": Vector2(78, 68),
	"windsock": Vector2(70, 70),
	"flag": Vector2(66, 66)
}

static var _atlas: Texture2D


static func texture() -> Texture2D:
	if _atlas == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas = load(ATLAS_PATH) as Texture2D
	return _atlas


static func source_rect(key: String) -> Rect2:
	var cell: Vector2i = CELLS.get(
		key,
		Vector2i.ZERO
	)
	return Rect2(
		Vector2(
			float(cell.x) * CELL_SIZE,
			float(cell.y) * CELL_SIZE
		),
		Vector2(CELL_SIZE, CELL_SIZE)
	)


static func world_size(kind: String) -> Vector2:
	return WORLD_SIZES.get(
		kind,
		Vector2(48, 48)
	)


static func animation_frame(
	clock: float,
	speed: float,
	phase: float = 0.0
) -> int:
	return int(floor(
		(clock * maxf(speed, 0.01)) + phase
	)) % 2


static func crew_key(
	marshaller: bool,
	frame: int
) -> String:
	if marshaller:
		return "marshaller_b" if frame % 2 == 1 else "marshaller_a"
	return "crew_b" if frame % 2 == 1 else "crew_a"


static func civilian_key(variant: int) -> String:
	return "civilian_b" if variant % 2 == 1 else "civilian_a"


static func utility_key(heading: float) -> String:
	return "utility_left" if cos(heading) < 0.0 else "utility_right"


static func baggage_key(heading: float) -> String:
	return "baggage_left" if cos(heading) < 0.0 else "baggage_right"


static func windsock_key(frame: int) -> String:
	return "windsock_b" if frame % 2 == 1 else "windsock_a"


static func flag_key(frame: int) -> String:
	return "flag_b" if frame % 2 == 1 else "flag_a"


static func visual_profile() -> Dictionary:
	return {
		"atlas_path": ATLAS_PATH,
		"cell_size": CELL_SIZE,
		"crew_size": world_size("crew"),
		"marshaller_size": world_size("marshaller"),
		"civilian_size": world_size("civilian"),
		"utility_size": world_size("utility"),
		"baggage_size": world_size("baggage"),
		"windsock_size": world_size("windsock"),
		"flag_size": world_size("flag")
	}
