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
const COUNTRY_HIT_RADIUS := 32.0
const SELECTED_HALO_RADIUS := 24.0
const GEOGRAPHY_DETAIL_COUNT := 12
const AIRPORT_LABEL_ZOOM := 1.35
const NETWORK_ROUTE_WIDTH := 1.35

var countries: Array[Dictionary] = []
var destinations: Array[Dictionary] = []
var selected_country_code := ""
var hovered_country_code := ""
var selected_destination_id := ""
var home_country_code := "NL"
var route_country_codes: Dictionary = {}
var unlocked_route_country_codes: Dictionary = {}
var selected_position := Vector2(-1, -1)
var route_preview: Dictionary = {}

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


func set_route_preview(preview: Dictionary) -> void:
	route_preview = preview.duplicate(true)
	queue_redraw()


func route_preview_text() -> String:
	if route_preview.is_empty():
		return ""
	return "%s • %d km • %s • %s" % [
		String(route_preview.get("city", "Route")).to_upper(),
		int(route_preview.get("distance_km", 0)),
		String(route_preview.get("duration_text", "—")),
		String(route_preview.get("status", "READY"))
	]


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
	_draw_geography_details()
	_draw_region_labels()

	var home_position := _home_position()
	_draw_route_network(home_position)
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
	# Stylized rather than geographic-to-the-pixel, but deliberately detailed
	# enough that the map reads as a world instead of seven simple blobs.
	_draw_continent([
		[0.025, 0.18], [0.055, 0.13], [0.10, 0.095], [0.16, 0.075],
		[0.22, 0.09], [0.275, 0.125], [0.315, 0.18], [0.325, 0.235],
		[0.305, 0.28], [0.31, 0.325], [0.275, 0.36], [0.245, 0.405],
		[0.205, 0.425], [0.165, 0.405], [0.135, 0.37], [0.09, 0.355],
		[0.06, 0.31], [0.035, 0.265]
	], Color("4b745d"))
	_draw_continent([
		[0.27, 0.405], [0.315, 0.43], [0.35, 0.475], [0.38, 0.54],
		[0.395, 0.61], [0.39, 0.68], [0.365, 0.75], [0.345, 0.82],
		[0.315, 0.91], [0.29, 0.855], [0.275, 0.78], [0.26, 0.70],
		[0.245, 0.61], [0.245, 0.52]
	], Color("4f795f"))
	_draw_continent([
		[0.425, 0.18], [0.455, 0.145], [0.505, 0.13], [0.555, 0.135],
		[0.61, 0.15], [0.65, 0.19], [0.665, 0.23], [0.645, 0.265],
		[0.615, 0.285], [0.59, 0.32], [0.545, 0.335], [0.505, 0.315],
		[0.47, 0.305], [0.44, 0.27], [0.425, 0.225]
	], Color("587f63"))
	_draw_continent([
		[0.485, 0.305], [0.535, 0.30], [0.58, 0.325], [0.615, 0.365],
		[0.64, 0.43], [0.64, 0.50], [0.625, 0.585], [0.60, 0.67],
		[0.575, 0.75], [0.545, 0.835], [0.51, 0.79], [0.485, 0.70],
		[0.47, 0.61], [0.455, 0.52], [0.46, 0.425]
	], Color("547b61"))
	_draw_continent([
		[0.595, 0.175], [0.65, 0.145], [0.71, 0.125], [0.78, 0.115],
		[0.845, 0.125], [0.90, 0.155], [0.94, 0.19], [0.955, 0.245],
		[0.95, 0.305], [0.925, 0.355], [0.91, 0.405], [0.875, 0.435],
		[0.835, 0.47], [0.79, 0.485], [0.745, 0.46], [0.705, 0.445],
		[0.665, 0.39], [0.635, 0.34], [0.615, 0.285]
	], Color("527961"))
	_draw_continent([
		[0.785, 0.61], [0.825, 0.59], [0.875, 0.585], [0.92, 0.615],
		[0.95, 0.66], [0.96, 0.72], [0.955, 0.775], [0.925, 0.825],
		[0.88, 0.85], [0.835, 0.84], [0.80, 0.79], [0.78, 0.73]
	], Color("557c62"))


