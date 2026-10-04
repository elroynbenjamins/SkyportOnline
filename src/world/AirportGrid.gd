class_name AirportGrid
extends Node2D

signal parcel_selected(parcel_id: String, data: Dictionary)
signal build_preview_changed(data: Dictionary)
signal building_placed(data: Dictionary)
signal network_status_changed(data: Dictionary)

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
const PREVIEW_VALID := Color("68d391", 0.62)
const PREVIEW_INVALID := Color("ef6461", 0.68)
const AIRSIDE_WARNING := Color("ffb84d")
const AIRSIDE_CONNECTED := Color("76d39b")

var parcels: Dictionary = {}
var selected_id := ""
var parcel_labels: Dictionary = {}

var placed_buildings: Array[Dictionary] = []
var occupied_cells: Dictionary = {}
var next_building_uid := 1
var building_labels: Array[Label] = []
var building_textures: Dictionary = {}
var airside_status: Dictionary = {}

var preview_building_id := ""
var preview_origin := Vector2i(-1, -1)
var preview_rotation := 0
var preview_status: Dictionary = {}


func _ready() -> void:
	_initialize_parcels()
	_initialize_starter_airport()
	_recalculate_airside_network()
	_create_parcel_labels()
	_refresh_building_labels()
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


func _initialize_starter_airport() -> void:
	_place_building_internal("short_runway", Vector2i(8, 8), 0)
	_place_building_internal("taxiway", Vector2i(11, 10), 0)
	_place_building_internal("taxiway", Vector2i(12, 10), 0)
	_place_building_internal("small_stand", Vector2i(11, 11), 0)
	_place_building_internal("small_terminal", Vector2i(8, 13), 0)
	_place_building_internal("basic_fuel", Vector2i(13, 13), 0)
	_rebuild_occupied_cells()


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

	_draw_buildings()
	_draw_airside_warnings()
	_draw_build_preview()
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


func _draw_buildings() -> void:
	var buildings_to_draw: Array[Dictionary] = placed_buildings.duplicate(true)
	buildings_to_draw.sort_custom(Callable(self, "_sort_buildings_by_depth"))

	for building in buildings_to_draw:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty():
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var origin: Vector2i = building["origin"]
		var color: Color = definition["color"]
		if not String(definition.get("world_sprite_path", "")).is_empty():
			color.a = 0.72

		for y in range(footprint.y):
			for x in range(footprint.x):
				_draw_tile_overlay(origin + Vector2i(x, y), color, Color("eef2f1", 0.30), 1.0)

		if String(definition.get("world_sprite_path", "")).is_empty():
			_draw_building_detail(building, definition, footprint)
		else:
			_draw_building_sprite(definition, origin, footprint)


func _sort_buildings_by_depth(a: Dictionary, b: Dictionary) -> bool:
	var a_origin: Vector2i = a["origin"]
	var b_origin: Vector2i = b["origin"]
	return a_origin.x + a_origin.y < b_origin.x + b_origin.y


func _draw_building_detail(building: Dictionary, definition: Dictionary, footprint: Vector2i) -> void:
	var origin: Vector2i = building["origin"]
	var id := String(definition["id"])

	if id.contains("runway"):
		var start := tile_to_world(Vector2(origin.x, origin.y) + Vector2(0.1, float(footprint.y - 1) * 0.5))
		var finish := tile_to_world(Vector2(origin.x + footprint.x - 1, origin.y) + Vector2(-0.1, float(footprint.y - 1) * 0.5))
		if footprint.y > footprint.x:
			start = tile_to_world(Vector2(origin.x, origin.y) + Vector2(float(footprint.x - 1) * 0.5, 0.1))
			finish = tile_to_world(Vector2(origin.x, origin.y + footprint.y - 1) + Vector2(float(footprint.x - 1) * 0.5, -0.1))
		draw_dashed_line(start, finish, Color("f4f2df"), 2.0, 8.0)

	elif id == "taxiway":
		var center := tile_to_world(Vector2(origin.x, origin.y))
		draw_circle(center, 4.0, Color("f0c94c"))

	elif id.contains("fuel"):
		var center := _footprint_center_world(origin, footprint)
		draw_circle(center + Vector2(-10, 0), 8.0, Color("f4e4b0"))
		draw_circle(center + Vector2(10, 0), 8.0, Color("f4e4b0"))

	elif id.contains("stand"):
		var center := _footprint_center_world(origin, footprint)
		draw_circle(center, 10.0, Color("dce5e7"), false, 3.0)


