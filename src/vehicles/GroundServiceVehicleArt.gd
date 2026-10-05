class_name GroundServiceVehicleArt
extends RefCounted

const ATLAS_PATH := "res://assets/production/ground_service_v1/skyport_ground_service_atlas.webp"
const CELL_SIZE := 256.0
const ISO_HEADING_ANGLE := 0.463647609
const MAX_TURN_LEAN := 0.10

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
	"fuel": Vector2(54, 54),
	"passenger": Vector2(58, 58),
	"cargo": Vector2(46, 46),
	"cleaning": Vector2(50, 50),
	"catering": Vector2(54, 54),
	"pushback": Vector2(44, 44)
}

const MOTION_BOB_BY_SERVICE := {
	"fuel": 0.45,
	"passenger": 0.38,
	"cargo": 0.70,
	"cleaning": 0.52,
	"catering": 0.45,
	"pushback": 0.62
}

const SHADOW_ASPECT_BY_SERVICE := {
	"fuel": 0.36,
	"passenger": 0.34,
	"cargo": 0.42,
	"cleaning": 0.38,
	"catering": 0.36,
	"pushback": 0.44
}

const APPROACH_DISTANCE_BY_SERVICE := {
	"fuel": 30.0,
	"passenger": 31.0,
	"cargo": 24.0,
	"cleaning": 23.0,
	"catering": 29.0,
	"pushback": 27.0
}

const ATTACHMENT_REACH_BY_SERVICE := {
	"fuel": 48.0,
	"passenger": 46.0,
	"cargo": 40.0,
	"cleaning": 36.0,
	"catering": 44.0,
	"pushback": 48.0
}

const SERVICE_ALIGN_RATE_BY_SERVICE := {
	"fuel": 9.0,
	"passenger": 8.0,
	"cargo": 9.0,
	"cleaning": 10.0,
	"catering": 8.0,
	"pushback": 14.0
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


static func authored_heading(direction: String) -> float:
	match direction:
		"ne":
			return -ISO_HEADING_ANGLE
		"se":
			return ISO_HEADING_ANGLE
		"sw":
			return PI - ISO_HEADING_ANGLE
		"nw":
			return -PI + ISO_HEADING_ANGLE
		_:
			return 0.0


static func turn_lean(angle: float) -> float:
	var direction := direction_for(angle)
	var canonical := authored_heading(direction)
	var difference := wrapf(
		angle - canonical,
		-PI,
		PI
	)
	return clampf(
		difference,
		-MAX_TURN_LEAN,
		MAX_TURN_LEAN
	)


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


static func motion_bob_amplitude(
	service_type: String
) -> float:
	return float(
		MOTION_BOB_BY_SERVICE.get(
			service_type,
			0.5
		)
	)


static func shadow_aspect(
	service_type: String
) -> float:
	return clampf(
		float(
			SHADOW_ASPECT_BY_SERVICE.get(
				service_type,
				0.40
			)
		),
		0.28,
		0.50
	)


static func approach_distance(
	service_type: String
) -> float:
	return float(
		APPROACH_DISTANCE_BY_SERVICE.get(
			service_type,
			24.0
		)
	)


static func attachment_reach(
	service_type: String
) -> float:
	return float(
		ATTACHMENT_REACH_BY_SERVICE.get(
			service_type,
			40.0
		)
	)


static func service_align_rate(
	service_type: String
) -> float:
	return float(
		SERVICE_ALIGN_RATE_BY_SERVICE.get(
			service_type,
			9.0
		)
	)


static func visual_profile(
	service_type: String
) -> Dictionary:
	return {
		"world_size": world_size(service_type),
		"shadow_radius": shadow_radius(service_type),
		"shadow_aspect": shadow_aspect(service_type),
		"motion_bob": motion_bob_amplitude(service_type),
		"approach_distance": approach_distance(service_type),
		"attachment_reach": attachment_reach(service_type),
		"service_align_rate": service_align_rate(service_type)
	}
