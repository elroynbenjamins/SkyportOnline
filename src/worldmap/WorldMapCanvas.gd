class_name WorldMapCanvas
extends Control

signal country_selected(country_code: String)
signal country_hovered(country_code: String)

const FALLBACK_HOME_POSITION := Vector2(0.505, 0.215)
const OCEAN_COLOR := Color("12394d")
const OCEAN_DEEP := Color("0c2a3a")
const GRID_COLOR := Color(0.39, 0.64, 0.72, 0.13)
const LAND_COLOR := Color("4d765f")
const LAND_EDGE := Color("7da889")
const ROUTE_COLOR := Color("74cce7")
const ROUTE_LOCKED_COLOR := Color("7f94a0")
const FUTURE_COLOR := Color("496876")
const SELECTED_COLOR := Color("f2c85e")
const HOME_COLOR := Color("ffd66e")

var countries: Array[Dictionary] = []
var selected_country_code := ""
var hovered_country_code := ""
var home_country_code := "NL"
var route_country_codes: Dictionary = {}
var unlocked_route_country_codes: Dictionary = {}
var selected_position := Vector2(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func set_countries(values: Array[Dictionary]) -> void:
	countries = values.duplicate(true)
	queue_redraw()


func set_selected_country(country_code: String) -> void:
	selected_country_code = country_code
	selected_position = Vector2(-1, -1)
	queue_redraw()


func set_home_country(country_code: String) -> void:
	if CountryCatalog.get_country(country_code).is_empty():
		home_country_code = "NL"
	else:
		home_country_code = country_code
	queue_redraw()


func set_route_countries(
	route_codes: Array[String],
	unlocked_codes: Array[String]
) -> void:
	route_country_codes.clear()
	unlocked_route_country_codes.clear()
	for country_code in route_codes:
		route_country_codes[country_code] = true
	for country_code in unlocked_codes:
		unlocked_route_country_codes[country_code] = true
	queue_redraw()


# Compatibility with the older destination-pin implementation.
func set_selected_position(normalized_position: Vector2) -> void:
	selected_country_code = ""
	selected_position = normalized_position
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN_DEEP)
	draw_rect(
		Rect2(Vector2(0, size.y * 0.08), Vector2(size.x, size.y * 0.84)),
		OCEAN_COLOR
	)
	_draw_grid()
	_draw_continents()

	var home_position := _home_position()
	var selected := _selected_map_position()
	if selected.x >= 0.0:
		_draw_route_arc(home_position, selected)

	for country in countries:
		_draw_country_marker(country)

	_draw_home_marker(home_position)
	_draw_legend()


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


func _draw_continent(points: Array, fill: Color) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(
			Vector2(float(point[0]) * size.x, float(point[1]) * size.y)
		)
	draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
		draw_polyline(outline, LAND_EDGE, 1.5, true)


func _draw_route_arc(from_position: Vector2, to_position: Vector2) -> void:
	if from_position.distance_to(to_position) < 4.0:
		return

	var points := PackedVector2Array()
	var midpoint := from_position.lerp(to_position, 0.5)
	var distance := from_position.distance_to(to_position)
	var control := midpoint + Vector2(0, -minf(size.y * 0.18, distance * 0.22))
	for index in range(25):
		var t := float(index) / 24.0
		var inv := 1.0 - t
		points.append(
			inv * inv * from_position
			+ 2.0 * inv * t * control
			+ t * t * to_position
		)

	for index in range(points.size() - 1):
		if index % 2 == 0:
			draw_line(
				points[index],
				points[index + 1],
				Color(0.98, 0.84, 0.40, 0.92),
				2.0,
				true
			)


