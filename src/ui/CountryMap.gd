class_name CountryMap
extends Control

signal country_selected(country_id: String)
signal country_hovered(country_id: String)

var countries: Array[Dictionary] = []
var selected_country_id := ""
var hovered_country_id := ""

const OCEAN_COLOR := Color("12394d")
const OCEAN_DEEP := Color("0c2a3a")
const GRID_COLOR := Color(0.35, 0.62, 0.70, 0.13)
const LAND_COLOR := Color("4f785f")
const LAND_EDGE := Color("80aa8c")
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
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN_DEEP)
	draw_rect(
		Rect2(Vector2(0, size.y * 0.08), Vector2(size.x, size.y * 0.84)),
		OCEAN_COLOR
	)
	_draw_grid()
	_draw_continents()
	for country in countries:
		_draw_country_marker(country)
	_draw_hint()


func _draw_grid() -> void:
	for index in range(1, 12):
		var x := size.x * float(index) / 12.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for index in range(1, 6):
		var y := size.y * float(index) / 6.0
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _draw_continents() -> void:
	_draw_continent([
		[0.035, 0.17], [0.10, 0.10], [0.18, 0.08], [0.27, 0.12],
		[0.32, 0.21], [0.30, 0.32], [0.25, 0.39], [0.17, 0.42],
		[0.10, 0.35], [0.055, 0.28]
	], Color("4b745d"))
	_draw_continent([
		[0.27, 0.40], [0.34, 0.45], [0.39, 0.55], [0.39, 0.66],
		[0.35, 0.80], [0.31, 0.91], [0.28, 0.75], [0.25, 0.55]
	], Color("4f795f"))
	_draw_continent([
		[0.43, 0.16], [0.52, 0.13], [0.61, 0.15], [0.66, 0.22],
		[0.62, 0.30], [0.55, 0.33], [0.48, 0.30], [0.43, 0.24]
	], Color("587f63"))
	_draw_continent([
		[0.48, 0.31], [0.58, 0.31], [0.64, 0.43], [0.63, 0.57],
		[0.59, 0.74], [0.55, 0.84], [0.49, 0.67], [0.46, 0.47]
	], Color("547b61"))
	_draw_continent([
		[0.59, 0.17], [0.70, 0.12], [0.82, 0.11], [0.94, 0.18],
		[0.95, 0.29], [0.91, 0.40], [0.83, 0.47], [0.73, 0.46],
		[0.65, 0.37], [0.62, 0.26]
	], Color("527961"))
	_draw_continent([
		[0.78, 0.61], [0.87, 0.58], [0.94, 0.64], [0.96, 0.76],
		[0.91, 0.85], [0.83, 0.84], [0.79, 0.75]
	], Color("557c62"))
	_draw_continent([
		[0.94, 0.72], [0.98, 0.76], [0.985, 0.84], [0.96, 0.89],
		[0.94, 0.83]
	], Color("567d63"))


func _draw_continent(values: Array, fill: Color) -> void:
	var polygon := PackedVector2Array()
	for value in values:
		polygon.append(
			Vector2(float(value[0]) * size.x, float(value[1]) * size.y)
		)
	draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
		draw_polyline(outline, LAND_EDGE, 1.5, true)


func _draw_country_marker(country: Dictionary) -> void:
	var country_id := String(country.get("id", ""))
	var marker_position := _country_position(country)
	var is_selected := country_id == selected_country_id
	var is_hovered := country_id == hovered_country_id

	var marker_size := 12.0
	var fill := MARKER_COLOR
	var border := Color("d3f0f6")
	if is_hovered:
		marker_size = 17.0
		fill = MARKER_HOVER
		border = Color.WHITE
	if is_selected:
		marker_size = 22.0
		fill = MARKER_SELECTED
		border = Color("fff3bd")
		draw_circle(
			marker_position,
			18.0,
			Color(0.95, 0.78, 0.32, 0.16)
		)
		draw_circle(
			marker_position,
			15.0,
			Color(0.95, 0.78, 0.32, 0.35),
			false,
			2.0
		)

	draw_circle(
		marker_position,
		marker_size * 0.5 + 3.0,
		Color(0, 0, 0, 0.30)
	)
	draw_circle(
		marker_position,
		marker_size * 0.5,
		fill
	)
	draw_circle(
		marker_position,
		marker_size * 0.5 + 1.0,
		border,
		false,
		1.5
	)

	if is_selected or is_hovered:
		var text_color := (
			Color("fff0b8")
			if is_selected
			else Color("ecfbff")
		)
		draw_string(
			ThemeDB.fallback_font,
			marker_position + Vector2(marker_size * 0.5 + 6.0, 4.0),
			"%s  %s" % [
				country_id,
				String(country.get("name", "Country"))
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			text_color
		)


func _draw_hint() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(14, size.y - 12),
		"Tap a marker or use the country list",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("a8c7d0")
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
			country_hovered.emit(next_hover)
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
	var closest_distance := 26.0
	for country in countries:
		var distance := local_position.distance_to(_country_position(country))
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(country.get("id", ""))
	return closest_id
