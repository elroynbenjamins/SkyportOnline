class_name WorldMapCanvas
extends Control

signal route_selected(route_id: String)

const OCEAN := Color("163845")
const OCEAN_GRID := Color("4c7280", 0.28)
const LAND := Color("456f59")
const LAND_EDGE := Color("7ca184")
const ROUTE_LINE := Color("8bb4c1", 0.55)
const ROUTE_LOCKED := Color("79858a", 0.32)
const HOME_COLOR := Color("f5d76e")

var route_entries: Array[Dictionary] = []
var marker_buttons: Array[Button] = []
var view_mode := "EUROPE"


func _ready() -> void:
	custom_minimum_size = Vector2(700, 430)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout_markers)
	queue_redraw()


func configure(entries: Array[Dictionary]) -> void:
	route_entries.clear()
	for entry in entries:
		route_entries.append(entry.duplicate(true))
	_rebuild_markers()
	queue_redraw()


func set_view_mode(mode: String) -> void:
	if mode not in ["WORLD", "EUROPE"]:
		return
	view_mode = mode
	_layout_markers()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN)

	for index in range(1, 6):
		var x := size.x * float(index) / 6.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), OCEAN_GRID, 1.0)
	for index in range(1, 4):
		var y := size.y * float(index) / 4.0
		draw_line(Vector2(0, y), Vector2(size.x, y), OCEAN_GRID, 1.0)

	if view_mode == "WORLD":
		_draw_world_land()
	else:
		_draw_europe_land()

	var home := CountryCatalog.get_country("NL")
	if not home.is_empty():
		var home_point := _project_country(home)
		draw_circle(home_point, 8.0, HOME_COLOR)
		draw_circle(home_point, 12.0, Color(HOME_COLOR, 0.35), false, 2.0)

	for entry in route_entries:
		var country := CountryCatalog.get_country(
			String(entry.get("country_code", ""))
		)
		if country.is_empty():
			continue
		var destination := _project_country(country)
		var line_color := ROUTE_LINE
		if not bool(entry.get("compatible", false)):
			line_color = ROUTE_LOCKED
		draw_dashed_line(home_point, destination, line_color, 2.0, 7.0)


func _draw_world_land() -> void:
	_draw_geo_polygon([
		Vector2(-168, 72), Vector2(-130, 70), Vector2(-105, 55),
		Vector2(-80, 52), Vector2(-60, 42), Vector2(-82, 20),
		Vector2(-115, 15), Vector2(-140, 35)
	])
	_draw_geo_polygon([
		Vector2(-82, 12), Vector2(-60, 8), Vector2(-48, -10),
		Vector2(-56, -35), Vector2(-70, -55), Vector2(-82, -18)
	])
	_draw_geo_polygon([
		Vector2(-12, 36), Vector2(-12, 60), Vector2(18, 72),
		Vector2(48, 62), Vector2(40, 38), Vector2(18, 34)
	])
	_draw_geo_polygon([
		Vector2(-18, 34), Vector2(18, 36), Vector2(42, 12),
		Vector2(34, -28), Vector2(12, -36), Vector2(-8, -18)
	])
	_draw_geo_polygon([
		Vector2(35, 70), Vector2(85, 72), Vector2(135, 58),
		Vector2(155, 38), Vector2(115, 8), Vector2(78, 12),
		Vector2(42, 32)
	])
	_draw_geo_polygon([
		Vector2(112, -10), Vector2(154, -12), Vector2(154, -39),
		Vector2(120, -44), Vector2(108, -25)
	])


func _draw_europe_land() -> void:
	_draw_geo_polygon([
		Vector2(-12, 36), Vector2(-11, 49), Vector2(-6, 58),
		Vector2(3, 61), Vector2(11, 59), Vector2(18, 61),
		Vector2(28, 57), Vector2(30, 50), Vector2(24, 45),
		Vector2(18, 40), Vector2(12, 37), Vector2(7, 43),
		Vector2(0, 44), Vector2(-5, 40)
	])
	_draw_geo_polygon([
		Vector2(5, 55), Vector2(10, 62), Vector2(18, 70),
		Vector2(29, 69), Vector2(28, 58), Vector2(18, 55)
	])
	_draw_geo_polygon([
		Vector2(-9, 50), Vector2(-7, 58), Vector2(-2, 58),
		Vector2(1, 52), Vector2(-2, 50)
	])


func _draw_geo_polygon(points: Array) -> void:
	var projected := PackedVector2Array()
	for point_variant in points:
		var lon_lat: Vector2 = point_variant
		projected.append(_project(lon_lat.x, lon_lat.y))
	if projected.size() >= 3:
		draw_colored_polygon(projected, LAND)
		var outline := projected.duplicate()
		outline.append(projected[0])
		draw_polyline(outline, LAND_EDGE, 1.5)


func _project_country(country: Dictionary) -> Vector2:
	return _project(
		float(country.get("longitude", 0.0)),
		float(country.get("latitude", 0.0))
	)


func _project(longitude: float, latitude: float) -> Vector2:
	if view_mode == "EUROPE":
		var min_lon := -15.0
		var max_lon := 32.0
		var min_lat := 34.0
		var max_lat := 63.0
		return Vector2(
			((longitude - min_lon) / (max_lon - min_lon)) * size.x,
			((max_lat - latitude) / (max_lat - min_lat)) * size.y
		)

	return Vector2(
		((longitude + 180.0) / 360.0) * size.x,
		((90.0 - latitude) / 180.0) * size.y
	)


func _rebuild_markers() -> void:
	for button in marker_buttons:
		if is_instance_valid(button):
			button.queue_free()
	marker_buttons.clear()

	for entry in route_entries:
		var country := CountryCatalog.get_country(
			String(entry.get("country_code", ""))
		)
		if country.is_empty():
			continue

		var button := Button.new()
		var route_id := String(entry.get("id", ""))
		var locked := not bool(entry.get("compatible", false))
		button.text = "%s%s\n%s" % [
			"🔒 " if locked else "",
			String(entry.get("destination_name", "Destination")),
			String(country.get("code", ""))
		]
		button.custom_minimum_size = Vector2(104, 44)
		button.size = Vector2(104, 44)
		button.add_theme_font_size_override("font_size", 12)
		button.tooltip_text = String(entry.get("reason", "Select destination"))
		button.pressed.connect(
			func() -> void: route_selected.emit(route_id)
		)
		add_child(button)
		marker_buttons.append(button)

	_layout_markers()


func _layout_markers() -> void:
	if marker_buttons.size() != route_entries.size():
		return

	for index in range(marker_buttons.size()):
		var entry := route_entries[index]
		var country := CountryCatalog.get_country(
			String(entry.get("country_code", ""))
		)
		if country.is_empty():
			continue
		var point := _project_country(country)
		var offset := _marker_offset(index, String(country.get("code", "")))
		marker_buttons[index].position = point - Vector2(52, 22) + offset


func _marker_offset(index: int, country_code: String) -> Vector2:
	match country_code:
		"BE":
			return Vector2(-70, 42)
		"DE":
			return Vector2(34, -46)
		"CH":
			return Vector2(42, 34)
		"IT":
			return Vector2(72, 48 + float(index % 2) * 34.0)
		"DK":
			return Vector2(45, -42)
		"CZ":
			return Vector2(76, -12)
		"ES":
			return Vector2(-24, 42)
		"GB":
			return Vector2(-62, -28)
		_:
			return Vector2.ZERO
