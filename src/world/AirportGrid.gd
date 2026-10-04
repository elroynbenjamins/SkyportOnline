class_name AirportGrid
extends Node2D

signal parcel_selected(parcel_id: String, data: Dictionary)

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const PARCEL_SIZE := 8
const PARCEL_COLUMNS := 3
const PARCEL_ROWS := 3

const OWNED_A := Color("5e965f")
const OWNED_B := Color("579059")
const LOCKED_A := Color("384c45")
const LOCKED_B := Color("334640")
const GRID_LINE := Color("8fbc86", 0.32)
const LOCKED_GRID_LINE := Color("84958d", 0.22)
const SELECTED_LINE := Color("ffd166")
const RUNWAY := Color("323a40")
const RUNWAY_EDGE := Color("e7e9e8")
const APRON := Color("747f85")
const TERMINAL := Color("bdc4c6")
const FUEL := Color("c59c45")

var parcels: Dictionary = {}
var selected_id := ""
var parcel_labels: Dictionary = {}


func _ready() -> void:
	_initialize_parcels()
	_create_parcel_labels()
	queue_redraw()


func _initialize_parcels() -> void:
	_add_parcel("north_west", 0, 0, 35, 2000000, false)
	_add_parcel("north", 1, 0, 5, 25000, false)
	_add_parcel("north_east", 2, 0, 30, 1200000, false)
	_add_parcel("west", 0, 1, 12, 120000, false)
	_add_parcel("home", 1, 1, 1, 0, true)
	_add_parcel("east", 2, 1, 8, 50000, false)
	_add_parcel("south_west", 0, 2, 25, 800000, false)
	_add_parcel("south", 1, 2, 16, 250000, false)
	_add_parcel("south_east", 2, 2, 20, 500000, false)


func _add_parcel(id: String, px: int, py: int, level: int, cost: int, owned: bool) -> void:
	parcels[id] = {
		"id": id,
		"px": px,
		"py": py,
		"level": level,
		"cost": cost,
		"owned": owned
	}


func _draw() -> void:
	draw_rect(Rect2(-1800, -700, 3600, 2600), Color("203c3d"))

	for py in range(PARCEL_ROWS):
		for px in range(PARCEL_COLUMNS):
			var parcel := _parcel_at(px, py)
			if parcel.is_empty():
				continue
			_draw_parcel_tiles(parcel)

	_draw_starter_airport()
	_draw_selected_outline()


func _draw_parcel_tiles(parcel: Dictionary) -> void:
	var start_x: int = int(parcel["px"]) * PARCEL_SIZE
	var start_y: int = int(parcel["py"]) * PARCEL_SIZE
	var owned: bool = bool(parcel["owned"])

	for y in range(start_y, start_y + PARCEL_SIZE):
		for x in range(start_x, start_x + PARCEL_SIZE):
			var center := tile_to_world(Vector2(x, y))
			var points := _tile_points(center)
			var checker := (x + y) % 2 == 0
			var fill := OWNED_A if checker else OWNED_B
			var line := GRID_LINE
			if not owned:
				fill = LOCKED_A if checker else LOCKED_B
				line = LOCKED_GRID_LINE
			draw_colored_polygon(points, fill)
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), line, 1.0)


func _draw_starter_airport() -> void:
	# Temporary code-drawn airport markers. These are deliberately simple and
	# will be replaced with the proper Skyport pixel-art building pack.
	var home := parcels["home"]
	if not home["owned"]:
		return

	for x in range(8, 16):
		for y in range(10, 12):
			_draw_tile_overlay(x, y, RUNWAY)

	var runway_start := tile_to_world(Vector2(8, 10.5))
	var runway_end := tile_to_world(Vector2(15, 10.5))
	draw_line(runway_start, runway_end, RUNWAY_EDGE, 3.0)

	for x in range(9, 12):
		for y in range(13, 15):
			_draw_tile_overlay(x, y, APRON)

	for x in range(9, 11):
		_draw_tile_overlay(x, 15, TERMINAL)

	_draw_tile_overlay(13, 14, FUEL)
	_draw_tile_overlay(14, 14, FUEL)


func _draw_tile_overlay(x: int, y: int, color: Color) -> void:
	var center := tile_to_world(Vector2(x, y))
	var points := _tile_points(center)
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("d7e0de", 0.3), 1.0)


