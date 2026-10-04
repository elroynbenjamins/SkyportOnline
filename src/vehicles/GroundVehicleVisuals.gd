class_name GroundVehicleVisuals
extends RefCounted

const ATLAS_CELL_SIZE := 64.0
const ATLAS_DIRECTIONS := 4


static func atlas_path(service_type: String) -> String:
	if service_type not in [
		"fuel",
		"passenger",
		"cargo",
		"cleaning",
		"catering",
		"pushback"
	]:
		return ""
	return (
		"res://assets/pixel/vehicles/ground_service/%s_atlas.png"
		% service_type
	)


static func direction_index(rotation_radians: float) -> int:
	var heading := Vector2.RIGHT.rotated(rotation_radians)

	if heading.x >= 0.0:
		if heading.y < 0.0:
			return 0 # NE
		return 1 # SE

	if heading.y >= 0.0:
		return 2 # SW
	return 3 # NW


static func display_size(service_type: String) -> Vector2:
	match service_type:
		"passenger":
			return Vector2(52, 52)
		"cargo":
			return Vector2(50, 50)
		"fuel":
			return Vector2(48, 48)
		"catering":
			return Vector2(48, 48)
		"cleaning":
			return Vector2(45, 45)
		"pushback":
			return Vector2(44, 44)
		_:
			return Vector2(46, 46)


static func source_region(
	service_type: String,
	rotation_radians: float
) -> Rect2:
	var index := direction_index(rotation_radians)
	return Rect2(
		Vector2(float(index) * ATLAS_CELL_SIZE, 0.0),
		Vector2(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	)
