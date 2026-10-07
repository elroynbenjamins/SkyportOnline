class_name FuelTruckPrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 125.0

var current_drive_speed := 0.0
var outbound_travel_duration := 0.0
var return_travel_duration := 0.0
var phase_travel_elapsed := 0.0
var visual_route_progress := 0.0
var traffic_yield_factor := 1.0
var traffic_waiting := false
var traffic_reason := ""
var traffic_blocker_id := -1
var traffic_sequence := 999999
var traffic_stand_uid := -1

var outbound_route := PackedVector2Array()
var return_route := PackedVector2Array()
var route_index := 0
var service_duration := 4.0
var service_remaining := 0.0
var phase := "IDLE"
var launch_delay_remaining := 0.0
var service_pose_rotation := 0.0
var has_service_pose_rotation := false
var service_connection_target := Vector2.ZERO
var has_service_connection_target := false
var motion_clock := 0.0
var visual_motion_amount := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func set_launch_delay(seconds: float) -> void:
	launch_delay_remaining = maxf(seconds, 0.0)


func configure_apron_traffic(
	stand_uid: int,
	sequence: int
) -> void:
	traffic_stand_uid = stand_uid
	traffic_sequence = sequence


func set_service_pose_rotation(value: float) -> void:
	service_pose_rotation = value
	has_service_pose_rotation = true


func set_service_connection_target(
	global_target: Vector2
) -> void:
	service_connection_target = global_target
	has_service_connection_target = true


func start_service(route: PackedVector2Array, duration: float) -> void:
	if route.size() < 2:
		queue_free()
		return

	var baseline_length := GroundServiceMotionRules.route_length(route)
	outbound_route = GroundServiceMotionRules.refined_route(
		route,
		"fuel"
	)
	return_route = outbound_route.duplicate()
	return_route.reverse()
	route_index = 0
	current_drive_speed = 0.0
	outbound_travel_duration = maxf(
		baseline_length / maxf(drive_speed, 1.0),
		0.08
	)
	return_travel_duration = outbound_travel_duration
	phase_travel_elapsed = 0.0
	visual_route_progress = 0.0
	traffic_yield_factor = 1.0
	traffic_waiting = false
	traffic_reason = ""
	traffic_blocker_id = -1
	service_duration = maxf(duration, 0.4)
	service_remaining = service_duration
	position = outbound_route[0]
	visible = true
	phase = "WAITING_LAUNCH" if launch_delay_remaining > 0.0 else "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	motion_clock += delta
	var moving := (
		phase in ["OUTBOUND", "RETURNING"]
		and not traffic_waiting
	)
	visual_motion_amount = move_toward(
		visual_motion_amount,
		1.0 if moving else 0.0,
		delta * 4.0
	)
	if moving or phase == "SERVICING":
		queue_redraw()

	match phase:
		"WAITING_LAUNCH":
			launch_delay_remaining = maxf(
				launch_delay_remaining - delta,
				0.0
			)
			if launch_delay_remaining <= 0.0:
				phase = "OUTBOUND"
				current_drive_speed = 0.0
				queue_redraw()
		"OUTBOUND":
			if _follow_route(
			outbound_route,
			delta,
			outbound_travel_duration
		):
				phase = "SERVICING"
				if has_service_pose_rotation:
					rotation = service_pose_rotation
				service_started.emit()
				queue_redraw()
		"SERVICING":
			service_remaining -= delta
			if service_remaining <= 0.0:
				phase = "RETURNING"
				route_index = 0
				current_drive_speed = 0.0
				phase_travel_elapsed = 0.0
				visual_route_progress = 0.0
				traffic_yield_factor = 1.0
				traffic_waiting = false
				traffic_reason = ""
				traffic_blocker_id = -1
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _follow_route(
			return_route,
			delta,
			return_travel_duration
		):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _follow_route(
	points: PackedVector2Array,
	delta: float,
	travel_duration: float
) -> bool:
	if points.size() < 2:
		return true

	var duration := maxf(travel_duration, 0.01)
	var previous_position := position
	phase_travel_elapsed = minf(
		phase_travel_elapsed + delta,
		duration
	)
	var time_progress := clampf(
		phase_travel_elapsed / duration,
		0.0,
		1.0
	)
	var scheduled_progress := (
		GroundServiceMotionRules.distance_progress_for_time(
			time_progress,
			"fuel"
		)
	)
	var traffic := _current_traffic_decision()
	traffic_yield_factor = float(
		traffic.get("factor", 1.0)
	)
	traffic_waiting = bool(
		traffic.get("yielding", false)
	)
	traffic_reason = String(
		traffic.get("reason", "")
	)
	traffic_blocker_id = int(
		traffic.get("blocker_id", -1)
	)

	var nominal_step := delta / duration
	var progress_step := nominal_step * traffic_yield_factor
	if not traffic_waiting:
		progress_step = nominal_step * 2.20
	visual_route_progress = move_toward(
		visual_route_progress,
		scheduled_progress,
		progress_step
	)
	var sample := GroundServiceMotionRules.sample_route_at_progress(
		points,
		visual_route_progress
	)
	position = sample.get("position", position)
	var target_index := clampi(
		int(sample.get("target_index", 1)),
		1,
		points.size() - 1
	)
	route_index = (
		points.size() - 1
		if bool(sample.get("done", false))
		else maxi(target_index - 1, 0)
	)

	current_drive_speed = (
		previous_position.distance_to(position)
		/ maxf(delta, 0.001)
	)
	var target_heading := GroundServiceMotionRules.lookahead_heading(
		points,
		position,
		target_index,
		"fuel"
	)
	var turn_rate := deg_to_rad(
		GroundServiceMotionRules.turn_rate_degrees("fuel")
	)
	rotation = _rotate_heading_toward(
		rotation,
		target_heading,
		turn_rate * delta
	)
	queue_redraw()

	if (
		time_progress >= 1.0
		and visual_route_progress >= 0.999
	):
		position = points[points.size() - 1]
		route_index = points.size() - 1
		current_drive_speed = 0.0
		rotation = GroundServiceMotionRules.endpoint_heading(points)
		return true
	return false