func _draw_geography_details() -> void:
	var island_fill := Color("5a8165")
	_draw_island([
		[0.285, 0.045], [0.33, 0.035], [0.35, 0.075], [0.325, 0.12],
		[0.285, 0.105], [0.27, 0.07]
	], island_fill) # Greenland
	_draw_island([
		[0.435, 0.175], [0.45, 0.16], [0.46, 0.19], [0.45, 0.235],
		[0.435, 0.22]
	], Color("5f876a")) # United Kingdom
	_draw_island([
		[0.405, 0.115], [0.417, 0.105], [0.428, 0.116], [0.417, 0.128]
	], island_fill) # Iceland
	_draw_island([
		[0.898, 0.275], [0.91, 0.29], [0.905, 0.335], [0.895, 0.355],
		[0.888, 0.325]
	], Color("5a8165")) # Japan
	_draw_island([
		[0.80, 0.515], [0.83, 0.51], [0.845, 0.525], [0.825, 0.54]
	], island_fill) # Sumatra / Java cluster
	_draw_island([
		[0.85, 0.50], [0.87, 0.49], [0.88, 0.52], [0.865, 0.55]
	], island_fill) # Borneo cluster
	_draw_island([
		[0.87, 0.44], [0.882, 0.43], [0.89, 0.46], [0.88, 0.485]
	], island_fill) # Philippines
	_draw_island([
		[0.605, 0.645], [0.62, 0.66], [0.618, 0.72], [0.605, 0.75],
		[0.596, 0.70]
	], island_fill) # Madagascar
	_draw_island([
		[0.945, 0.72], [0.962, 0.735], [0.968, 0.78], [0.955, 0.805],
		[0.945, 0.775]
	], Color("5c8368")) # New Zealand north
	_draw_island([
		[0.955, 0.81], [0.97, 0.825], [0.968, 0.86], [0.955, 0.875],
		[0.948, 0.845]
	], Color("5c8368")) # New Zealand south
	_draw_island([
		[0.235, 0.39], [0.25, 0.385], [0.26, 0.40], [0.245, 0.41]
	], Color("547b61")) # Caribbean
	_draw_island([
		[0.735, 0.46], [0.745, 0.47], [0.742, 0.49], [0.733, 0.485]
	], Color("587f63")) # Sri Lanka

	_draw_lake(Vector2(0.245, 0.255), 5.0)
	_draw_lake(Vector2(0.265, 0.27), 4.0)
	_draw_lake(Vector2(0.58, 0.55), 4.0)
	_draw_lake(Vector2(0.66, 0.31), 5.0)


func _draw_island(points: Array, fill: Color) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(
			_map_to_screen(Vector2(float(point[0]), float(point[1])))
		)
	if polygon.size() < 3:
		return
	var shadow := PackedVector2Array()
	for point in polygon:
		shadow.append(point + Vector2(1.5, 2.0))
	draw_colored_polygon(shadow, Color(0.01, 0.06, 0.08, 0.20))
	draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color(0.50, 0.68, 0.55, 0.72), 1.0, true)


func _draw_lake(map_position: Vector2, base_radius: float) -> void:
	var position := _map_to_screen(map_position)
	if not _is_screen_visible(position, 12.0):
		return
	draw_circle(
		position,
		base_radius * clampf(zoom_level, 1.0, 1.8),
		Color(0.055, 0.20, 0.27, 0.85)
	)


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
		draw_polyline(
			outline,
			Color(0.53, 0.73, 0.60, 0.22),
			3.5,
			true
		)
		draw_polyline(outline, LAND_EDGE, 1.4, true)


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


func network_connection_count() -> int:
	var count := 0
	for country_code in route_country_codes.keys():
		if String(country_code) != home_country_code:
			count += 1
	return count


func airport_labels_visible() -> bool:
	return zoom_level >= AIRPORT_LABEL_ZOOM


