class_name AirportAmbientLifeArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/ambient_life_v1/airport_ambient_atlas_v1.svg"
const CELL_SIZE := 256.0

const PASSENGER_ATLAS_PATH := "res://assets/production/passenger_v2/airport_passenger_atlas_v2.png"
const PASSENGER_CELL_SIZE := 256.0
const PASSENGER_ARCHETYPES := [
	"business",
	"backpacker",
	"family",
	"couple",
	"casual",
	"premium",
	"elderly",
	"vacation"
]
const PASSENGER_CELLS := {
	"business": Vector2i(0, 0),
	"backpacker": Vector2i(2, 0),
	"family": Vector2i(0, 1),
	"couple": Vector2i(2, 1),
	"casual": Vector2i(0, 2),
	"premium": Vector2i(2, 2),
	"elderly": Vector2i(0, 3),
	"vacation": Vector2i(2, 3)
}

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
	"crew": Vector2(54, 54),
	"marshaller": Vector2(60, 60),
	"civilian": Vector2(50, 50),
	"utility": Vector2(60, 60),
	"baggage": Vector2(86, 76),
	"windsock": Vector2(84, 84),
	"flag": Vector2(80, 80)
}

static var _atlas: Texture2D
static var _passenger_atlas: Texture2D


static func texture() -> Texture2D:
	if _atlas == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas = load(ATLAS_PATH) as Texture2D
	return _atlas


static func passenger_texture() -> Texture2D:
	if (
		_passenger_atlas == null
		and ResourceLoader.exists(PASSENGER_ATLAS_PATH)
	):
		_passenger_atlas = load(PASSENGER_ATLAS_PATH) as Texture2D
	return _passenger_atlas


static func passenger_archetype(variant: int) -> String:
	if PASSENGER_ARCHETYPES.is_empty():
		return "business"
	var index := variant % PASSENGER_ARCHETYPES.size()
	if index < 0:
		index += PASSENGER_ARCHETYPES.size()
	return PASSENGER_ARCHETYPES[index]


static func passenger_source_rect(
	archetype: String,
	frame: int
) -> Rect2:
	var normalized := (
		archetype
		if PASSENGER_CELLS.has(archetype)
		else "business"
	)
	var start: Vector2i = PASSENGER_CELLS.get(
		normalized,
		Vector2i.ZERO
	)
	var frame_index := frame % 2
	if frame_index < 0:
		frame_index += 2
	var cell := Vector2i(
		start.x + frame_index,
		start.y
	)
	return Rect2(
		Vector2(
			float(cell.x) * PASSENGER_CELL_SIZE,
			float(cell.y) * PASSENGER_CELL_SIZE
		),
		Vector2(
			PASSENGER_CELL_SIZE,
			PASSENGER_CELL_SIZE
		)
	)


static func passenger_world_size(
	archetype: String = ""
) -> Vector2:
	match archetype:
		"family", "couple":
			return Vector2(62, 62)
		"premium", "vacation":
			return Vector2(59, 59)
		_:
			return Vector2(56, 56)


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
		"passenger_atlas_path": PASSENGER_ATLAS_PATH,
		"passenger_cell_size": PASSENGER_CELL_SIZE,
		"passenger_variant_count": PASSENGER_ARCHETYPES.size(),
		"passenger_size": passenger_world_size(),
		"crew_size": world_size("crew"),
		"marshaller_size": world_size("marshaller"),
		"civilian_size": world_size("civilian"),
		"utility_size": world_size("utility"),
		"baggage_size": world_size("baggage"),
		"windsock_size": world_size("windsock"),
		"flag_size": world_size("flag")
	}
