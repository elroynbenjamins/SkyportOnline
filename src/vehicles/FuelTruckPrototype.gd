class_name FuelTruckPrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 125.0

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

	outbound_route = route
	return_route = route.duplicate()
	return_route.reverse()
	route_index = 0
	service_duration = maxf(duration, 0.4)
	service_remaining = service_duration
	position = outbound_route[0]
	visible = true
	phase = "WAITING_LAUNCH" if launch_delay_remaining > 0.0 else "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	match phase:
		"WAITING_LAUNCH":
			launch_delay_remaining = maxf(
				launch_delay_remaining - delta,
				0.0
			)
			if launch_delay_remaining <= 0.0:
				phase = "OUTBOUND"
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
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _follow_route(return_route, delta):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _follow_route(points: PackedVector2Array, delta: float) -> bool:
	if points.size() < 2:
		return true

	var target_index := mini(route_index + 1, points.size() - 1)
	var target := points[target_index]
	var to_target := target - position
	var distance := to_target.length()

	if distance <= drive_speed * delta:
		position = target
		route_index = target_index
		return route_index >= points.size() - 1

	var direction := to_target.normalized()
	position += direction * drive_speed * delta
	rotation = direction.angle()
	queue_redraw()
	return false


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
			-global_rotation,
			Vector2.ONE
		)
		draw_texture_rect_region(
			atlas,
			Rect2(
				-draw_size * 0.5 + Vector2(0, -2),
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

	if phase == "SERVICING":
		_draw_service_beacon()
		_draw_fuel_hose()


func _draw_service_beacon() -> void:
	var draw_size := GroundServiceVehicleArt.world_size(
		"fuel"
	)
	var height := maxf(draw_size.y * 0.36, 15.0)
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation,
		Vector2.ONE
	)
	var beacon_position := Vector2(0, -height)
	draw_circle(
		beacon_position + Vector2(1, 2),
		4.2,
		Color(0.03, 0.06, 0.07, 0.32)
	)
	draw_circle(
		beacon_position,
		3.6,
		Color("ffd166")
	)
	draw_circle(
		beacon_position + Vector2(-1, -1),
		1.3,
		Color("fff0b2")
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
	var world_offset := Vector2(3, 5)
	var local_offset := world_offset.rotated(
		-global_rotation
	)
	draw_set_transform(
		local_offset,
		-global_rotation,
		Vector2(1.0, 0.42)
	)
	draw_circle(
		Vector2.ZERO,
		radius,
		Color(0, 0, 0, 0.20)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
