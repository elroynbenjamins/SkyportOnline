class_name ApronTrafficRules
extends RefCounted

# Small visual lane offsets keep vehicles from perfectly overlapping while
# staying inside the same logical service-road route.
const SERVICE_LANE_OFFSETS := {
	"passenger": -5.0,
	"cleaning": -3.0,
	"pushback": -1.0,
	"fuel": 1.5,
	"catering": 3.5,
	"cargo": 5.5
}

const STAND_STAGGER_SECONDS := 0.45
const MAX_STAGGER_SECONDS := 1.80


static func lane_offset(service_type: String) -> float:
	return float(
		SERVICE_LANE_OFFSETS.get(service_type, 0.0)
	)


static func stagger_delay(active_approaches: int) -> float:
	return minf(
		maxi(active_approaches, 0)
		* STAND_STAGGER_SECONDS,
		MAX_STAGGER_SECONDS
	)


static func offset_route(
	points: PackedVector2Array,
	service_type: String
) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()

	var offset := lane_offset(service_type)
	if absf(offset) < 0.01:
		return points.duplicate()

	var result := PackedVector2Array()
	result.append(points[0])

	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var next := points[index + 1]

		var incoming := (current - previous).normalized()
		var outgoing := (next - current).normalized()
		var direction := incoming + outgoing
		if direction.length() < 0.01:
			direction = outgoing
		if direction.length() < 0.01:
			direction = incoming
		if direction.length() < 0.01:
			result.append(current)
			continue

		direction = direction.normalized()
		var normal := Vector2(-direction.y, direction.x)
		result.append(current + normal * offset)

	# Keep the aircraft docking point exact.
	result.append(points[points.size() - 1])
	return result


static func minimum_visual_spacing(
	service_type: String
) -> float:
	match service_type:
		"passenger":
			return 20.0
		"pushback":
			return 18.0
		_:
			return 16.0
