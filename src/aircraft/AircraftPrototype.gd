class_name AircraftPrototype
extends Node2D

signal route_completed
signal state_changed(state: String)

@export var taxi_speed: float = 105.0
@export var departure_delay: float = 0.8

var route := PackedVector2Array()
var route_index := 0
var moving := false
var delay_remaining := 0.0
var state := "PARKED"
var aircraft_size := "S"
var stand_uid := -1
var runway_uid := -1


func set_departure_route(
	points: PackedVector2Array,
	size_class: String = "S",
	assigned_stand_uid: int = -1,
	assigned_runway_uid: int = -1
) -> void:
	route = points
	aircraft_size = size_class
	stand_uid = assigned_stand_uid
	runway_uid = assigned_runway_uid
	route_index = 0
	moving = false
	delay_remaining = 0.0
	_set_state("WAITING_FUEL")

	if route.is_empty():
		visible = false
		return

	visible = true
	position = route[0]
	queue_redraw()


func mark_service_complete() -> void:
	moving = false
	_set_state("READY_FOR_DEPARTURE")


func begin_departure_after_clearance() -> void:
	if route.size() < 2:
		return
	delay_remaining = departure_delay
	moving = false
	_set_state("CLEARED")


func _process(delta: float) -> void:
	if route.size() < 2:
		return

	if state == "CLEARED":
		delay_remaining -= delta
		if delay_remaining <= 0.0:
			moving = true
			_set_state("TAXIING")
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
			_set_state("HOLDING")
			route_completed.emit()
			queue_redraw()
			return
	else:
		var direction := to_target.normalized()
		position += direction * taxi_speed * delta
		rotation = direction.angle()

	queue_redraw()


func _set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
	queue_redraw()


func _draw() -> void:
	_draw_shadow()

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

	if state == "WAITING_FUEL":
		draw_circle(Vector2(-2, -26), 6.0, Color("f4c95d"))
	elif state == "READY_FOR_DEPARTURE":
		draw_circle(Vector2(-2, -26), 6.0, Color("76d39b"))
	elif state == "CLEARED":
		draw_circle(Vector2(-2, -26), 6.0, Color("78b7e8"))


func _draw_shadow() -> void:
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