func _draw_building_sprite(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i,
	modulate: Color = Color.WHITE
) -> void:
	var sprite_path := String(definition.get("world_sprite_path", ""))
	if sprite_path.is_empty():
		return

	var texture := _get_building_texture(sprite_path)
	if texture == null:
		return

	var draw_size: Vector2 = definition.get("world_sprite_size", Vector2(160, 120))
	var offset: Vector2 = definition.get("world_sprite_offset", Vector2.ZERO)
	var center := _footprint_center_world(origin, footprint)
	var rect := Rect2(center - draw_size * 0.5 + offset, draw_size)
	draw_texture_rect(texture, rect, false, modulate)


func _get_building_texture(path: String) -> Texture2D:
	if building_textures.has(path):
		return building_textures[path] as Texture2D

	var resource := load(path)
	if resource is Texture2D:
		building_textures[path] = resource
		return resource as Texture2D
	return null


func _draw_build_preview() -> void:
	if preview_building_id.is_empty() or preview_origin.x < 0 or preview_origin.y < 0:
		return

	var definition := BuildingCatalog.get_definition(preview_building_id)
	if definition.is_empty():
		return

	var footprint := _footprint_for(definition, preview_rotation)
	var valid: bool = bool(preview_status.get("valid", false))
	var fill := PREVIEW_VALID if valid else PREVIEW_INVALID

	for y in range(footprint.y):
		for x in range(footprint.x):
			_draw_tile_overlay(preview_origin + Vector2i(x, y), fill, Color("ffffff", 0.75), 2.0)

	if not String(definition.get("world_sprite_path", "")).is_empty():
		var ghost := Color(0.72, 1.0, 0.78, 0.72) if valid else Color(1.0, 0.65, 0.65, 0.72)
		_draw_building_sprite(definition, preview_origin, footprint, ghost)


func _draw_tile_overlay(tile: Vector2i, color: Color, line_color: Color, width: float) -> void:
	var center := tile_to_world(Vector2(tile.x, tile.y))
	var points := _tile_points(center)
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), line_color, width)


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
	if not _tile_in_world(tile):
		return

	var parcel := _parcel_for_tile(tile)
	if not parcel.is_empty():
		select_parcel(String(parcel["id"]))


func select_parcel(parcel_id: String) -> void:
	if not parcels.has(parcel_id):
		return
	selected_id = parcel_id
	queue_redraw()
	parcel_selected.emit(parcel_id, parcels[parcel_id].duplicate(true))


func clear_parcel_selection() -> void:
	selected_id = ""
	queue_redraw()


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


func set_build_preview(building_id: String, world_position: Vector2, rotation: int) -> Dictionary:
	preview_building_id = building_id
	preview_origin = world_to_tile(world_position)
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(building_id, preview_origin, preview_rotation)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func refresh_build_preview(rotation: int) -> Dictionary:
	if preview_building_id.is_empty():
		return {}
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(preview_building_id, preview_origin, preview_rotation)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func get_build_preview_status() -> Dictionary:
	return preview_status.duplicate(true)


func has_build_preview() -> bool:
	return not preview_building_id.is_empty() and preview_origin.x >= 0 and preview_origin.y >= 0


func clear_build_preview() -> void:
	preview_building_id = ""
	preview_origin = Vector2i(-1, -1)
	preview_rotation = 0
	preview_status = {}
	queue_redraw()


func confirm_build_preview() -> Dictionary:
	if not bool(preview_status.get("valid", false)):
		return {}

	var placed := _place_building_internal(preview_building_id, preview_origin, preview_rotation)
	_rebuild_occupied_cells()
	_recalculate_airside_network()
	_refresh_building_labels()
	clear_build_preview()
	queue_redraw()
	building_placed.emit(placed.duplicate(true))
	return placed


func _get_placement_status(building_id: String, origin: Vector2i, rotation: int) -> Dictionary:
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return {
			"valid": false,
			"reason": "Unknown building."
		}

	var footprint := _footprint_for(definition, rotation)
	var cells := _cells_for(origin, footprint)

	for cell in cells:
		if not _tile_in_world(cell):
			return {
				"valid": false,
				"reason": "Outside the airport map.",
				"origin": origin,
				"footprint": footprint
			}
		if not _is_tile_owned(cell):
			return {
				"valid": false,
				"reason": "This land parcel is still locked.",
				"origin": origin,
				"footprint": footprint
			}
		if occupied_cells.has(_cell_key(cell)):
			return {
				"valid": false,
				"reason": "Another airport building already occupies this space.",
				"origin": origin,
				"footprint": footprint
			}

	var result := {
		"valid": true,
		"reason": "Ready to build.",
		"origin": origin,
		"footprint": footprint
	}

	if _needs_airside_connection(definition):
		var preview_cells := _cells_for(origin, footprint)
		if not _cells_touch_reachable_taxiway(preview_cells):
			result["warning"] = "No taxiway connection to a runway yet."

	return result


