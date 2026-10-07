class_name GroundServiceMotionRules
extends RefCounted


const STRAIGHT_ANGLE_DEG := 10.0


static func turn_rate_degrees(service_type: String) -> float:
	match service_type:
		"passenger":
			return 105.0
		"fuel", "catering":
			return 120.0
		"cleaning":
			return 138.0
		"cargo":
			return 145.0
		"pushback":
			return 165.0
		_:
			return 135.0


static func corner_radius(service_type: String) -> float:
	match service_type:
		"passenger":
			return 16.0
		"fuel", "catering":
			return 14.0
		"cleaning":
			return 11.0
		"cargo":
			return 10.0
		"pushback":
			return 8.0
		_:
			return 11.0


static func acceleration(service_type: String) -> float:
	match service_type:
		"passenger":
			return 72.0
		"fuel", "catering":
			return 82.0
		"cleaning":
			return 96.0
		"cargo":
			return 104.0
		"pushback":
			return 112.0
		_:
			return 90.0


static func deceleration(service_type: String) -> float:
	match service_type:
		"passenger":
			return 112.0
		"fuel", "catering":
			return 124.0
		"cleaning":
			return 138.0
		"cargo":
			return 145.0
		"pushback":
			return 158.0
		_:
			return 132.0


static func docking_speed_factor(service_type: String) -> float:
	match service_type:
		"passenger":
			return 0.34
		"fuel", "catering":
			return 0.38
		"cleaning":
			return 0.42
		"cargo":
			return 0.44
		"pushback":
			return 0.30
		_:
			return 0.40


static func anticipation_distance(service_type: String) -> float:
	return corner_radius(service_type) * 1.85


static func braking_distance(service_type: String) -> float:
	match service_type:
		"passenger":
			return 34.0
		"fuel", "catering":
			return 30.0
		"cleaning":
			return 25.0
		"cargo":
			return 23.0
		"pushback":
			return 20.0
		_:
			return 25.0


static func turn_angle_degrees(
	previous: Vector2,
	current: Vector2,
	next: Vector2
) -> float:
	var incoming := current - previous
	var outgoing := next - current
	if incoming.length_squared() < 0.001 or outgoing.length_squared() < 0.001:
		return 0.0
	return absf(rad_to_deg(wrapf(
		outgoing.angle() - incoming.angle(),
		-PI,
		PI
	)))


static func corner_speed_factor(angle_degrees: float) -> float:
	var angle := absf(angle_degrees)
	if angle <= STRAIGHT_ANGLE_DEG:
		return 1.0
	if angle < 35.0:
		return 0.88
	if angle < 70.0:
		return 0.72
	if angle < 115.0:
		return 0.56
	return 0.46


static func refined_route(
	points: PackedVector2Array,
	service_type: String
) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()

	var result := PackedVector2Array()
	result.append(points[0])
	var desired_radius := corner_radius(service_type)

	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var next := points[index + 1]
		var incoming := current - previous
		var outgoing := next - current
		var angle := turn_angle_degrees(previous, current, next)

		if (
			angle <= STRAIGHT_ANGLE_DEG
			or incoming.length() < 7.0
			or outgoing.length() < 7.0
		):
			_append_if_distinct(result, current)
			continue

		var usable_radius := minf(
			desired_radius,
			minf(
				incoming.length() * 0.30,
				outgoing.length() * 0.30
			)
		)
		if usable_radius < 3.0:
			_append_if_distinct(result, current)
			continue

		var entry := (
			current
			- incoming.normalized() * usable_radius
		)
		var exit := (
			current
			+ outgoing.normalized() * usable_radius
		)
		var midpoint := (
			entry * 0.24
			+ current * 0.52
			+ exit * 0.24
		)
		_append_if_distinct(result, entry)
		_append_if_distinct(result, midpoint)
		_append_if_distinct(result, exit)

	_append_if_distinct(result, points[points.size() - 1])
	return result


static func speed_for_target(
	route: PackedVector2Array,
	target_index: int,
	base_speed: float,
	service_type: String,
	current_position: Vector2
) -> float:
	if route.is_empty():
		return 0.0
	var safe_target := clampi(target_index, 0, route.size() - 1)
	var factor := 1.0

	if safe_target > 0 and safe_target < route.size() - 1:
		var angle := turn_angle_degrees(
			route[safe_target - 1],
			route[safe_target],
			route[safe_target + 1]
		)
		factor = minf(factor, corner_speed_factor(angle))

	# Begin slowing for the next bend before the vehicle reaches the actual
	# corner point, matching the aircraft ground-motion readability.
	if safe_target < route.size() - 2:
		var next_angle := turn_angle_degrees(
			route[safe_target],
			route[safe_target + 1],
			route[safe_target + 2]
		)
		factor = minf(
			factor,
			lerpf(1.0, corner_speed_factor(next_angle), 0.40)
		)

	if safe_target >= route.size() - 1:
		var distance := current_position.distance_to(route[safe_target])
		var braking := braking_distance(service_type)
		var ratio := clampf(
			distance / maxf(braking, 1.0),
			0.0,
			1.0
		)
		var eased := ratio * ratio * (3.0 - 2.0 * ratio)
		factor = minf(
			factor,
			lerpf(
				docking_speed_factor(service_type),
				1.0,
				eased
			)
		)

	return maxf(
		base_speed * factor,
		base_speed * 0.24
	)


static func lookahead_heading(
	route: PackedVector2Array,
	current_position: Vector2,
	target_index: int,
	service_type: String
) -> float:
	if route.is_empty():
		return 0.0
	var safe_target := clampi(target_index, 0, route.size() - 1)
	var target := route[safe_target]
	var toward := target - current_position
	if toward.length_squared() < 0.001:
		if safe_target > 0:
			return (
				route[safe_target]
				- route[safe_target - 1]
			).angle()
		return 0.0

	var current_direction := toward.normalized()
	if safe_target >= route.size() - 1:
		return current_direction.angle()

	var outgoing := (
		route[safe_target + 1]
		- route[safe_target]
	).normalized()
	if outgoing == Vector2.ZERO:
		return current_direction.angle()

	var distance := toward.length()
	var blend := 1.0 - clampf(
		distance / maxf(
			anticipation_distance(service_type),
			1.0
		),
		0.0,
		1.0
	)
	blend *= 0.56
	var heading := current_direction.lerp(
		outgoing,
		blend
	).normalized()
	if heading == Vector2.ZERO:
		return current_direction.angle()
	return heading.angle()


static func endpoint_heading(route: PackedVector2Array) -> float:
	if route.size() < 2:
		return 0.0
	var direction := (
		route[route.size() - 1]
		- route[route.size() - 2]
	).normalized()
	if direction == Vector2.ZERO:
		return 0.0
	return direction.angle()


static func route_length(route: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, route.size()):
		total += route[index - 1].distance_to(route[index])
	return total


static func _append_if_distinct(
	result: PackedVector2Array,
	point: Vector2
) -> void:
	if result.is_empty():
		result.append(point)
		return
	if result[result.size() - 1].distance_to(point) >= 0.65:
		result.append(point)
