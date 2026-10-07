class_name TaxiMotionRules
extends RefCounted

const STRAIGHT_ANGLE_DEG := 12.0
const SHARP_TURN_ANGLE_DEG := 70.0


static func turn_rate_degrees(
	aircraft_size: String,
	profile: Dictionary = {}
) -> float:
	if profile.has("taxi_turn_rate_deg"):
		return maxf(
			float(profile.get("taxi_turn_rate_deg", 120.0)),
			30.0
		)

	match aircraft_size:
		"M":
			return 105.0
		"L":
			return 82.0
		"XL":
			return 68.0
		_:
			return 145.0


static func corner_radius(
	aircraft_size: String,
	profile: Dictionary = {}
) -> float:
	if profile.has("taxi_corner_radius"):
		return maxf(
			float(profile.get("taxi_corner_radius", 12.0)),
			4.0
		)

	match aircraft_size:
		"M":
			return 19.0
		"L":
			return 26.0
		"XL":
			return 34.0
		_:
			return 13.0


static func corner_speed_factor(angle_degrees: float) -> float:
	var angle := absf(angle_degrees)
	if angle <= STRAIGHT_ANGLE_DEG:
		return 1.0
	if angle < 35.0:
		return 0.90
	if angle < SHARP_TURN_ANGLE_DEG:
		return 0.78
	if angle < 115.0:
		return 0.62
	return 0.52


static func turn_angle_degrees(
	previous: Vector2,
	current: Vector2,
	next: Vector2
) -> float:
	var incoming := current - previous
	var outgoing := next - current
	if incoming.length() < 0.001 or outgoing.length() < 0.001:
		return 0.0

	return absf(
		rad_to_deg(
			wrapf(
				outgoing.angle() - incoming.angle(),
				-PI,
				PI
			)
		)
	)


static func refined_route(
	points: PackedVector2Array,
	aircraft_size: String,
	profile: Dictionary = {}
) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()

	var result := PackedVector2Array()
	result.append(points[0])
	var desired_radius := corner_radius(
		aircraft_size,
		profile
	)

	for index in range(1, points.size() - 1):
		var previous := points[index - 1]
		var current := points[index]
		var next := points[index + 1]
		var incoming := current - previous
		var outgoing := next - current
		var angle := turn_angle_degrees(
			previous,
			current,
			next
		)

		if (
			angle <= STRAIGHT_ANGLE_DEG
			or incoming.length() < 8.0
			or outgoing.length() < 8.0
		):
			_append_if_distinct(result, current)
			continue

		var usable_radius := minf(
			desired_radius,
			minf(
				incoming.length() * 0.32,
				outgoing.length() * 0.32
			)
		)
		if usable_radius < 4.0:
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

		_append_if_distinct(result, entry)

		# A center-weighted midpoint makes a 90 degree grid corner feel
		# rounded without introducing a full spline/path dependency.
		var midpoint := (
			entry * 0.25
			+ current * 0.50
			+ exit * 0.25
		)
		_append_if_distinct(result, midpoint)
		_append_if_distinct(result, exit)

	_append_if_distinct(
		result,
		points[points.size() - 1]
	)
	return result


static func speed_for_target(
	route: PackedVector2Array,
	current_index: int,
	target_index: int,
	base_speed: float
) -> float:
	if route.size() < 3:
		return base_speed
	if target_index <= 0 or target_index >= route.size() - 1:
		return base_speed

	var previous_index := maxi(target_index - 1, 0)
	var next_index := mini(
		target_index + 1,
		route.size() - 1
	)
	var angle := turn_angle_degrees(
		route[previous_index],
		route[target_index],
		route[next_index]
	)
	var factor := corner_speed_factor(angle)

	# Start easing before the actual bend when possible.
	if current_index >= 0 and current_index < route.size() - 2:
		var lookahead_index := mini(
			target_index + 1,
			route.size() - 2
		)
		if lookahead_index > target_index:
			var next_angle := turn_angle_degrees(
				route[target_index],
				route[lookahead_index],
				route[lookahead_index + 1]
			)
			factor = minf(
				factor,
				lerpf(
					1.0,
					corner_speed_factor(next_angle),
					0.45
				)
			)

	return maxf(base_speed * factor, base_speed * 0.48)


static func anticipation_distance(
	aircraft_size: String,
	profile: Dictionary = {}
) -> float:
	if profile.has("taxi_anticipation_distance"):
		return maxf(
			float(profile.get("taxi_anticipation_distance", 24.0)),
			10.0
		)
	return corner_radius(aircraft_size, profile) * 1.75


static func braking_distance(
	aircraft_size: String,
	profile: Dictionary = {}
) -> float:
	if profile.has("taxi_braking_distance"):
		return maxf(
			float(profile.get("taxi_braking_distance", 30.0)),
			12.0
		)
	match aircraft_size:
		"M":
			return 40.0
		"L":
			return 52.0
		"XL":
			return 66.0
		_:
			return 30.0


static func lookahead_heading(
	route: PackedVector2Array,
	current_position: Vector2,
	target_index: int,
	aircraft_size: String,
	profile: Dictionary = {}
) -> float:
	if route.is_empty():
		return 0.0
	var safe_target := clampi(
		target_index,
		0,
		route.size() - 1
	)
	var target := route[safe_target]
	var to_target := target - current_position
	if to_target.length_squared() < 0.0001:
		if safe_target > 0:
			return (
				route[safe_target]
				- route[safe_target - 1]
			).angle()
		return 0.0

	var current_direction := to_target.normalized()
	if safe_target >= route.size() - 1:
		return current_direction.angle()

	var outgoing := (
		route[safe_target + 1]
		- route[safe_target]
	).normalized()
	if outgoing == Vector2.ZERO:
		return current_direction.angle()

	var distance := to_target.length()
	var anticipation := anticipation_distance(
		aircraft_size,
		profile
	)
	var blend := 1.0 - clampf(
		distance / maxf(anticipation, 1.0),
		0.0,
		1.0
	)
	# Keep the visual heading close to the actual movement vector to avoid
	# sideways-looking aircraft, while still beginning the nose turn early.
	blend *= 0.62
	var blended := current_direction.lerp(
		outgoing,
		blend
	).normalized()
	if blended == Vector2.ZERO:
		return current_direction.angle()
	return blended.angle()


static func braking_speed_factor(
	distance_to_stop: float,
	aircraft_size: String,
	profile: Dictionary = {},
	minimum_factor: float = 0.28
) -> float:
	var distance := braking_distance(
		aircraft_size,
		profile
	)
	var ratio := clampf(
		distance_to_stop / maxf(distance, 1.0),
		0.0,
		1.0
	)
	# Smoothstep gives a gentle initial reduction and stronger braking near
	# the stop line / parking point.
	var eased := ratio * ratio * (3.0 - 2.0 * ratio)
	return lerpf(
		clampf(minimum_factor, 0.12, 0.95),
		1.0,
		eased
	)


static func endpoint_heading(
	route: PackedVector2Array
) -> float:
	if route.size() < 2:
		return 0.0
	var direction := (
		route[route.size() - 1]
		- route[route.size() - 2]
	).normalized()
	if direction == Vector2.ZERO:
		return 0.0
	return direction.angle()


static func _append_if_distinct(
	result: PackedVector2Array,
	point: Vector2
) -> void:
	if result.is_empty():
		result.append(point)
		return
	if result[result.size() - 1].distance_to(point) >= 0.75:
		result.append(point)