func _draw_selected_outline() -> void:
	if selected_id.is_empty() or not parcels.has(selected_id):
		return

	var parcel: Dictionary = parcels[selected_id]
	var sx := int(parcel["px"]) * PARCEL_SIZE
	var sy := int(parcel["py"]) * PARCEL_SIZE

	for y in range(sy, sy + PARCEL_SIZE):
		for x in range(sx, sx + PARCEL_SIZE):
			if x == sx or x == sx + PARCEL_SIZE - 1 or y == sy or y == sy + PARCEL_SIZE - 1:
				var p := _tile_points(tile_to_world(Vector2(x, y)))
				draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[3], p[0]]), SELECTED_LINE, 2.5)


func _tile_points(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -TILE_HEIGHT * 0.5),
		center + Vector2(TILE_WIDTH * 0.5, 0),
		center + Vector2(0, TILE_HEIGHT * 0.5),
		center + Vector2(-TILE_WIDTH * 0.5, 0)
	])


func tile_to_world(tile: Vector2) -> Vector2:
	return Vector2(
		(tile.x - tile.y) * TILE_WIDTH * 0.5,
		(tile.x + tile.y) * TILE_HEIGHT * 0.5
	)


func world_to_tile(world_position: Vector2) -> Vector2i:
	var tx := world_position.x / TILE_WIDTH + world_position.y / TILE_HEIGHT
	var ty := world_position.y / TILE_HEIGHT - world_position.x / TILE_WIDTH
	return Vector2i(floori(tx), floori(ty))


func select_world_position(world_position: Vector2) -> void:
	var tile := world_to_tile(world_position)
	if tile.x < 0 or tile.y < 0:
		return
	if tile.x >= PARCEL_COLUMNS * PARCEL_SIZE or tile.y >= PARCEL_ROWS * PARCEL_SIZE:
		return

	var px := tile.x / PARCEL_SIZE
	var py := tile.y / PARCEL_SIZE
	var parcel := _parcel_at(px, py)
	if not parcel.is_empty():
		select_parcel(String(parcel["id"]))


func select_parcel(parcel_id: String) -> void:
	if not parcels.has(parcel_id):
		return
	selected_id = parcel_id
	queue_redraw()
	parcel_selected.emit(parcel_id, parcels[parcel_id].duplicate(true))


func get_selected_parcel() -> Dictionary:
	if selected_id.is_empty() or not parcels.has(selected_id):
		return {}
	return parcels[selected_id].duplicate(true)


func purchase_selected() -> void:
	if selected_id.is_empty() or not parcels.has(selected_id):
		return
	if parcels[selected_id]["owned"]:
		return

	parcels[selected_id]["owned"] = true
	_update_parcel_label(selected_id)
	queue_redraw()
	parcel_selected.emit(selected_id, parcels[selected_id].duplicate(true))


func _parcel_at(px: int, py: int) -> Dictionary:
	for parcel in parcels.values():
		if int(parcel["px"]) == px and int(parcel["py"]) == py:
			return parcel
	return {}


func _create_parcel_labels() -> void:
	for id in parcels.keys():
		var parcel: Dictionary = parcels[id]
		var label := Label.new()
		label.name = "Parcel_%s" % id
		label.size = Vector2(190, 70)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("f5f7f6"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)

		var center_tile := Vector2(
			int(parcel["px"]) * PARCEL_SIZE + (PARCEL_SIZE - 1) * 0.5,
			int(parcel["py"]) * PARCEL_SIZE + (PARCEL_SIZE - 1) * 0.5
		)
		label.position = tile_to_world(center_tile) - label.size * 0.5 + Vector2(0, -18)
		add_child(label)
		parcel_labels[id] = label
		_update_parcel_label(id)


func _update_parcel_label(id: String) -> void:
	if not parcel_labels.has(id):
		return

	var parcel: Dictionary = parcels[id]
	var label: Label = parcel_labels[id]
	if parcel["owned"]:
		label.text = "OWNED"
		if id == "home":
			label.text = "YOUR AIRPORT"
	else:
		label.text = "🔒  Lv %d\n%,d coins" % [int(parcel["level"]), int(parcel["cost"])]
