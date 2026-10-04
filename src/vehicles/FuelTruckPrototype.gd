class_name FuelTruckPrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 125.0

var station_position := Vector2.ZERO
var target_position := Vector2.ZERO
var service_duration := 4.0
var service_remaining := 0.0
var phase := "IDLE"


func start_service(from_position: Vector2, to_position: Vector2, duration: float) -> void:
	station_position = from_position
	target_position = to_position
	service_duration = maxf(duration, 0.4)
	service_remaining = service_duration
	position = station_position
	visible = true
	phase = "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	match phase:
		"OUTBOUND":
			if _move_toward(target_position, delta):
				phase = "SERVICING"
				service_started.emit()
				queue_redraw()
		"SERVICING":
			service_remaining -= delta
			if service_remaining <= 0.0:
				phase = "RETURNING"
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _move_toward(station_position, delta):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _move_toward(target: Vector2, delta: float) -> bool:
	var to_target := target - position
	var distance := to_target.length()
	if distance <= drive_speed * delta:
		position = target
		return true

	var direction := to_target.normalized()
	position += direction * drive_speed * delta
	rotation = direction.angle()
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