func _rotate_heading_toward(
	current_heading: float,
	target_heading: float,
	maximum_step: float
) -> float:
	var difference := wrapf(
		target_heading - current_heading,
		-PI,
		PI
	)
	return current_heading + clampf(
		difference,
		-maximum_step,
		maximum_step
	)


func get_apron_traffic_snapshot() -> Dictionary:
	return {
		"instance_id": get_instance_id(),
		"position": global_position,
		"heading": global_rotation,
		"phase": phase,
		"service_type": "fuel",
		"traffic_sequence": traffic_sequence,
		"stand_uid": traffic_stand_uid,
		"yielding": traffic_waiting,
		"route_progress": visual_route_progress,
		"stand_zone": ApronTrafficRules.stand_throat_state({
			"stand_uid": traffic_stand_uid,
			"phase": phase,
			"route_progress": visual_route_progress,
		}),
	}


func _current_traffic_decision() -> Dictionary:
	if phase not in ["OUTBOUND", "RETURNING"]:
		return {
			"factor": 1.0,
			"yielding": false,
			"reason": "",
			"blocker_id": -1,
		}
	var parent := get_parent()
	if parent == null:
		return {
			"factor": 1.0,
			"yielding": false,
			"reason": "",
			"blocker_id": -1,
		}
	var others: Array = []
	for child in parent.get_children():
		if child == self:
			continue
		if not child.has_method("get_apron_traffic_snapshot"):
			continue
		var snapshot_variant = child.call(
			"get_apron_traffic_snapshot"
		)
		if snapshot_variant is Dictionary:
			others.append(snapshot_variant)
	return ApronTrafficRules.traffic_decision(
		get_apron_traffic_snapshot(),
		others
	)


func get_motion_snapshot() -> Dictionary:
	var route := (
		return_route
		if phase == "RETURNING"
		else outbound_route
	)
	return {
		"phase": phase,
		"service_type": "fuel",
		"route_index": route_index,
		"route_points": route.size(),
		"route_length": GroundServiceMotionRules.route_length(route),
		"current_speed": current_drive_speed,
		"travel_elapsed": phase_travel_elapsed,
		"travel_duration": (
			return_travel_duration
			if phase == "RETURNING"
			else outbound_travel_duration
		),
		"turn_rate_deg": GroundServiceMotionRules.turn_rate_degrees(
			"fuel"
		),
		"corner_radius": GroundServiceMotionRules.corner_radius(
			"fuel"
		),
		"braking_distance": GroundServiceMotionRules.braking_distance(
			"fuel"
		),
		"production_road_following": true,
		"traffic_waiting": traffic_waiting,
		"traffic_factor": traffic_yield_factor,
		"traffic_reason": traffic_reason,
		"traffic_blocker_id": traffic_blocker_id,
		"traffic_sequence": traffic_sequence,
		"stand_uid": traffic_stand_uid,
	}




