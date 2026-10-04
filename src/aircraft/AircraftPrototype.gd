class_name AircraftPrototype
extends Node2D

signal route_completed

@export var taxi_speed: float = 105.0
@export var start_delay: float = 1.2

var route := PackedVector2Array()
var route_index := 0
var moving := false
var delay_remaining := 0.0
var state := "PARKED"


func set_route(points: PackedVector2Array) -> void:
	route = points
	route_index = 0
	moving = false
	state = "PARKED"
	delay_remaining = start_delay

	if route.is_empty():
		visible = false
		return

	visible = true
	position = route[0]
	queue_redraw()


func _process(delta: float) -> void:
	if route.size() < 2:
		return

	if delay_remaining > 0.0:
		delay_remaining -= delta
		if delay_remaining <= 0.0:
			moving = true
			state = "TAXIING"
		return

	if not moving:
		return

	var target_index := mini(route_index + 1, route.size() - 1)
	var target := route[target_index]
	var to_target := target - position
	var distance := to_target.length()

	if distance <= taxi_speed * delta:
		position = target
		route_index = target_index
		if route_index >= route.size() - 1:
			moving = false
			state = "HOLDING"
			route_completed.emit()
			queue_redraw()
			return
	else:
		var direction := to_target.normalized()
		position += direction * taxi_speed * delta
		rotation = direction.angle()

	queue_redraw()


func _draw() -> void:
	# Temporary code-drawn S-class commuter plane. This will be replaced by
	# the dedicated pixel-aircraft sprite pack once pathing is locked.
	draw_ellipse_shadow()

	var fuselage := PackedVector2Array([
		Vector2(22, 0),
		Vector2(12, -5),
		Vector2(-18, -5),
		Vector2(-25, 0),
		Vector2(-18, 5),
		Vector2(12, 5)
	])
	draw_colored_polygon(fuselage, Color("f4f7f7"))

	var wing := PackedVector2Array([
		Vector2(4, -4),
		Vector2(-5, -18),
		Vector2(-12, -18),
		Vector2(-7, -3),
		Vector2(-7, 3),
		Vector2(-12, 18),
		Vector2(-5, 18),
		Vector2(4, 4)
	])
	draw_colored_polygon(wing, Color("dce8ea"))

	var tail := PackedVector2Array([
		Vector2(-14, -4),
		Vector2(-20, -11),
		Vector2(-23, -11),
		Vector2(-20, -3),
		Vector2(-20, 3),
		Vector2(-23, 11),
		Vector2(-20, 11),
		Vector2(-14, 4)
	])
	draw_colored_polygon(tail, Color("5d90b8"))

	draw_rect(Rect2(Vector2(2, -4), Vector2(7, 8)), Color("4a7898"))
	draw_circle(Vector2(14, 0), 2.2, Color("c8e9f1"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
