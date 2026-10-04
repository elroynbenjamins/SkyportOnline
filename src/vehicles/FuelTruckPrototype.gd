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
	phase = "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	match phase:
		"OUTBOUND":
			if _follow_route(outbound_route, delta):
				phase = "SERVICING"
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

	draw_rect(Rect2(Vector2(-13, -7), Vector2(24, 14)), Color("e5a83f"))
	draw_rect(Rect2(Vector2(7, -6), Vector2(11, 12)), Color("e9ecec"))
	draw_rect(Rect2(Vector2(10, -4), Vector2(5, 5)), Color("5f8798"))
	draw_circle(Vector2(-7, -8), 3.0, Color("292f32"))
	draw_circle(Vector2(10, -8), 3.0, Color("292f32"))
	draw_circle(Vector2(-7, 8), 3.0, Color("292f32"))
	draw_circle(Vector2(10, 8), 3.0, Color("292f32"))

	if phase == "SERVICING":
		draw_circle(Vector2(-1, -14), 4.0, Color("ffd166"))


func _draw_shadow() -> void:
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