func _draw() -> void:
	_draw_shadow()

	var atlas := GroundServiceVehicleArt.texture()
	if atlas != null:
		var draw_size := GroundServiceVehicleArt.world_size(
			"fuel"
		)
		var source := GroundServiceVehicleArt.source_rect(
			"fuel",
			global_rotation
		)
		draw_set_transform(
			Vector2.ZERO,
			-global_rotation
			+ GroundServiceVehicleArt.turn_lean(
				global_rotation
			),
			Vector2.ONE
		)
		draw_texture_rect_region(
			atlas,
			Rect2(
				-draw_size * 0.5
				+ Vector2(
					0,
					-2 + _motion_bob_y()
				),
				draw_size
			),
			source
		)
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)
	else:
		draw_rect(
			Rect2(Vector2(-13, -7), Vector2(24, 14)),
			Color("e5a83f")
		)
		draw_rect(
			Rect2(Vector2(7, -6), Vector2(11, 12)),
			Color("e9ecec")
		)
		draw_rect(
			Rect2(Vector2(10, -4), Vector2(5, 5)),
			Color("5f8798")
		)
		draw_circle(Vector2(-7, -8), 3.0, Color("292f32"))
		draw_circle(Vector2(10, -8), 3.0, Color("292f32"))
		draw_circle(Vector2(-7, 8), 3.0, Color("292f32"))
		draw_circle(Vector2(10, 8), 3.0, Color("292f32"))

	if phase in ["OUTBOUND", "RETURNING"]:
		_draw_service_beacon(
			0.88 if traffic_waiting else 0.55
		)
	elif phase == "SERVICING":
		_draw_service_beacon(1.0)
		_draw_fuel_hose()


func _motion_bob_y() -> float:
	if visual_motion_amount <= 0.001:
		return 0.0
	var amplitude := GroundServiceVehicleArt.motion_bob_amplitude(
		"fuel"
	)
	return (
		sin(motion_clock * 11.0)
		* amplitude
		* visual_motion_amount
	)


func _draw_service_beacon(
	strength: float = 1.0
) -> void:
	var draw_size := GroundServiceVehicleArt.world_size(
		"fuel"
	)
	var height := maxf(draw_size.y * 0.36, 15.0)
	var pulse := (
		0.5
		+ 0.5 * sin(motion_clock * 8.0)
	)
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation
		+ GroundServiceVehicleArt.turn_lean(
			global_rotation
		),
		Vector2.ONE
	)
	var beacon_position := Vector2(
		0,
		-height + _motion_bob_y()
	)
	draw_circle(
		beacon_position + Vector2(1, 2),
		4.2,
		Color(0.03, 0.06, 0.07, 0.28 * strength)
	)
	draw_circle(
		beacon_position,
		5.0 + pulse * 1.2,
		Color(1.0, 0.72, 0.18, (0.08 + pulse * 0.10) * strength)
	)
	draw_circle(
		beacon_position,
		3.3,
		Color(1.0, 0.72 + pulse * 0.12, 0.22, 0.92 * strength)
	)
	draw_circle(
		beacon_position + Vector2(-1, -1),
		1.2,
		Color(1.0, 0.96, 0.72, 0.95 * strength)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_fuel_hose() -> void:
	if not has_service_connection_target:
		return

	var target := to_local(service_connection_target)
	if target.length() < 1.0:
		return

	var hose_end := target.normalized() * minf(
		target.length(),
		38.0
	)
	var mid := hose_end * 0.55 + Vector2(0, 7)
	draw_polyline(
		PackedVector2Array([
			Vector2(-6, 5),
			mid,
			hose_end
		]),
		Color("2d3438"),
		3.0
	)
	draw_circle(
		hose_end,
		2.5,
		Color("e6b84c")
	)


func _draw_shadow() -> void:
	var radius := GroundServiceVehicleArt.shadow_radius(
		"fuel"
	)
	var aspect := GroundServiceVehicleArt.shadow_aspect(
		"fuel"
	)
	var world_offset := Vector2(3, 5)
	var local_offset := world_offset.rotated(
		-global_rotation
	)
	draw_set_transform(
		local_offset,
		-global_rotation
		+ GroundServiceVehicleArt.turn_lean(
			global_rotation
		),
		Vector2(1.0, aspect)
	)
	draw_circle(
		Vector2(-radius * 0.12, 0),
		radius * 1.10,
		Color(0, 0, 0, 0.10)
	)
	draw_circle(
		Vector2(radius * 0.12, 0),
		radius * 0.84,
		Color(0, 0, 0, 0.16)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