func _draw_country_marker(country: Dictionary) -> void:
	var country_code := String(country.get("id", ""))
	var position := _country_position(country)
	var selected := country_code == selected_country_code
	var hovered := country_code == hovered_country_code
	var has_route := route_country_codes.has(country_code)
	var unlocked := unlocked_route_country_codes.has(country_code)

	var radius := 5.0
	var fill := FUTURE_COLOR
	var border := Color("87a4ad")
	if has_route:
		radius = 8.0
		fill = ROUTE_COLOR if unlocked else ROUTE_LOCKED_COLOR
		border = Color("d9f3fb") if unlocked else Color("b4c0c6")
	if hovered:
		radius += 2.5
		border = Color.WHITE
	if selected:
		radius = 11.0
		fill = SELECTED_COLOR
		border = Color("fff3c2")

	if selected:
		draw_circle(position, 18.0, Color(0.95, 0.78, 0.32, 0.16))
		draw_circle(position, 15.0, Color(0.95, 0.78, 0.32, 0.34), false, 2.0)

	draw_circle(position, radius + 2.0, Color(0, 0, 0, 0.30))
	draw_circle(position, radius, fill)
	draw_circle(position, radius + 1.0, border, false, 1.5)

	var show_label := has_route or selected or hovered or country_code == home_country_code
	if show_label:
		var font_color := Color("d9f1f7")
		if selected:
			font_color = Color("fff1bd")
		elif has_route and not unlocked:
			font_color = Color("aebdc4")
		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(radius + 5.0, 4.0),
			country_code,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			font_color
		)


func _draw_home_marker(position: Vector2) -> void:
	var diamond := PackedVector2Array([
		position + Vector2(0, -9),
		position + Vector2(9, 0),
		position + Vector2(0, 9),
		position + Vector2(-9, 0)
	])
	draw_colored_polygon(diamond, HOME_COLOR)
	draw_polyline(
		PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
		]),
		Color("fff4c4"),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		position + Vector2(13, 4),
		"HOME",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("ffe79a")
	)


func _draw_legend() -> void:
	var y := size.y - 16.0
	draw_circle(Vector2(18, y), 5.0, ROUTE_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(29, y + 4),
		"Route",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("bfe8f2")
	)
	draw_circle(Vector2(78, y), 5.0, ROUTE_LOCKED_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(89, y + 4),
		"Locked",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("b5c4ca")
	)
	draw_circle(Vector2(148, y), 4.0, FUTURE_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(158, y + 4),
		"Future",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("91aab4")
	)


func _home_position() -> Vector2:
	var home_country := CountryCatalog.get_country(home_country_code)
	if home_country.is_empty():
		return Vector2(
			FALLBACK_HOME_POSITION.x * size.x,
			FALLBACK_HOME_POSITION.y * size.y
		)
	return _country_position(home_country)


func _selected_map_position() -> Vector2:
	if not selected_country_code.is_empty():
		var country := CountryCatalog.get_country(selected_country_code)
		if not country.is_empty():
			return _country_position(country)
	if selected_position.x >= 0.0:
		return Vector2(
			selected_position.x * size.x,
			selected_position.y * size.y
		)
	return Vector2(-1, -1)


func _country_position(country: Dictionary) -> Vector2:
	return Vector2(
		float(country.get("map_x", 0.5)) * size.x,
		float(country.get("map_y", 0.5)) * size.y
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _country_at(event.position)
		if next_hover != hovered_country_code:
			hovered_country_code = next_hover
			country_hovered.emit(next_hover)
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_select_at(event.position)


func _select_at(local_position: Vector2) -> void:
	var country_code := _country_at(local_position)
	if country_code.is_empty():
		return
	selected_country_code = country_code
	hovered_country_code = country_code
	selected_position = Vector2(-1, -1)
	queue_redraw()
	country_selected.emit(country_code)
	accept_event()


func _country_at(local_position: Vector2) -> String:
	var closest_code := ""
	var closest_distance := 24.0
	for country in countries:
		var marker_position := _country_position(country)
		var distance := local_position.distance_to(marker_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_code = String(country.get("id", ""))
	return closest_code
