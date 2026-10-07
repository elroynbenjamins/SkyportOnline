class_name FuelTruckPrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 125.0

var current_drive_speed := 0.0

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

	outbound_route = GroundServiceMotionRules.refined_route(
		route,
		"fuel"
	)
	return_route = outbound_route.duplicate()
	return_route.reverse()
	route_index = 0
	current_drive_speed = 0.0
	service_duration = maxf(duration, 0.4)
	service_remaining = service_duration
	position = outbound_route[0]
	visible = true
	phase = "WAITING_LAUNCH" if launch_delay_remaining > 0.0 else "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	motion_clock += delta
	var moving := phase in ["OUTBOUND", "RETURNING"]
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
			if _follow_route(outbound_route, delta):
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
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _follow_route(return_route, delta):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _follow_route(
	points: PackedVector2Array,
	delta: float
) -> bool:
	if points.size() < 2:
		return true

	var target_index := mini(
		route_index + 1,
		points.size() - 1
	)
	var target := points[target_index]
	var to_target := target - position
	var distance := to_target.length()

	var target_speed := GroundServiceMotionRules.speed_for_target(
		points,
		target_index,
		drive_speed,
		"fuel",
		position
	)
	var rate := GroundServiceMotionRules.acceleration("fuel")
	if target_speed < current_drive_speed:
		rate = GroundServiceMotionRules.deceleration("fuel")
	current_drive_speed = move_toward(
		current_drive_speed,
		target_speed,
		rate * delta
	)
	var movement_speed := maxf(
		current_drive_speed,
		drive_speed * 0.18
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

	if distance <= movement_speed * delta:
		position = target
		rotation = _rotate_heading_toward(
			rotation,
			target_heading,
			turn_rate * delta
		)
		route_index = target_index
		if route_index >= points.size() - 1:
			current_drive_speed = 0.0
			rotation = GroundServiceMotionRules.endpoint_heading(points)
			queue_redraw()
			return true
		queue_redraw()
		return false

	var direction := to_target.normalized()
	position += direction * movement_speed * delta
	rotation = _rotate_heading_toward(
		rotation,
		target_heading,
		turn_rate * delta
	)
	queue_redraw()
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
		_draw_service_beacon(0.55)
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
