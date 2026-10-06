class_name ApronDetailArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/apron_detail_v2/apron_detail_atlas_v2.svg"
const CELL_SIZE := 256.0
const ATLAS_SIZE := Vector2i(1024, 1280)

const CELLS := {
	"crew_a": Vector2i(0, 0),
	"crew_b": Vector2i(1, 0),
	"marshaller_a": Vector2i(2, 0),
	"marshaller_b": Vector2i(3, 0),
	"stairs_right": Vector2i(0, 1),
	"stairs_left": Vector2i(1, 1),
	"belt_right": Vector2i(2, 1),
	"belt_left": Vector2i(3, 1),
	"gpu_right": Vector2i(0, 2),
	"gpu_left": Vector2i(1, 2),
	"cargo_loader_right": Vector2i(2, 2),
	"cargo_loader_left": Vector2i(3, 2),
	"baggage_right": Vector2i(0, 3),
	"baggage_left": Vector2i(1, 3),
	"utility_right": Vector2i(2, 3),
	"utility_left": Vector2i(3, 3),
	"cargo_pallet": Vector2i(0, 4),
	"uld": Vector2i(1, 4),
	"cones": Vector2i(2, 4),
	"chocks": Vector2i(3, 4)
}

const WORLD_SIZES := {
	"crew": Vector2(56, 56),
	"marshaller": Vector2(60, 60),
	"stairs": Vector2(78, 78),
	"belt": Vector2(70, 70),
	"gpu": Vector2(58, 58),
	"cargo_loader": Vector2(80, 80),
	"baggage": Vector2(78, 78),
	"utility": Vector2(62, 62),
	"cargo_pallet": Vector2(54, 54),
	"uld": Vector2(54, 54),
	"cones": Vector2(38, 38),
	"chocks": Vector2(36, 36)
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
		Vector2(56, 56)
	)


static func animation_frame(
	clock: float,
	speed: float,
	phase: float = 0.0
) -> int:
	return int(
		floor(
			clock * speed
			+ phase
		)
	) % 2


static func crew_key(
	marshaller: bool,
	frame: int
) -> String:
	var normalized := frame % 2
	if normalized < 0:
		normalized += 2
	if marshaller:
		return (
			"marshaller_a"
			if normalized == 0
			else "marshaller_b"
		)
	return (
		"crew_a"
		if normalized == 0
		else "crew_b"
	)


static func direction_side(
	heading: float
) -> String:
	return (
		"right"
		if cos(heading) >= 0.0
		else "left"
	)


static func directional_key(
	kind: String,
	heading: float
) -> String:
	var side := direction_side(heading)
	match kind:
		"stairs":
			return "stairs_%s" % side
		"belt":
			return "belt_%s" % side
		"gpu":
			return "gpu_%s" % side
		"cargo_loader":
			return "cargo_loader_%s" % side
		"baggage":
			return "baggage_%s" % side
		"utility":
			return "utility_%s" % side
		_:
			return kind


static func visual_profile() -> Dictionary:
	return {
		"atlas_path": ATLAS_PATH,
		"atlas_size": ATLAS_SIZE,
		"cell_size": CELL_SIZE,
		"cell_count": CELLS.size(),
		"crew_size": world_size("crew"),
		"marshaller_size": world_size("marshaller"),
		"stairs_size": world_size("stairs"),
		"belt_size": world_size("belt"),
		"gpu_size": world_size("gpu"),
		"cargo_loader_size": world_size("cargo_loader"),
		"baggage_size": world_size("baggage"),
		"utility_size": world_size("utility")
	}
