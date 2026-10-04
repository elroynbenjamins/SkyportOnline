class_name TaxiTrafficController
extends Node

signal hold_changed(
	aircraft: AircraftPrototype,
	holding: bool,
	reason: String
)

const BASE_CLEARANCE_S := 24.0
const BASE_CLEARANCE_M := 34.0
const BASE_CLEARANCE_L := 46.0
const BASE_CLEARANCE_XL := 58.0

var registered: Dictionary = {}
var reservations: Dictionary = {}


func register_aircraft(aircraft: AircraftPrototype) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	registered[aircraft.get_instance_id()] = aircraft


func unregister_aircraft(aircraft: AircraftPrototype) -> void:
	if aircraft == null:
		return
	var key := aircraft.get_instance_id()
	registered.erase(key)
	reservations.erase(key)


func request_segment(
	aircraft: AircraftPrototype,
	from_point: Vector2,
	to_point: Vector2
) -> Dictionary:
	if aircraft == null or not is_instance_valid(aircraft):
		return {
			"allowed": false,
			"reason": "invalid aircraft"
		}

	_cleanup_invalid()
	register_aircraft(aircraft)

	var aircraft_id := aircraft.get_instance_id()
	if reservations.has(aircraft_id):
		var existing: Dictionary = reservations[aircraft_id]
		if (
			Vector2(existing.get("from", Vector2.ZERO)).distance_to(
				from_point
			) < 0.5
			and Vector2(existing.get("to", Vector2.ZERO)).distance_to(
				to_point
			) < 0.5
		):
			return {
				"allowed": true,
				"reason": ""
			}
		reservations.erase(aircraft_id)

	var self_clearance := clearance_for_aircraft(aircraft)

	for other_id_variant in reservations.keys():
		var other_id := int(other_id_variant)
		if other_id == aircraft_id:
			continue

		var reservation: Dictionary = reservations[other_id]
		var other := reservation.get("aircraft") as AircraftPrototype
		if other == null or not is_instance_valid(other):
			continue

		var other_clearance := clearance_for_aircraft(other)
		var clearance := maxf(self_clearance, other_clearance)
		var other_from: Vector2 = reservation.get(
			"from",
			Vector2.ZERO
		)
		var other_to: Vector2 = reservation.get(
			"to",
			Vector2.ZERO
		)

		if _segments_conflict(
			from_point,
			to_point,
			other_from,
			other_to,
			clearance
		):
			var reason := _conflict_reason(
				aircraft,
				other,
				from_point,
				to_point,
				other_from,
				other_to
			)
			hold_changed.emit(
				aircraft,
				true,
				reason
			)
			return {
				"allowed": false,
				"reason": reason,
				"blocked_by": other
			}

	# Avoid entering a waypoint already occupied by a taxiing aircraft that
	# has not requested its next segment yet.
	for other_variant in registered.values():
		var other := other_variant as AircraftPrototype
		if other == null or not is_instance_valid(other):
			continue
		if other == aircraft:
			continue
		if not other.visible:
			continue
		if not _is_ground_traffic_state(other.state):
			continue

		var clearance := maxf(
			self_clearance,
			clearance_for_aircraft(other)
		)
		if other.global_position.distance_to(to_point) < clearance:
			var reason := (
				"arrival traffic"
				if other.state == "TAXIING_IN"
				else "aircraft ahead"
			)
			hold_changed.emit(
				aircraft,
				true,
				reason
			)
			return {
				"allowed": false,
				"reason": reason,
				"blocked_by": other
			}

	reservations[aircraft_id] = {
		"aircraft": aircraft,
		"from": from_point,
		"to": to_point,
		"state": aircraft.state
	}
	hold_changed.emit(aircraft, false, "")
	return {
		"allowed": true,
		"reason": ""
	}


func release_segment(aircraft: AircraftPrototype) -> void:
	if aircraft == null:
		return
	reservations.erase(aircraft.get_instance_id())


func release_all_for_aircraft(
	aircraft: AircraftPrototype
) -> void:
	release_segment(aircraft)


