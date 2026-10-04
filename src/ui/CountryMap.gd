class_name CountryMap
extends Control

signal country_selected(country_id: String)

var countries: Array[Dictionary] = []
var selected_country_id := ""
var hovered_country_id := ""

const OCEAN_COLOR := Color("0a3145")
const GRID_COLOR := Color(0.22, 0.45, 0.55, 0.18)
const LAND_COLOR := Color("3e765f")
const LAND_EDGE := Color("79a984")
const MARKER_COLOR := Color("6fd2e8")
const MARKER_HOVER := Color("d7f6fb")
const MARKER_SELECTED := Color("f3c65e")


func _ready() -> void:
	custom_minimum_size = Vector2(650, 330)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func set_countries(values: Array[Dictionary]) -> void:
	countries = values.duplicate(true)
	queue_redraw()


func set_selected_country(country_id: String) -> void:
	selected_country_id = country_id
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN_COLOR)
	_draw_grid()
	_draw_continents()
	for country in countries:
		_draw_country_marker(country)


func _draw_grid() -> void:
	for index in range(1, 12):
		var x := size.x * float(index) / 12.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for index in range(1, 6):
		var y := size.y * float(index) / 6.0
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _draw_continents() -> void:
	_draw_continent([
		[0.04, 0.17], [0.17, 0.08], [0.29, 0.13], [0.34, 0.27],
		[0.27, 0.41], [0.20, 0.43], [0.12, 0.35], [0.06, 0.27]
	])
	_draw_continent([
		[0.27, 0.43], [0.38, 0.48], [0.41, 0.62], [0.36, 0.83],
		[0.31, 0.91], [0.28, 0.72], [0.25, 0.55]
	])
	_draw_continent([
		[0.43, 0.18], [0.57, 0.15], [0.64, 0.24], [0.59, 0.34],
		[0.50, 0.34], [0.44, 0.28]
	])
	_draw_continent([
		[0.48, 0.34], [0.61, 0.34], [0.65, 0.50], [0.61, 0.76],
		[0.55, 0.84], [0.48, 0.63], [0.45, 0.45]
	])
	_draw_continent([
		[0.59, 0.19], [0.78, 0.11], [0.94, 0.18], [0.93, 0.39],
		[0.82, 0.48], [0.71, 0.45], [0.63, 0.34]
	])
	_draw_continent([
		[0.79, 0.61], [0.92, 0.60], [0.96, 0.77], [0.88, 0.86],
		[0.80, 0.78]
	])
	_draw_continent([
		[0.94, 0.75], [0.98, 0.77], [0.99, 0.85], [0.96, 0.88]
	])


func _draw_continent(values: Array) -> void:
	var polygon := PackedVector2Array()
	for value in values:
		polygon.append(Vector2(float(value[0]) * size.x, float(value[1]) * size.y))
	draw_colored_polygon(polygon, LAND_COLOR)
	var closed := polygon.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
		draw_polyline(closed, LAND_EDGE, 2.0)


func _draw_country_marker(country: Dictionary) -> void:
	var country_id := String(country.get("id", ""))
	var marker_position := _country_position(country)
	var is_selected := country_id == selected_country_id
	var is_hovered := country_id == hovered_country_id

	var marker_size := 12.0
	var fill := MARKER_COLOR
	if is_hovered:
		marker_size = 16.0
		fill = MARKER_HOVER
	if is_selected:
		marker_size = 20.0
		fill = MARKER_SELECTED
		var glow := MARKER_SELECTED
		glow.a = 0.18
		draw_rect(
			Rect2(marker_position - Vector2(14, 14), Vector2(28, 28)),
			glow
		)

	draw_circle(
		marker_position,
		marker_size * 0.5 + 3.0,
		Color(0, 0, 0, 0.28)
	)
	draw_circle(
		marker_position,
		marker_size * 0.5,
		fill
	)

	if is_selected:
		draw_circle(
			marker_position,
			13.0,
			Color("fff3bd"),
			false,
			2.0
		)
		draw_circle(
			marker_position,
			17.0,
			Color("f2c96d", 0.28),
			false,
			3.0
		)


func _country_position(country: Dictionary) -> Vector2:
	return Vector2(
		float(country.get("map_x", 0.5)) * size.x,
		float(country.get("map_y", 0.5)) * size.y
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _country_at(event.position)
		if next_hover != hovered_country_id:
			hovered_country_id = next_hover
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_select_at(event.position)


func _select_at(local_position: Vector2) -> void:
	var country_id := _country_at(local_position)
	if country_id.is_empty():
		return
	selected_country_id = country_id
	hovered_country_id = country_id
	queue_redraw()
	country_selected.emit(country_id)
	accept_event()


func _country_at(local_position: Vector2) -> String:
	var closest_id := ""
	var closest_distance := 22.0
	for country in countries:
		var distance := local_position.distance_to(_country_position(country))
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(country.get("id", ""))
	return closest_id