func _draw_route_network(home_position: Vector2) -> void:
	for country_code_value in route_country_codes.keys():
		var country_code := String(country_code_value)
		if country_code == home_country_code:
			continue
		if country_code == selected_country_code:
			continue

		var country := CountryCatalog.get_country(country_code)
		if country.is_empty():
			continue
		var target := _country_position(country)
		if not _is_screen_visible(target, 80.0):
			continue

		var unlocked := unlocked_route_country_codes.has(country_code)
		var points := _route_points(home_position, target, 25)
		if unlocked:
			draw_polyline(
				points,
				Color(0.38, 0.77, 0.88, 0.30),
				NETWORK_ROUTE_WIDTH,
				true
			)
		else:
			for index in range(points.size() - 1):
				if index % 3 != 2:
					draw_line(
						points[index],
						points[index + 1],
						Color(0.56, 0.64, 0.68, 0.22),
						1.0,
						true
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
	_draw_route_badge(from_position, to_position)


func _draw_route_badge(
	from_position: Vector2,
	to_position: Vector2
) -> void:
	if route_preview.is_empty():
		return

	var position := _quadratic_route_point(
		from_position,
		to_position,
		0.50
	) + Vector2(0, 18)
	var badge_size := Vector2(184, 46)
	var badge_position := position - badge_size * 0.5
	badge_position.x = clampf(
		badge_position.x,
		8.0,
		maxf(8.0, size.x - badge_size.x - 8.0)
	)
	badge_position.y = clampf(
		badge_position.y,
		56.0,
		maxf(56.0, size.y - badge_size.y - 42.0)
	)
	var rect := Rect2(badge_position, badge_size)

	var status := String(route_preview.get("status", "READY"))
	var border := Color("65d7ef")
	var accent := Color("bceffa")
	if status.begins_with("LOCKED"):
		border = Color("9caab1")
		accent = Color("bdc6ca")
	elif status == "OUT OF RANGE":
		border = Color("d97768")
		accent = Color("f1b2a7")
	elif status == "AIRCRAFT BUSY":
		border = Color("c58fe4")
		accent = Color("e4c5f3")
	elif status == "WAITING PAX":
		border = Color("d9ad55")
		accent = Color("f1d794")
	elif status == "READY":
		border = Color("72d38d")
		accent = Color("bcebc8")

	draw_rect(rect.grow(2.0), Color(0.01, 0.07, 0.10, 0.76), true)
	draw_rect(rect, Color(0.035, 0.15, 0.20, 0.95), true)
	draw_rect(rect, border, false, 1.5)

	var city := String(route_preview.get("city", "Route")).to_upper()
	var distance := int(route_preview.get("distance_km", 0))
	var duration := String(route_preview.get("duration_text", "—"))
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(10, 17),
		"%s  •  %d KM" % [city, distance],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("e8f6f8")
	)
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(10, 35),
		"%s  •  %s" % [duration, status],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		accent
	)


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
		draw_circle(
			position,
			SELECTED_HALO_RADIUS,
			Color(0.95, 0.78, 0.32, 0.10)
		)
		draw_circle(
			position,
			SELECTED_HALO_RADIUS - 4.0,
			Color(0.95, 0.78, 0.32, 0.26),
			false,
			2.0
		)
		draw_circle(
			position,
			SELECTED_HALO_RADIUS - 9.0,
			Color("fff0b3"),
			false,
			2.0
		)
		_draw_selection_brackets(position)

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


func _draw_selection_brackets(position: Vector2) -> void:
	var offset := SELECTED_HALO_RADIUS + 3.0
	var arm := 6.0
	var color := Color(1.0, 0.91, 0.60, 0.86)
	var width := 2.0
	for direction in [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(1, 1),
		Vector2(-1, 1)
	]:
		var corner := position + Vector2(
			direction.x * offset,
			direction.y * offset
		)
		draw_line(
			corner,
			corner + Vector2(-direction.x * arm, 0),
			color,
			width
		)
		draw_line(
			corner,
			corner + Vector2(0, -direction.y * arm),
			color,
			width
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

	if selected or airport_labels_visible():
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
		Rect2(Vector2(8, y - 12), Vector2(300, 24)),
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
	draw_string(
		ThemeDB.fallback_font,
		Vector2(218, y + 4),
		"Network %d" % network_connection_count(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("9ed8e5")
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


func country_display_position(country_code: String) -> Vector2:
	var country := CountryCatalog.get_country(country_code)
	if country.is_empty():
		return Vector2(-1, -1)
	return _country_position(country)


func _country_position(country: Dictionary) -> Vector2:
	var country_code := String(country.get("id", ""))
	return _map_to_screen(Vector2(
		float(country.get("map_x", 0.5)),
		float(country.get("map_y", 0.5))
	)) + _marker_offset(country_code)


func _marker_offset(country_code: String) -> Vector2:
	# Dense European markers get presentation-only offsets so adjacent
	# countries stay individually tappable at world view.
	match country_code:
		"NL":
			return Vector2(-4, -15)
		"BE":
			return Vector2(-14, 8)
		"DE":
			return Vector2(14, -8)
		"DK":
			return Vector2(10, -17)
		"GB":
			return Vector2(-12, -8)
		"FR":
			return Vector2(-10, 15)
		"ES":
			return Vector2(-14, 13)
		"IT":
			return Vector2(15, 16)
		"TR":
			return Vector2(14, 9)
		_:
			return Vector2.ZERO


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


func country_at_position(local_position: Vector2) -> String:
	return _country_at(local_position)


func _country_at(local_position: Vector2) -> String:
	var closest_code := ""
	var closest_distance := COUNTRY_HIT_RADIUS
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
