class_name WorldMapCanvas
extends Control

const HOME_POSITION := Vector2(0.50, 0.46)

var selected_position := Vector2(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_selected_position(normalized_position: Vector2) -> void:
	selected_position = normalized_position
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16384a"))

	_draw_grid()
	_draw_landmasses()

	var home := Vector2(
		HOME_POSITION.x * size.x,
		HOME_POSITION.y * size.y
	)
	draw_circle(home, 9.0, Color("ffd166"))
	draw_circle(home, 4.0, Color("fff2b3"))

	if selected_position.x >= 0.0:
		var selected := Vector2(
			selected_position.x * size.x,
			selected_position.y * size.y
		)
		draw_dashed_line(
			home,
			selected,
			Color("f7d878", 0.9),
			2.0,
			10.0
		)
		draw_circle(selected, 7.0, Color("8ad3ff"))


func _draw_grid() -> void:
	for x_index in range(1, 6):
		var x := size.x * float(x_index) / 6.0
		draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			Color("4c7690", 0.16),
			1.0
		)

	for y_index in range(1, 4):
		var y := size.y * float(y_index) / 4.0
		draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			Color("4c7690", 0.16),
			1.0
		)


func _draw_landmasses() -> void:
	var mainland := PackedVector2Array([
		_norm(Vector2(0.34, 0.25)),
		_norm(Vector2(0.51, 0.20)),
		_norm(Vector2(0.68, 0.27)),
		_norm(Vector2(0.79, 0.41)),
		_norm(Vector2(0.77, 0.61)),
		_norm(Vector2(0.66, 0.76)),
		_norm(Vector2(0.49, 0.82)),
		_norm(Vector2(0.36, 0.72)),
		_norm(Vector2(0.30, 0.55))
	])
	draw_colored_polygon(mainland, Color("4e765f"))

	var uk := PackedVector2Array([
		_norm(Vector2(0.22, 0.32)),
		_norm(Vector2(0.30, 0.30)),
		_norm(Vector2(0.32, 0.43)),
		_norm(Vector2(0.27, 0.53)),
		_norm(Vector2(0.20, 0.48)),
		_norm(Vector2(0.18, 0.38))
	])
	draw_colored_polygon(uk, Color("557d65"))

	var scandinavia := PackedVector2Array([
		_norm(Vector2(0.52, 0.05)),
		_norm(Vector2(0.63, 0.04)),
		_norm(Vector2(0.68, 0.17)),
		_norm(Vector2(0.62, 0.30)),
		_norm(Vector2(0.54, 0.26)),
		_norm(Vector2(0.49, 0.13))
	])
	draw_colored_polygon(scandinavia, Color("527b62"))

	var italy := PackedVector2Array([
		_norm(Vector2(0.58, 0.66)),
		_norm(Vector2(0.62, 0.68)),
		_norm(Vector2(0.66, 0.82)),
		_norm(Vector2(0.63, 0.91)),
		_norm(Vector2(0.59, 0.81))
	])
	draw_colored_polygon(italy, Color("547d63"))

	var iberia := PackedVector2Array([
		_norm(Vector2(0.30, 0.72)),
		_norm(Vector2(0.43, 0.73)),
		_norm(Vector2(0.45, 0.87)),
		_norm(Vector2(0.35, 0.93)),
		_norm(Vector2(0.26, 0.85))
	])
	draw_colored_polygon(iberia, Color("50795f"))


func _norm(point: Vector2) -> Vector2:
	return Vector2(point.x * size.x, point.y * size.y)
