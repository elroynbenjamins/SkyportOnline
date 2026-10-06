class_name WorldMapCanvas
extends Control

signal country_selected(country_code: String)
signal country_hovered(country_code: String)
signal destination_selected(destination_id: String)
signal view_changed(zoom_level: float)

const FALLBACK_HOME_POSITION := Vector2(0.505, 0.215)
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.28
const DRAG_THRESHOLD := 7.0

const OCEAN_COLOR := Color("12394d")
const OCEAN_DEEP := Color("0c2a3a")
const GRID_COLOR := Color(0.39, 0.64, 0.72, 0.13)
const LAND_EDGE := Color("7da889")
const ROUTE_COLOR := Color("74cce7")
const ROUTE_LOCKED_COLOR := Color("7f94a0")
const FUTURE_COLOR := Color("496876")
const SELECTED_COLOR := Color("f2c85e")
const HOME_COLOR := Color("ffd66e")
const AIRPORT_COLOR := Color("c8eff7")

var countries: Array[Dictionary] = []
var destinations: Array[Dictionary] = []
var selected_country_code := ""
var hovered_country_code := ""
var selected_destination_id := ""
var home_country_code := "NL"
var route_country_codes: Dictionary = {}
var unlocked_route_country_codes: Dictionary = {}
var selected_position := Vector2(-1, -1)

var zoom_level := 1.0
var view_center := Vector2(0.5, 0.5)
var route_phase := 0.0

var pointer_down := false
var pointer_dragged := false
var pointer_start := Vector2.ZERO
var last_pointer_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if selected_country_code.is_empty():
		return
	if selected_country_code == home_country_code:
		return
	route_phase = fmod(route_phase + delta * 0.32, 1.0)
	queue_redraw()


func set_countries(values: Array[Dictionary]) -> void:
	countries = values.duplicate(true)
	queue_redraw()


func set_destinations(values: Array[Dictionary]) -> void:
	destinations = values.duplicate(true)
	queue_redraw()


func set_selected_country(country_code: String) -> void:
	selected_country_code = country_code
	selected_position = Vector2(-1, -1)
	queue_redraw()


func set_selected_destination(destination_id: String) -> void:
	selected_destination_id = destination_id
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


func zoom_in() -> void:
	set_zoom_level(zoom_level + ZOOM_STEP)


func zoom_out() -> void:
	set_zoom_level(zoom_level - ZOOM_STEP)


func set_zoom_level(value: float) -> void:
	var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_level):
		return
	zoom_level = next_zoom
	_clamp_view_center()
	view_changed.emit(zoom_level)
	queue_redraw()


func reset_view() -> void:
	zoom_level = MIN_ZOOM
	view_center = Vector2(0.5, 0.5)
	view_changed.emit(zoom_level)
	queue_redraw()


func focus_country(country_code: String, target_zoom: float = 1.75) -> void:
	var country := CountryCatalog.get_country(country_code)
	if country.is_empty():
		return
	view_center = Vector2(
		float(country.get("map_x", 0.5)),
		float(country.get("map_y", 0.5))
	)
	zoom_level = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	_clamp_view_center()
	view_changed.emit(zoom_level)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN_DEEP)
	_draw_ocean_bands()
	_draw_grid()
	_draw_continents()
	_draw_region_labels()

	var home_position := _home_position()
	var selected := _selected_map_position()
	if selected.x >= 0.0:
		_draw_route_arc(home_position, selected)

	for country in countries:
		_draw_country_marker(country)

	_draw_selected_country_airports()
	_draw_home_marker(home_position)
	_draw_legend()


func _draw_ocean_bands() -> void:
	var band_count := 7
	for index in range(band_count):
		var top := size.y * float(index) / float(band_count)
		var height := size.y / float(band_count)
		var alpha := 0.965 + float(index % 2) * 0.018
		var band_color := OCEAN_COLOR
		band_color.a = alpha
		draw_rect(
			Rect2(Vector2(0, top), Vector2(size.x, height + 1.0)),
			band_color
		)


func _draw_grid() -> void:
	for index in range(1, 12):
		var a := _map_to_screen(Vector2(float(index) / 12.0, 0.0))
		var b := _map_to_screen(Vector2(float(index) / 12.0, 1.0))
		draw_line(a, b, GRID_COLOR, 1.0)
	for index in range(1, 6):
		var a := _map_to_screen(Vector2(0.0, float(index) / 6.0))
		var b := _map_to_screen(Vector2(1.0, float(index) / 6.0))
		draw_line(a, b, GRID_COLOR, 1.0)


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
			_map_to_screen(Vector2(float(point[0]), float(point[1])))
		)
	var shadow := PackedVector2Array()
	for point in polygon:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_colored_polygon(shadow, Color(0.01, 0.06, 0.08, 0.24))
	draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
		draw_polyline(outline, LAND_EDGE, 1.5, true)