func get_active_reservation_count() -> int:
	_cleanup_invalid()
	return reservations.size()


func has_reservation(
	aircraft: AircraftPrototype
) -> bool:
	if aircraft == null:
		return false
	return reservations.has(aircraft.get_instance_id())


func get_reservation(
	aircraft: AircraftPrototype
) -> Dictionary:
	if aircraft == null:
		return {}
	var key := aircraft.get_instance_id()
	if not reservations.has(key):
		return {}
	return (reservations[key] as Dictionary).duplicate(true)


static func clearance_for_aircraft(
	aircraft: AircraftPrototype
) -> float:
	if aircraft == null:
		return BASE_CLEARANCE_S

	var profile := aircraft.get_aircraft_profile()
	if profile.has("taxi_clearance_radius"):
		return maxf(
			float(
				profile.get(
					"taxi_clearance_radius",
					BASE_CLEARANCE_S
				)
			),
			12.0
		)

	match aircraft.aircraft_size:
		"M":
			return BASE_CLEARANCE_M
		"L":
			return BASE_CLEARANCE_L
		"XL":
			return BASE_CLEARANCE_XL
		_:
			return BASE_CLEARANCE_S


func _cleanup_invalid() -> void:
	for key_variant in reservations.keys():
		var key := int(key_variant)
		var reservation: Dictionary = reservations[key]
		var aircraft := reservation.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			reservations.erase(key)

	for key_variant in registered.keys():
		var key := int(key_variant)
		var aircraft := registered[key] as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			registered.erase(key)


func _segments_conflict(
	a_from: Vector2,
	a_to: Vector2,
	b_from: Vector2,
	b_to: Vector2,
	clearance: float
) -> bool:
	# Exact or reversed shared taxi segments.
	if (
		a_from.distance_to(b_from) < clearance
		and a_to.distance_to(b_to) < clearance
	):
		return true
	if (
		a_from.distance_to(b_to) < clearance
		and a_to.distance_to(b_from) < clearance
	):
		return true

	# Shared / crossing holding points.
	if a_to.distance_to(b_to) < clearance:
		return true
	if a_to.distance_to(b_from) < clearance * 0.82:
		return true
	if a_from.distance_to(b_to) < clearance * 0.82:
		return true

	# Corridor intersection / near-intersection.
	if _segments_intersect(a_from, a_to, b_from, b_to):
		return true

	var minimum_distance := minf(
		_point_segment_distance(a_from, b_from, b_to),
		_point_segment_distance(a_to, b_from, b_to)
	)
	minimum_distance = minf(
		minimum_distance,
		_point_segment_distance(b_from, a_from, a_to)
	)
	minimum_distance = minf(
		minimum_distance,
		_point_segment_distance(b_to, a_from, a_to)
	)
	return minimum_distance < clearance * 0.72


func _conflict_reason(
	aircraft: AircraftPrototype,
	other: AircraftPrototype,
	a_from: Vector2,
	a_to: Vector2,
	b_from: Vector2,
	b_to: Vector2
) -> String:
	if other.state == "TAXIING_IN" and aircraft.state != "TAXIING_IN":
		return "arrival traffic"

	var same_direction := (
		(a_to - a_from).normalized().dot(
			(b_to - b_from).normalized()
		) > 0.35
	)
	if same_direction:
		return "aircraft ahead"
	return "crossing traffic"


func _is_ground_traffic_state(state: String) -> bool:
	return state in [
		"TAXIING_OUT",
		"TAXIING_IN",
		"HOLD_SHORT",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"LANDING_ROLL"
	]


func _point_segment_distance(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)

	var t := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	var closest := segment_start + segment * t
	return point.distance_to(closest)


func _segments_intersect(
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2
) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := _cross(ab, cd)
	if absf(denominator) < 0.0001:
		return false

	var ac := c - a
	var t := _cross(ac, cd) / denominator
	var u := _cross(ac, ab) / denominator
	return (
		t >= 0.0 and t <= 1.0
		and u >= 0.0 and u <= 1.0
	)


func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