func _footprint_for(definition: Dictionary, rotation: int) -> Vector2i:
	var base: Vector2i = definition["footprint"]
	if bool(definition.get("rotatable", false)) and rotation % 2 == 1:
		return Vector2i(base.y, base.x)
	return base


func _cells_for(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			cells.append(origin + Vector2i(x, y))
	return cells


func _place_building_internal(definition_id: String, origin: Vector2i, rotation: int) -> Dictionary:
	var placed := {
		"uid": next_building_uid,
		"definition_id": definition_id,
		"origin": origin,
		"rotation": rotation % 2
	}
	next_building_uid += 1
	placed_buildings.append(placed)
	return placed


func _rebuild_occupied_cells() -> void:
	occupied_cells.clear()
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty():
			continue
		var footprint := _footprint_for(definition, int(building["rotation"]))
		var origin: Vector2i = building["origin"]
		for cell in _cells_for(origin, footprint):
			occupied_cells[_cell_key(cell)] = int(building["uid"])


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _tile_in_world(tile: Vector2i) -> bool:
	return (
		tile.x >= 0
		and tile.y >= 0
		and tile.x < PARCEL_COLUMNS * PARCEL_SIZE
		and tile.y < PARCEL_ROWS * PARCEL_SIZE
	)


func _is_tile_owned(tile: Vector2i) -> bool:
	var parcel := _parcel_for_tile(tile)
	return not parcel.is_empty() and bool(parcel["owned"])


func _parcel_for_tile(tile: Vector2i) -> Dictionary:
	if not _tile_in_world(tile):
		return {}
	var px := floori(float(tile.x) / float(PARCEL_SIZE))
	var py := floori(float(tile.y) / float(PARCEL_SIZE))
	return _parcel_at(px, py)


func _parcel_at(px: int, py: int) -> Dictionary:
	for parcel in parcels.values():
		if int(parcel["px"]) == px and int(parcel["py"]) == py:
			return parcel
	return {}


func _footprint_center_world(origin: Vector2i, footprint: Vector2i) -> Vector2:
	var center_tile := Vector2(
		float(origin.x) + float(footprint.x - 1) * 0.5,
		float(origin.y) + float(footprint.y - 1) * 0.5
	)
	return tile_to_world(center_tile)


func _create_parcel_labels() -> void:
	for id in parcels.keys():
		var parcel: Dictionary = parcels[id]
		var label := Label.new()
		label.name = "Parcel_%s" % id
		label.size = Vector2(190, 70)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		label.text = "🔒  Lv %d\n%s coins" % [int(parcel["level"]), _format_number(int(parcel["cost"]))]


func _refresh_building_labels() -> void:
	for label in building_labels:
		if is_instance_valid(label):
			label.queue_free()
	building_labels.clear()

	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty() or String(definition["id"]) == "taxiway":
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(150, 34)
		label.position = _footprint_center_world(building["origin"], footprint) - Vector2(75, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("f8faf9"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.text = _building_label_text(building, definition)
		add_child(label)
		building_labels.append(label)


func _building_label_text(building: Dictionary, definition: Dictionary) -> String:
	var id := String(definition["id"])
	if id.contains("runway"):
		return "RUNWAY  •  " + _size_text(definition)
	if id.contains("fuel"):
		return "FUEL  •  " + _size_text(definition)
	if id.contains("stand"):
		if not _is_airside_building_connected(int(building["uid"])):
			return "STAND  •  " + _size_text(definition) + "  ⚠ TAXIWAY"
		return "STAND  •  " + _size_text(definition) + "  ✓"
	if id.contains("terminal"):
		return "TERMINAL"
	if id.contains("hangar"):
		if not _is_airside_building_connected(int(building["uid"])):
			return "HANGAR  •  " + _size_text(definition) + "  ⚠ TAXIWAY"
		return "HANGAR  •  " + _size_text(definition) + "  ✓"
	return String(definition["name"]).to_upper()


func _size_text(definition: Dictionary) -> String:
	var sizes: PackedStringArray = definition["sizes"]
	var result := ""
	for index in range(sizes.size()):
		if index > 0:
			result += "/"
		result += sizes[index]
	return result



func get_airside_status() -> Dictionary:
	return airside_status.duplicate(true)


func _needs_airside_connection(definition: Dictionary) -> bool:
	var id := String(definition.get("id", ""))
	return id.contains("stand") or id.contains("hangar")


func _is_taxiway_definition(definition: Dictionary) -> bool:
	return String(definition.get("id", "")) == "taxiway"


func _is_runway_definition(definition: Dictionary) -> bool:
	return String(definition.get("id", "")).contains("runway")


func _is_airside_building_connected(uid: int) -> bool:
	var connected: Array = airside_status.get("connected_uids", [])
	return connected.has(uid)


func _recalculate_airside_network() -> void:
	var taxiway_cells: Dictionary = {}
	var runway_cells: Dictionary = {}
	var airside_buildings: Array[Dictionary] = []

	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty():
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var cells := _cells_for(building["origin"], footprint)

		if _is_taxiway_definition(definition):
			for cell in cells:
				taxiway_cells[_cell_key(cell)] = cell
		elif _is_runway_definition(definition):
			for cell in cells:
				runway_cells[_cell_key(cell)] = cell
		elif _needs_airside_connection(definition):
			airside_buildings.append({
				"uid": int(building["uid"]),
				"definition_id": String(building["definition_id"]),
				"cells": cells
			})

	var reachable_taxiways := _reachable_taxiway_cells(taxiway_cells, runway_cells)
	var connected_uids: Array[int] = []
	var disconnected: Array[Dictionary] = []
	var connected_stands := 0
	var total_stands := 0
	var connected_hangars := 0
	var total_hangars := 0

	for info in airside_buildings:
		var uid := int(info["uid"])
		var definition_id := String(info["definition_id"])
		var connected := _cells_touch_cell_set(info["cells"], reachable_taxiways)

		if definition_id.contains("stand"):
			total_stands += 1
			if connected:
				connected_stands += 1
		elif definition_id.contains("hangar"):
			total_hangars += 1
			if connected:
				connected_hangars += 1

		if connected:
			connected_uids.append(uid)
		else:
			disconnected.append({
				"uid": uid,
				"definition_id": definition_id
			})

	airside_status = {
		"runways": _count_buildings_matching("runway"),
		"taxiways": taxiway_cells.size(),
		"stands_total": total_stands,
		"stands_connected": connected_stands,
		"hangars_total": total_hangars,
		"hangars_connected": connected_hangars,
		"connected_uids": connected_uids,
		"disconnected": disconnected,
		"reachable_taxiway_cells": reachable_taxiways.keys()
	}
	network_status_changed.emit(get_airside_status())
	queue_redraw()


func _reachable_taxiway_cells(taxiway_cells: Dictionary, runway_cells: Dictionary) -> Dictionary:
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = []

	for taxiway_variant in taxiway_cells.values():
		var taxiway: Vector2i = taxiway_variant
		if _cell_touches_cell_set(taxiway, runway_cells):
			reachable[_cell_key(taxiway)] = taxiway
			queue.append(taxiway)

	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1

		for neighbor in _orthogonal_neighbors(current):
			var key := _cell_key(neighbor)
			if taxiway_cells.has(key) and not reachable.has(key):
				reachable[key] = neighbor
				queue.append(neighbor)

	return reachable


func _cells_touch_reachable_taxiway(cells: Array[Vector2i]) -> bool:
	var reachable_keys: Array = airside_status.get("reachable_taxiway_cells", [])
	if reachable_keys.is_empty():
		return false

	var reachable: Dictionary = {}
	for key in reachable_keys:
		reachable[String(key)] = true

	for cell in cells:
		for neighbor in _orthogonal_neighbors(cell):
			if reachable.has(_cell_key(neighbor)):
				return true
	return false


func _cells_touch_cell_set(cells: Array, cell_set: Dictionary) -> bool:
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		if _cell_touches_cell_set(cell, cell_set):
			return true
	return false


func _cell_touches_cell_set(cell: Vector2i, cell_set: Dictionary) -> bool:
	for neighbor in _orthogonal_neighbors(cell):
		if cell_set.has(_cell_key(neighbor)):
			return true
	return false


func _orthogonal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1)
	]


func _count_buildings_matching(fragment: String) -> int:
	var count := 0
	for building in placed_buildings:
		if String(building["definition_id"]).contains(fragment):
			count += 1
	return count


func _draw_airside_warnings() -> void:
	var disconnected: Array = airside_status.get("disconnected", [])
	for info in disconnected:
		var uid := int(info.get("uid", -1))
		var building := _building_by_uid(uid)
		if building.is_empty():
			continue

		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty():
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var center := _footprint_center_world(building["origin"], footprint)
		var marker_center := center + Vector2(0, -54)

		draw_circle(marker_center, 12.0, Color("402f18", 0.92))
		draw_circle(marker_center, 9.0, AIRSIDE_WARNING)
		draw_line(marker_center + Vector2(0, -5), marker_center + Vector2(0, 2), Color("2a2118"), 3.0)
		draw_circle(marker_center + Vector2(0, 6), 1.8, Color("2a2118"))


func _building_by_uid(uid: int) -> Dictionary:
	for building in placed_buildings:
		if int(building["uid"]) == uid:
			return building
	return {}

func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