func _draw_region_labels() -> void:
	var labels := [
		{"text": "NORTH AMERICA", "position": Vector2(0.14, 0.16)},
		{"text": "SOUTH AMERICA", "position": Vector2(0.30, 0.58)},
		{"text": "EUROPE", "position": Vector2(0.50, 0.13)},
		{"text": "AFRICA", "position": Vector2(0.51, 0.48)},
		{"text": "ASIA", "position": Vector2(0.73, 0.18)},
		{"text": "OCEANIA", "position": Vector2(0.82, 0.72)}
	]
	for entry in labels:
		var position := _map_to_screen(entry["position"])
		if not _is_screen_visible(position, 80.0):
			continue
		draw_string(
			ThemeDB.fallback_font,
			position,
			String(entry["text"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0.78, 0.90, 0.86, 0.28)
		)


func _draw_route_arc(from_position: Vector2, to_position: Vector2) -> void:
	if from_position.distance_to(to_position) < 4.0:
		return

	var points := _route_points(from_position, to_position, 41)
	draw_polyline(points, Color(0.25, 0.62, 0.73, 0.28), 4.0, true)

	var phase_offset := int(floor(route_phase * 8.0))
	for index in range(points.size() - 1):
		if (index + phase_offset) % 3 == 0:
			draw_line(
				points[index],
				points[index + 1],
				Color(0.98, 0.84, 0.40, 0.94),
				2.2,
				true
			)

	var plane_t := fmod(route_phase + 0.08, 1.0)
	var plane_position := _quadratic_route_point(
		from_position,
		to_position,
		plane_t
	)
	var ahead := _quadratic_route_point(
		from_position,
		to_position,
		minf(plane_t + 0.018, 1.0)
	)
	var direction := plane_position.direction_to(ahead)
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	_draw_plane_marker(plane_position, direction)


func _route_points(
	from_position: Vector2,
	to_position: Vector2,
	count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var t := float(index) / float(maxi(count - 1, 1))
		points.append(_quadratic_route_point(from_position, to_position, t))
	return points


func _quadratic_route_point(
	from_position: Vector2,
	to_position: Vector2,
	t: float
) -> Vector2:
	var midpoint := from_position.lerp(to_position, 0.5)
	var distance := from_position.distance_to(to_position)
	var control := midpoint + Vector2(
		0,
		-minf(size.y * 0.18, distance * 0.22)
	)
	var inv := 1.0 - t
	return (
		inv * inv * from_position
		+ 2.0 * inv * t * control
		+ t * t * to_position
	)


func _draw_plane_marker(position: Vector2, direction: Vector2) -> void:
	var normal := Vector2(-direction.y, direction.x)
	var nose := position + direction * 7.0
	var tail := position - direction * 6.0
	var wing_left := position + normal * 5.0 - direction * 1.0
	var wing_right := position - normal * 5.0 - direction * 1.0
	var plane := PackedVector2Array([
		nose,
		wing_left,
		tail,
		wing_right
	])
	draw_colored_polygon(plane, Color("fff0a8"))
	draw_polyline(
		PackedVector2Array([
			nose, wing_left, tail, wing_right, nose
		]),
		Color("765d22"),
		1.0
	)


func _draw_country_marker(country: Dictionary) -> void:
	var country_code := String(country.get("id", ""))
	var position := _country_position(country)
	if not _is_screen_visible(position, 36.0):
		return

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

	var show_badge := (
		has_route
		or selected
		or hovered
		or country_code == home_country_code
	)
	if show_badge:
		_draw_country_badge(
			country_code,
			position,
			radius,
			selected,
			hovered,
			has_route,
			unlocked
		)


func _draw_country_badge(
	country_code: String,
	position: Vector2,
	marker_radius: float,
	selected: bool,
	hovered: bool,
	has_route: bool,
	unlocked: bool
) -> void:
	var texture := CountryVisualCatalog.texture_for_country(country_code)
	if texture == null:
		var fallback_color := Color("d9f1f7")
		if selected:
			fallback_color = Color("fff1bd")
		elif has_route and not unlocked:
			fallback_color = Color("aebdc4")
		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(marker_radius + 5.0, 4.0),
			country_code,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			fallback_color
		)
		return

	var badge_size := Vector2(22, 16)
	if selected:
		badge_size = Vector2(30, 22)
	elif hovered:
		badge_size = Vector2(26, 19)

	var badge_position := position + Vector2(
		marker_radius + 5.0,
		-badge_size.y * 0.5
	)
	if badge_position.x + badge_size.x > size.x - 4.0:
		badge_position.x = position.x - marker_radius - 5.0 - badge_size.x
	if badge_position.y < 4.0:
		badge_position.y = 4.0
	elif badge_position.y + badge_size.y > size.y - 4.0:
		badge_position.y = size.y - 4.0 - badge_size.y

	var badge_rect := Rect2(badge_position, badge_size)
	var border_color := Color(0.03, 0.10, 0.14, 0.82)
	if selected:
		border_color = Color(0.96, 0.80, 0.36, 0.72)
	elif has_route and unlocked:
		border_color = Color(0.45, 0.82, 0.91, 0.60)

	draw_rect(badge_rect.grow(2.0), border_color, true)
	draw_texture_rect(texture, badge_rect, false)
	if selected or hovered:
		draw_string(
			ThemeDB.fallback_font,
			badge_rect.position
				+ Vector2(badge_rect.size.x + 4.0, badge_rect.size.y - 3.0),
			country_code,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color("f4f8fa")
		)


func _draw_selected_country_airports() -> void:
	var visible_routes := _routes_for_selected_country()
	if visible_routes.is_empty():
		return

	var country := CountryCatalog.get_country(selected_country_code)
	if country.is_empty():
		return

	var country_position := _country_position(country)
	for index in range(visible_routes.size()):
		var destination: Dictionary = visible_routes[index]
		var position := _destination_marker_position(
			country_position,
			index,
			visible_routes.size()
		)
		var unlocked := bool(destination.get("map_unlocked", false))
		var selected := (
			String(destination.get("id", ""))
			== selected_destination_id
		)

		draw_line(
			country_position,
			position,
			Color(0.65, 0.84, 0.88, 0.22),
			1.0
		)
		_draw_airport_marker(position, destination, unlocked, selected)


func _draw_airport_marker(
	position: Vector2,
	destination: Dictionary,
	unlocked: bool,
	selected: bool
) -> void:
	var fill := AIRPORT_COLOR if unlocked else ROUTE_LOCKED_COLOR
	var border := Color("e6fbff") if unlocked else Color("c1cbd0")
	var radius := 6.0
	if selected:
		fill = SELECTED_COLOR
		border = Color("fff4c2")
		radius = 8.0
		draw_circle(position, 14.0, Color(0.95, 0.78, 0.32, 0.14))

	draw_circle(position, radius + 2.0, Color(0, 0, 0, 0.34))
	draw_circle(position, radius, fill)
	draw_circle(position, radius + 1.0, border, false, 1.4)
	draw_line(
		position + Vector2(-3.5, 0),
		position + Vector2(3.5, 0),
		Color("17313d"),
		1.5
	)
	draw_line(
		position + Vector2(0, -3.5),
		position + Vector2(0, 3.5),
		Color("17313d"),
		1.5
	)

	var city := String(destination.get("city", "Route")).to_upper()
	var label_color := Color("fff0b5") if selected else Color("d9eef3")
	if not unlocked:
		label_color = Color("aebcc2")
	draw_string(
		ThemeDB.fallback_font,
		position + Vector2(10.0, 4.0),
		city,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		label_color
	)


func _draw_home_marker(position: Vector2) -> void:
	if not _is_screen_visible(position, 28.0):
		return
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
	draw_rect(
		Rect2(Vector2(8, y - 12), Vector2(220, 24)),
		Color(0.02, 0.09, 0.12, 0.58),
		true
	)
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
		return _map_to_screen(FALLBACK_HOME_POSITION)
	return _country_position(home_country)


func _selected_map_position() -> Vector2:
	if not selected_country_code.is_empty():
		var country := CountryCatalog.get_country(selected_country_code)
		if not country.is_empty():
			var country_position := _country_position(country)
			var routes := _routes_for_selected_country()
			for index in range(routes.size()):
				if (
					String(routes[index].get("id", ""))
					== selected_destination_id
				):
					return _destination_marker_position(
						country_position,
						index,
						routes.size()
					)
			return country_position
	if selected_position.x >= 0.0:
		return _map_to_screen(selected_position)
	return Vector2(-1, -1)


func _country_position(country: Dictionary) -> Vector2:
	return _map_to_screen(Vector2(
		float(country.get("map_x", 0.5)),
		float(country.get("map_y", 0.5))
	))


func _map_to_screen(normalized_position: Vector2) -> Vector2:
	var canvas_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var offset := normalized_position - view_center
	return (
		canvas_size * 0.5
		+ Vector2(
			offset.x * canvas_size.x * zoom_level,
			offset.y * canvas_size.y * zoom_level
		)
	)


func _screen_to_map(screen_position: Vector2) -> Vector2:
	var canvas_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var delta := screen_position - canvas_size * 0.5
	return view_center + Vector2(
		delta.x / (canvas_size.x * zoom_level),
		delta.y / (canvas_size.y * zoom_level)
	)


func _clamp_view_center() -> void:
	var half_visible := 0.5 / zoom_level
	view_center.x = clampf(
		view_center.x,
		half_visible,
		1.0 - half_visible
	)
	view_center.y = clampf(
		view_center.y,
		half_visible,
		1.0 - half_visible
	)


func _zoom_at(screen_position: Vector2, multiplier: float) -> void:
	var before := _screen_to_map(screen_position)
	var next_zoom := clampf(
		zoom_level * multiplier,
		MIN_ZOOM,
		MAX_ZOOM
	)
	if is_equal_approx(next_zoom, zoom_level):
		return

	var canvas_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var delta := screen_position - canvas_size * 0.5
	zoom_level = next_zoom
	view_center = before - Vector2(
		delta.x / (canvas_size.x * zoom_level),
		delta.y / (canvas_size.y * zoom_level)
	)
	_clamp_view_center()
	view_changed.emit(zoom_level)
	queue_redraw()


func _pan_by_screen_delta(delta: Vector2) -> void:
	var canvas_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	view_center -= Vector2(
		delta.x / (canvas_size.x * zoom_level),
		delta.y / (canvas_size.y * zoom_level)
	)
	_clamp_view_center()
	queue_redraw()


func _routes_for_selected_country() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination in destinations:
		if (
			String(destination.get("country_code", ""))
			== selected_country_code
		):
			result.append(destination)
	return result


func _destination_marker_position(
	country_position: Vector2,
	index: int,
	total: int
) -> Vector2:
	if total <= 1:
		return country_position + Vector2(30.0, -27.0)
	var radius := 38.0 + minf(float(total - 2) * 4.0, 10.0)
	var angle := -PI * 0.75 + TAU * float(index) / float(total)
	return country_position + Vector2(cos(angle), sin(angle)) * radius


func _destination_at(local_position: Vector2) -> String:
	var routes := _routes_for_selected_country()
	if routes.is_empty():
		return ""
	var country := CountryCatalog.get_country(selected_country_code)
	if country.is_empty():
		return ""

	var country_position := _country_position(country)
	var closest_id := ""
	var closest_distance := 16.0
	for index in range(routes.size()):
		var marker_position := _destination_marker_position(
			country_position,
			index,
			routes.size()
		)
		var distance := local_position.distance_to(marker_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(routes[index].get("id", ""))
	return closest_id


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


func _is_screen_visible(position: Vector2, margin: float) -> bool:
	return (
		position.x >= -margin
		and position.y >= -margin
		and position.x <= size.x + margin
		and position.y <= size.y + margin
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.16)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.16)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_pointer(event.position)
			else:
				_end_pointer(event.position)
			accept_event()
			return

	if event is InputEventMouseMotion:
		if pointer_down:
			_update_pointer_drag(event.position)
			accept_event()
			return
		var next_hover := _country_at(event.position)
		if next_hover != hovered_country_code:
			hovered_country_code = next_hover
			country_hovered.emit(next_hover)
			queue_redraw()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_end_pointer(event.position)
		accept_event()
		return

	if event is InputEventScreenDrag:
		_update_pointer_drag(event.position)
		accept_event()
		return

	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		accept_event()


func _begin_pointer(position: Vector2) -> void:
	pointer_down = true
	pointer_dragged = false
	pointer_start = position
	last_pointer_position = position


func _update_pointer_drag(position: Vector2) -> void:
	if not pointer_down:
		return
	if (
		not pointer_dragged
		and pointer_start.distance_to(position) >= DRAG_THRESHOLD
	):
		pointer_dragged = true

	if pointer_dragged and zoom_level > MIN_ZOOM + 0.001:
		var delta := position - last_pointer_position
		_pan_by_screen_delta(delta)
	last_pointer_position = position


func _end_pointer(position: Vector2) -> void:
	if not pointer_down:
		return
	var was_dragged := pointer_dragged
	pointer_down = false
	pointer_dragged = false
	if was_dragged:
		return

	var destination_id := _destination_at(position)
	if not destination_id.is_empty():
		selected_destination_id = destination_id
		queue_redraw()
		destination_selected.emit(destination_id)
		return

	var country_code := _country_at(position)
	if country_code.is_empty():
		return
	selected_country_code = country_code
	hovered_country_code = country_code
	selected_position = Vector2(-1, -1)
	queue_redraw()
	country_selected.emit(country_code)
