class_name AirportGrid
extends Node2D

signal parcel_selected(parcel_id: String, data: Dictionary)
signal build_preview_changed(data: Dictionary)
signal building_placed(data: Dictionary)
signal building_moved(data: Dictionary, previous: Dictionary)
signal building_stored(data: Dictionary)
signal building_restored(data: Dictionary)
signal network_status_changed(data: Dictionary)
signal building_selected_world(data: Dictionary)

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const PARCEL_SIZE := 8
const PARCEL_COLUMNS := 3
const PARCEL_ROWS := 3

const TERRAIN_BACKGROUND := Color("557f4b")
const OWNED_GRASS_VARIANTS := [
	Color("6fa557"),
	Color("73aa5b"),
	Color("69a052"),
	Color("78ad60"),
	Color("65994f"),
	Color("70a85a")
]
const AVAILABLE_GRASS_VARIANTS := [
	Color("747b50"),
	Color("7a8054"),
	Color("70784d"),
	Color("81865a")
]
const LOCKED_GRASS_VARIANTS := [
	Color("3b5046"),
	Color("40564a"),
	Color("384c43"),
	Color("455a4e")
]
const GRID_LINE := Color("d9efc8", 0.025)
const LOCKED_GRID_LINE := Color("97aaa0", 0.11)
const AVAILABLE_GRID_LINE := Color("e4c96d", 0.16)
const TERRAIN_PATCH_LIGHT := Color("9ac875", 0.08)
const TERRAIN_PATCH_DARK := Color("3f773f", 0.08)
const TERRAIN_SOIL := Color("9b825c", 0.10)
const TERRAIN_STONE := Color("d4d0c4", 0.26)
const TERRAIN_FLOWER := Color("f3d66b", 0.72)
const SELECTED_LINE := Color("ffd166")
const SELECTED_BUILDING_LINE := Color("7fd8ff")
const SELECTED_BUILDING_FILL := Color("68bde8", 0.08)
const HOVER_BUILDING_LINE := Color("b9edff", 0.72)
const HOVER_BUILDING_FILL := Color("8bdcff", 0.045)
const PREVIEW_VALID := Color("68d391", 0.38)
const PREVIEW_INVALID := Color("ef6461", 0.46)
const PREVIEW_EXPANSION_LINE := Color("ffd166", 0.95)
const PREVIEW_FUTURE_LINE := Color("7d8b85", 0.88)
const AIRSIDE_WARNING := Color("ffb84d")
const AIRSIDE_CONNECTED := Color("76d39b")
const HOLD_SHORT_SOLID := Color("f5d76e")
const HOLD_SHORT_DASH := Color("fff2a8")
const STOP_BAR_RED := Color("ff4d5a")
const STOP_BAR_AMBER := Color("ffbf47")
const STOP_BAR_OFF := Color("6d5b3f")
const RUNWAY_CLEAR := Color("76d39b")
const RUNWAY_OCCUPIED := Color("ff5d62")
const RUNWAY_PRIORITY := Color("ffbf47")
const TAXIWAY_OUTER := Color("38454b")
const TAXIWAY_INNER := Color("4b575c")
const SERVICE_ROAD_OUTER := Color("6b655e")
const SERVICE_ROAD_INNER := Color("837a70")
const PAVEMENT_HIGHLIGHT := Color("ffffff", 0.16)
const PAVEMENT_SHADOW := Color("182226", 0.24)
const FENCE_COLOR := Color("53656b")
const FENCE_MESH := Color("91a4aa", 0.52)
const PERIMETER_LIGHT := Color("fff0bd")
const ENVIRONMENT_PARKING := "res://assets/pixel/airport_v1/environment_parking_lot.svg"
const ENVIRONMENT_TREES := "res://assets/pixel/airport_v1/environment_tree_cluster.svg"
const ENVIRONMENT_HEDGE := "res://assets/pixel/airport_v1/environment_hedge_strip.svg"
const ENVIRONMENT_ENTRANCE := "res://assets/pixel/airport_v1/environment_entrance_sign.svg"
const ENVIRONMENT_CONIFERS := "res://assets/pixel/airport_v1/environment_conifer_cluster.svg"
const ENVIRONMENT_FIELDS := "res://assets/pixel/airport_v1/environment_distant_fields.svg"
const PARCEL_UNLOCK_FX_DURATION := 0.9
const PREVIEW_SNAP_FX_DURATION := 0.18
const PLACEMENT_CONFIRM_FX_DURATION := 0.46
const EDIT_DIM_MODULATE := Color(0.78, 0.82, 0.80, 0.70)

var parcels: Dictionary = {}
var selected_id := ""
var parcel_labels: Dictionary = {}

var placed_buildings: Array[Dictionary] = []
var stored_buildings: Array[Dictionary] = []
var occupied_cells: Dictionary = {}
var next_building_uid := 1
var building_labels: Array[Label] = []
var building_textures: Dictionary = {}
var building_texture_images: Dictionary = {}
var airside_status: Dictionary = {}
var runway_visual_states: Dictionary = {}
var event_visual_snapshot: Dictionary = {}
var event_owned_cosmetics: Dictionary = {}
var parcel_unlock_fx: Dictionary = {}
var preview_snap_elapsed := -1.0
var preview_snap_origin := Vector2i(-1, -1)
var preview_snap_footprint := Vector2i.ONE
var preview_snap_valid := false
var placement_confirm_fx: Array[Dictionary] = []
var hovered_building_uid := -1

var preview_building_id := ""
var preview_origin := Vector2i(-1, -1)
var preview_rotation := 0
var preview_status: Dictionary = {}
var preview_mode := "build"
var preview_ignore_uid := -1
var preview_stored_uid := -1
var selected_synergy_uid := -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_initialize_parcels()
	_initialize_starter_airport()
	_recalculate_airside_network()
	_create_parcel_labels()
	_refresh_building_labels()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var active := false

	if not parcel_unlock_fx.is_empty():
		active = true
		var completed: Array[String] = []
		for parcel_id_variant in parcel_unlock_fx.keys():
			var parcel_id := String(parcel_id_variant)
			var elapsed := float(
				parcel_unlock_fx.get(parcel_id, 0.0)
			) + delta
			if elapsed >= PARCEL_UNLOCK_FX_DURATION:
				completed.append(parcel_id)
			else:
				parcel_unlock_fx[parcel_id] = elapsed
		for parcel_id in completed:
			parcel_unlock_fx.erase(parcel_id)

	if preview_snap_elapsed >= 0.0:
		active = true
		preview_snap_elapsed += delta
		if preview_snap_elapsed >= PREVIEW_SNAP_FX_DURATION:
			preview_snap_elapsed = -1.0

	if not placement_confirm_fx.is_empty():
		active = true
		for index in range(
			placement_confirm_fx.size() - 1,
			-1,
			-1
		):
			var item: Dictionary = placement_confirm_fx[index]
			var elapsed := float(
				item.get("elapsed", 0.0)
			) + delta
			if elapsed >= PLACEMENT_CONFIRM_FX_DURATION:
				placement_confirm_fx.remove_at(index)
			else:
				item["elapsed"] = elapsed
				placement_confirm_fx[index] = item

	if (
		not parcel_unlock_fx.is_empty()
		or preview_snap_elapsed >= 0.0
		or not placement_confirm_fx.is_empty()
	):
		active = true

	if active:
		queue_redraw()
	else:
		set_process(false)


func _initialize_parcels() -> void:
	for zone in AirportExpansionCatalog.all():
		var zone_id := String(zone.get("id", ""))
		if zone_id.is_empty():
			continue
		_add_parcel(
			zone_id,
			int(zone.get("px", 0)),
			int(zone.get("py", 0)),
			int(zone.get("level", 1)),
			int(zone.get("cost", 0)),
			zone_id == "home"
		)


func _initialize_starter_airport() -> void:
	_place_building_internal("short_runway", Vector2i(8, 8), 0)
	_place_building_internal("taxiway", Vector2i(11, 10), 0)
	_place_building_internal("taxiway", Vector2i(12, 10), 0)
	_place_building_internal("taxiway", Vector2i(13, 10), 0)
	_place_building_internal("small_stand", Vector2i(11, 11), 0)
	_place_building_internal("small_stand", Vector2i(13, 11), 0)
	_place_building_internal("small_terminal", Vector2i(8, 13), 0)
	_place_building_internal("travel_office", Vector2i(8, 10), 0)
	_place_building_internal("ground_ops_depot", Vector2i(11, 14), 0)
	_place_building_internal("basic_fuel", Vector2i(13, 13), 0)
	_place_building_internal("service_road", Vector2i(11, 13), 0)
	_place_building_internal("service_road", Vector2i(12, 13), 0)
	_place_building_internal("service_road", Vector2i(15, 12), 0)
	_place_building_internal("service_road", Vector2i(15, 13), 0)
	_place_building_internal("service_road", Vector2i(12, 14), 0)
	_place_building_internal("service_road", Vector2i(12, 15), 0)
	_place_building_internal("service_road", Vector2i(13, 15), 0)
	_place_building_internal("service_road", Vector2i(14, 15), 0)
	_place_building_internal("service_road", Vector2i(15, 15), 0)
	_place_building_internal("service_road", Vector2i(15, 14), 0)
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
	_draw_world_terrain_background()
	# Landside art is a background layer. Drawing it before parcel terrain
	# guarantees decorative scenery can never cover buildable placement tiles.
	_draw_landside_environment()

	for py in range(PARCEL_ROWS):
		for px in range(PARCEL_COLUMNS):
			var parcel := _parcel_at(px, py)
			if parcel.is_empty():
				continue
			_draw_parcel_tiles(parcel)

	_draw_owned_airport_environment()
	_draw_expansion_boundary_visuals()
	_draw_parcel_unlock_fx()
	_draw_buildings()
	_draw_airside_props()
	_draw_hovered_building_outline()
	_draw_selected_building_outline()
	_draw_synergy_overlay()
	_draw_event_theme_overlay()
	_draw_runway_hold_short_markings()
	_draw_runway_operational_indicators()
	_draw_airside_warnings()
	_draw_build_preview()
	_draw_preview_snap_fx()
	_draw_placement_confirm_fx()
	_draw_preview_expansion_outline()
	_draw_selected_outline()


func _draw_world_terrain_background() -> void:
	draw_rect(
		Rect2(-1800, -700, 3600, 2600),
		TERRAIN_BACKGROUND
	)

	var landscape_patches := [
		[
			Vector2(-920, 220),
			Vector2(1.0, 0.38),
			430.0,
			Color("73a85c", 0.22)
		],
		[
			Vector2(780, 80),
			Vector2(1.0, 0.34),
			520.0,
			Color("477943", 0.17)
		],
		[
			Vector2(-360, 860),
			Vector2(1.0, 0.31),
			620.0,
			Color("7eaa5f", 0.14)
		],
		[
			Vector2(760, 980),
			Vector2(1.0, 0.36),
			520.0,
			Color("4b7742", 0.16)
		],
		[
			Vector2(-1120, 1120),
			Vector2(1.0, 0.42),
			460.0,
			Color("9a865d", 0.08)
		]
	]
	for patch_variant in landscape_patches:
		var patch: Array = patch_variant
		draw_set_transform(
			patch[0],
			0.0,
			patch[1]
		)
		draw_circle(
			Vector2.ZERO,
			float(patch[2]),
			patch[3]
		)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_parcel_tiles(parcel: Dictionary) -> void:
	var start_x: int = int(parcel["px"]) * PARCEL_SIZE
	var start_y: int = int(parcel["py"]) * PARCEL_SIZE
	var owned: bool = bool(parcel["owned"])
	var progression_state := String(
		_parcel_progression_data(
			String(parcel.get("id", ""))
		).get("progression_state", "future")
	)
	var terrain_state := "owned"
	if not owned:
		terrain_state = (
			"available"
			if progression_state == "available"
			else "locked"
		)

	for y in range(start_y, start_y + PARCEL_SIZE):
		for x in range(start_x, start_x + PARCEL_SIZE):
			var tile := Vector2i(x, y)
			var center := tile_to_world(Vector2(x, y))
			var points := _tile_points(center)
			var fill := _terrain_color_for(
				tile,
				terrain_state
			)
			var line := _terrain_line_for_state(
				terrain_state
			)

			draw_colored_polygon(points, fill)
			if line.a > 0.0:
				draw_polyline(
					PackedVector2Array([
						points[0],
						points[1],
						points[2],
						points[3],
						points[0]
					]),
					line,
					1.0
				)
			_draw_terrain_detail(
				tile,
				center,
				terrain_state
			)


func _terrain_hash(
	tile: Vector2i,
	salt: int = 0
) -> int:
	return absi(
		tile.x * 92837111
		+ tile.y * 689287499
		+ salt * 283923481
	)


func _terrain_color_for(
	tile: Vector2i,
	state: String
) -> Color:
	var variants: Array = OWNED_GRASS_VARIANTS
	if state == "available":
		variants = AVAILABLE_GRASS_VARIANTS
	elif state == "locked":
		variants = LOCKED_GRASS_VARIANTS

	var index := (
		_terrain_hash(tile, 7)
		% variants.size()
	)
	return variants[index]


func _terrain_line_for_state(
	state: String
) -> Color:
	match state:
		"available":
			return AVAILABLE_GRID_LINE
		"locked":
			return LOCKED_GRID_LINE
		_:
			return GRID_LINE


func _draw_terrain_detail(
	tile: Vector2i,
	center: Vector2,
	state: String
) -> void:
	var seed := _terrain_hash(tile, 19)
	var patch_kind := seed % 13

	if state == "owned":
		if patch_kind in [1, 7]:
			_draw_terrain_soft_patch(
				center
				+ Vector2(
					float((seed % 19) - 9),
					float((int(seed / 7) % 9) - 4)
				),
				10.0 + float(seed % 6),
				TERRAIN_PATCH_LIGHT
				if patch_kind == 1
				else TERRAIN_PATCH_DARK
			)
		elif patch_kind == 10:
			_draw_terrain_soft_patch(
				center + Vector2(-5, 2),
				8.0,
				TERRAIN_SOIL
			)
	elif state == "available":
		if patch_kind in [3, 8, 11]:
			_draw_terrain_soft_patch(
				center
				+ Vector2(
					float((seed % 15) - 7),
					float((int(seed / 5) % 7) - 3)
				),
				9.0 + float(seed % 5),
				Color("b59a62", 0.10)
			)
	else:
		if patch_kind in [2, 5, 9]:
			_draw_terrain_soft_patch(
				center
				+ Vector2(
					float((seed % 13) - 6),
					float((int(seed / 11) % 7) - 3)
				),
				8.0 + float(seed % 5),
				Color("243c36", 0.12)
			)

	var tuft_count := 1
	if state == "owned" and seed % 5 == 0:
		tuft_count = 2
	elif state == "locked" and seed % 4 == 0:
		tuft_count = 2

	for index in range(tuft_count):
		var local_seed := _terrain_hash(
			tile,
			31 + index * 17
		)
		var tuft := center + Vector2(
			float((local_seed % 25) - 12),
			float((int(local_seed / 7) % 13) - 6)
		)
		var light := Color("c8e7a9", 0.26)
		var dark := Color("416f3c", 0.30)
		if state == "available":
			light = Color("d5c58c", 0.24)
			dark = Color("625f3f", 0.28)
		elif state == "locked":
			light = Color("82998a", 0.18)
			dark = Color("263f36", 0.30)

		draw_line(
			tuft + Vector2(-2.0, 2.0),
			tuft + Vector2(0.0, -2.5),
			light,
			1.0
		)
		draw_line(
			tuft + Vector2(2.0, 2.0),
			tuft + Vector2(0.0, -2.5),
			dark,
			1.0
		)

	if state == "owned" and seed % 29 == 0:
		draw_circle(
			center + Vector2(9, -2),
			1.5,
			TERRAIN_FLOWER
		)
		draw_circle(
			center + Vector2(7, -1),
			1.0,
			Color("f5f0d6", 0.72)
		)
	elif seed % 23 == 0:
		draw_circle(
			center + Vector2(-10, 3),
			2.2,
			Color(0.10, 0.13, 0.10, 0.10)
		)
		draw_circle(
			center + Vector2(-10, 2),
			1.6,
			TERRAIN_STONE
		)


func _draw_terrain_soft_patch(
	position: Vector2,
	radius: float,
	color: Color
) -> void:
	draw_set_transform(
		position,
		0.0,
		Vector2(1.0, 0.42)
	)
	draw_circle(
		Vector2.ZERO,
		radius,
		color
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)



func get_landside_scenery_layout() -> Array[Dictionary]:
	return [
		{
			"id": "parking_west",
			"path": ENVIRONMENT_PARKING,
			"position": Vector2(-585, 570),
			"size": Vector2(330, 191)
		},
		{
			"id": "entrance_south_west",
			"path": ENVIRONMENT_ENTRANCE,
			"position": Vector2(-420, 676),
			"size": Vector2(190, 154)
		},
		{
			"id": "trees_east",
			"path": ENVIRONMENT_TREES,
			"position": Vector2(630, 455),
			"size": Vector2(245, 198)
		},
		{
			"id": "trees_west",
			"path": ENVIRONMENT_TREES,
			"position": Vector2(-770, 350),
			"size": Vector2(205, 165)
		},
		{
			"id": "hedge_south",
			"path": ENVIRONMENT_HEDGE,
			"position": Vector2(40, 758),
			"size": Vector2(350, 120)
		},
		{
			"id": "conifers_north_east",
			"path": ENVIRONMENT_CONIFERS,
			"position": Vector2(860, 205),
			"size": Vector2(255, 214)
		},
		{
			"id": "conifers_south_east",
			"path": ENVIRONMENT_CONIFERS,
			"position": Vector2(780, 790),
			"size": Vector2(215, 180)
		},
		{
			"id": "fields_far_west",
			"path": ENVIRONMENT_FIELDS,
			"position": Vector2(-1110, 265),
			"size": Vector2(460, 239)
		},
		{
			"id": "fields_far_east",
			"path": ENVIRONMENT_FIELDS,
			"position": Vector2(1090, 610),
			"size": Vector2(430, 224)
		}
	]


func get_landside_access_road_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-980, 592),
		Vector2(-805, 554),
		Vector2(-655, 575),
		Vector2(-520, 624),
		Vector2(-365, 682),
		Vector2(-205, 728)
	])


func _draw_landside_environment() -> void:
	_draw_landside_access_road()
	for item in get_landside_scenery_layout():
		_draw_environment_sprite(
			String(item.get("path", "")),
			item.get("position", Vector2.ZERO),
			item.get("size", Vector2.ZERO)
		)


func _draw_landside_access_road() -> void:
	var road := get_landside_access_road_points()
	var shadow := PackedVector2Array()
	for point in road:
		shadow.append(point + Vector2(4, 6))

	draw_polyline(
		shadow,
		Color(0.03, 0.07, 0.08, 0.24),
		48.0,
		true
	)
	draw_polyline(
		road,
		Color("b9b2a8"),
		44.0,
		true
	)
	draw_polyline(
		road,
		Color("625f5a"),
		34.0,
		true
	)
	draw_polyline(
		road,
		Color("f0ece3", 0.80),
		2.2,
		true
	)

	for index in range(road.size() - 1):
		var a := road[index]
		var b := road[index + 1]
		var length := a.distance_to(b)
		if length <= 1.0:
			continue
		var direction := (b - a).normalized()
		var dash_start := a + direction * 24.0
		var dash_end := b - direction * 24.0
		if dash_start.distance_to(dash_end) > 8.0:
			draw_dashed_line(
				dash_start,
				dash_end,
				Color("e6d16b", 0.78),
				2.0,
				14.0
			)


func _draw_environment_sprite(
	path: String,
	position: Vector2,
	size: Vector2
) -> void:
	if path.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var texture := _get_building_texture(path)
	if texture == null:
		return
	var rect := Rect2(
		position - size * 0.5,
		size
	)
	draw_texture_rect(
		texture,
		rect,
		false,
		Color.WHITE
	)


func _draw_owned_airport_environment() -> void:
	for parcel_variant in parcels.values():
		var parcel: Dictionary = parcel_variant
		if not bool(parcel.get("owned", false)):
			continue

		var px := int(parcel.get("px", 0))
		var py := int(parcel.get("py", 0))
		if not _parcel_owned_at(px - 1, py):
			_draw_owned_parcel_edge(parcel, "x_min")
		if not _parcel_owned_at(px + 1, py):
			_draw_owned_parcel_edge(parcel, "x_max")
		if not _parcel_owned_at(px, py - 1):
			_draw_owned_parcel_edge(parcel, "y_min")
		if not _parcel_owned_at(px, py + 1):
			_draw_owned_parcel_edge(parcel, "y_max")


func _parcel_owned_at(px: int, py: int) -> bool:
	var parcel := _parcel_at(px, py)
	return (
		not parcel.is_empty()
		and bool(parcel.get("owned", false))
	)


func _draw_owned_parcel_edge(
	parcel: Dictionary,
	edge_name: String
) -> void:
	var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
	var sy := int(parcel.get("py", 0)) * PARCEL_SIZE
	var ex := sx + PARCEL_SIZE - 1
	var ey := sy + PARCEL_SIZE - 1
	var parcel_center := get_parcel_world_center(
		String(parcel.get("id", ""))
	)

	for index in range(PARCEL_SIZE):
		var tile := Vector2i.ZERO
		match edge_name:
			"x_min":
				tile = Vector2i(sx, sy + index)
			"x_max":
				tile = Vector2i(ex, sy + index)
			"y_min":
				tile = Vector2i(sx + index, sy)
			_:
				tile = Vector2i(sx + index, ey)

		var points := _tile_points(
			tile_to_world(Vector2(tile.x, tile.y))
		)
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		match edge_name:
			"x_min":
				a = points[0]
				b = points[3]
			"x_max":
				a = points[1]
				b = points[2]
			"y_min":
				a = points[0]
				b = points[1]
			_:
				a = points[3]
				b = points[2]

		_draw_fence_segment(a, b)

		var midpoint := a.lerp(b, 0.5)
		var outward := (midpoint - parcel_center).normalized()
		if index % 4 == 1:
			_draw_perimeter_light(midpoint - outward * 3.0)
		if index % 6 == 4:
			_draw_perimeter_tree(midpoint + outward * 20.0)


func _draw_fence_segment(a: Vector2, b: Vector2) -> void:
	draw_line(
		a + Vector2(2, 3),
		b + Vector2(2, 3),
		Color(0.03, 0.07, 0.08, 0.22),
		3.0
	)
	draw_line(a, b, FENCE_COLOR, 2.2)
	for fraction in [0.0, 0.5, 1.0]:
		var base := a.lerp(b, float(fraction))
		draw_line(
			base,
			base + Vector2(0, -13),
			FENCE_COLOR.lightened(0.18),
			2.0
		)
	if a.distance_to(b) > 1.0:
		var top_a := a + Vector2(0, -10)
		var top_b := b + Vector2(0, -10)
		draw_line(top_a, top_b, FENCE_MESH, 1.0)
		for fraction in [0.25, 0.5, 0.75]:
			var low := a.lerp(b, float(fraction))
			var high := top_a.lerp(top_b, float(fraction))
			draw_line(low, high, FENCE_MESH, 0.7)


func _draw_perimeter_light(base: Vector2) -> void:
	draw_line(
		base + Vector2(2, 3),
		base + Vector2(2, -28),
		Color(0.02, 0.05, 0.06, 0.25),
		4.0
	)
	draw_line(
		base,
		base + Vector2(0, -31),
		Color("56666c"),
		3.0
	)
	var head := base + Vector2(0, -33)
	draw_rect(
		Rect2(head + Vector2(-7, -3), Vector2(14, 6)),
		Color("48585e"),
		true
	)
	draw_circle(
		head + Vector2(-4, 0),
		2.2,
		PERIMETER_LIGHT
	)
	draw_circle(
		head + Vector2(4, 0),
		2.2,
		PERIMETER_LIGHT
	)


func _draw_perimeter_tree(base: Vector2) -> void:
	draw_set_transform(
		base + Vector2(4, 5),
		0.0,
		Vector2(1.0, 0.42)
	)
	draw_circle(
		Vector2.ZERO,
		10.0,
		Color(0.03, 0.08, 0.04, 0.18)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(
		Rect2(base + Vector2(-2, -16), Vector2(4, 18)),
		Color("71543a"),
		true
	)
	draw_circle(
		base + Vector2(-5, -22),
		9.0,
		Color("3f7f46")
	)
	draw_circle(
		base + Vector2(5, -23),
		10.0,
		Color("4e9953")
	)
	draw_circle(
		base + Vector2(0, -31),
		10.0,
		Color("5aa95d")
	)
	draw_circle(
		base + Vector2(-3, -33),
		4.0,
		Color("83be68", 0.75)
	)


func _draw_expansion_boundary_visuals() -> void:
	for parcel_id_variant in parcels.keys():
		var parcel_id := String(parcel_id_variant)
		var parcel := _parcel_progression_data(parcel_id)
		if parcel.is_empty() or bool(parcel.get("owned", false)):
			continue
		_draw_expansion_perimeter(parcel)
		_draw_expansion_marker(parcel)


func _draw_expansion_perimeter(parcel: Dictionary) -> void:
	var state := String(parcel.get("progression_state", "future"))
	var accent: Color = parcel.get(
		"accent",
		AVAILABLE_GRID_LINE if state == "available" else LOCKED_GRID_LINE
	)
	if state != "available":
		accent = accent.lerp(Color("7f918a"), 0.64)
		accent.a = 0.62
	else:
		accent.a = 0.92

	var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
	var sy := int(parcel.get("py", 0)) * PARCEL_SIZE
	var ex := sx + PARCEL_SIZE - 1
	var ey := sy + PARCEL_SIZE - 1
	var line_width := 2.6 if state == "available" else 1.7
	var dash := 11.0 if state == "available" else 7.0

	for y in range(sy, ey + 1):
		for x in range(sx, ex + 1):
			if not (x == sx or x == ex or y == sy or y == ey):
				continue
			var points := _tile_points(
				tile_to_world(Vector2(x, y))
			)
			if x == sx:
				draw_dashed_line(points[0], points[3], accent, line_width, dash)
			if x == ex:
				draw_dashed_line(points[1], points[2], accent, line_width, dash)
			if y == sy:
				draw_dashed_line(points[0], points[1], accent, line_width, dash)
			if y == ey:
				draw_dashed_line(points[3], points[2], accent, line_width, dash)

	# Construction/fence posts make unowned land read as a physical airport
	# boundary rather than merely a differently colored grid.
	var post_color := accent.lightened(0.16)
	for corner_tile in [
		Vector2i(sx, sy),
		Vector2i(ex, sy),
		Vector2i(ex, ey),
		Vector2i(sx, ey)
	]:
		var center := tile_to_world(
			Vector2(corner_tile.x, corner_tile.y)
		)
		draw_line(
			center + Vector2(0, -18),
			center + Vector2(0, 3),
			post_color,
			3.0
		)
		draw_circle(
			center + Vector2(0, -19),
			3.2,
			post_color
		)


func _draw_expansion_marker(parcel: Dictionary) -> void:
	var center := get_parcel_world_center(
		String(parcel.get("id", ""))
	)
	var state := String(parcel.get("progression_state", "future"))
	var accent: Color = parcel.get("accent", Color("e0b95b"))
	if state != "available":
		accent = accent.lerp(Color("75837d"), 0.58)

	var sign_center := center + Vector2(0, 27)
	var shadow_rect := Rect2(
		sign_center + Vector2(-28, -11),
		Vector2(56, 22)
	)
	draw_rect(shadow_rect.grow(3.0), Color(0.02, 0.05, 0.06, 0.38), true)
	draw_rect(shadow_rect, Color("27383a", 0.94), true)
	draw_rect(shadow_rect, accent, false, 2.0)
	draw_line(
		sign_center + Vector2(-20, 12),
		sign_center + Vector2(-20, 25),
		Color("a7b2aa"),
		3.0
	)
	draw_line(
		sign_center + Vector2(20, 12),
		sign_center + Vector2(20, 25),
		Color("a7b2aa"),
		3.0
	)

	if state == "available":
		# Small construction chevrons: immediately readable as purchasable land.
		for index in range(3):
			var x := -15.0 + float(index) * 15.0
			var chevron := PackedVector2Array([
				sign_center + Vector2(x - 5, -3),
				sign_center + Vector2(x, 3),
				sign_center + Vector2(x + 5, -3)
			])
			draw_polyline(chevron, accent.lightened(0.18), 2.0)
	else:
		# Pixel-style padlock silhouette for later expansion districts.
		draw_arc(
			sign_center + Vector2(0, -3),
			6.0,
			PI,
			TAU,
			8,
			Color("aeb8b3"),
			2.0
		)
		draw_rect(
			Rect2(sign_center + Vector2(-7, -3), Vector2(14, 10)),
			Color("aeb8b3"),
			true
		)


func get_parcel_visual_state(parcel_id: String) -> Dictionary:
	var parcel := _parcel_progression_data(parcel_id)
	if parcel.is_empty():
		return {}
	var state := String(parcel.get("progression_state", "future"))
	return {
		"state": state,
		"zone_name": String(parcel.get("name", "")),
		"accent": parcel.get("accent", Color.WHITE),
		"show_boundary": not bool(parcel.get("owned", false)),
		"show_construction_marker": state == "available",
		"show_lock_marker": state == "future"
	}


func _draw_parcel_unlock_fx() -> void:
	for parcel_id_variant in parcel_unlock_fx.keys():
		var parcel_id := String(parcel_id_variant)
		if not parcels.has(parcel_id):
			continue

		var elapsed := float(
			parcel_unlock_fx.get(parcel_id, 0.0)
		)
		var progress := clampf(
			elapsed / PARCEL_UNLOCK_FX_DURATION,
			0.0,
			1.0
		)
		var parcel: Dictionary = parcels[parcel_id]
		var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
		var sy := int(parcel.get("py", 0)) * PARCEL_SIZE

		var glow_alpha := (1.0 - progress) * 0.38
		for y in range(sy, sy + PARCEL_SIZE):
			for x in range(sx, sx + PARCEL_SIZE):
				var center := tile_to_world(Vector2(x, y))
				var points := _tile_points(center)
				draw_colored_polygon(
					points,
					Color(1.0, 0.84, 0.35, glow_alpha)
				)

		var pulse_alpha := (1.0 - progress) * 0.95
		var pulse_width := lerpf(4.5, 1.5, progress)
		for y in range(sy, sy + PARCEL_SIZE):
			for x in range(sx, sx + PARCEL_SIZE):
				if not (
					x == sx
					or x == sx + PARCEL_SIZE - 1
					or y == sy
					or y == sy + PARCEL_SIZE - 1
				):
					continue
				var p := _tile_points(
					tile_to_world(Vector2(x, y))
				)
				draw_polyline(
					PackedVector2Array([
						p[0], p[1], p[2], p[3], p[0]
					]),
					Color(1.0, 0.86, 0.42, pulse_alpha),
					pulse_width
				)

		var center := get_parcel_world_center(parcel_id)
		for index in range(8):
			var angle := float(index) * TAU / 8.0
			var radius := 18.0 + progress * 52.0
			var particle := center + Vector2(
				cos(angle) * radius,
				sin(angle) * radius * 0.42
			)
			var particle_size := lerpf(4.0, 1.5, progress)
			draw_circle(
				particle,
				particle_size,
				Color(
					1.0,
					0.88,
					0.48,
					(1.0 - progress) * 0.9
				)
			)


func is_parcel_unlock_animation_active(
	parcel_id: String
) -> bool:
	return parcel_unlock_fx.has(parcel_id)


func get_parcel_world_center(parcel_id: String) -> Vector2:
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return Vector2.ZERO

	var parcel: Dictionary = parcels[parcel_id]
	var center_tile := Vector2(
		int(parcel.get("px", 0)) * PARCEL_SIZE
		+ (PARCEL_SIZE - 1) * 0.5,
		int(parcel.get("py", 0)) * PARCEL_SIZE
		+ (PARCEL_SIZE - 1) * 0.5
	)
	return tile_to_world(center_tile)


func get_parcel_tile_count(parcel_id: String) -> int:
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return 0
	return PARCEL_SIZE * PARCEL_SIZE


func _draw_buildings() -> void:
	var buildings_to_draw: Array[Dictionary] = placed_buildings.duplicate(true)
	buildings_to_draw.sort_custom(Callable(self, "_sort_buildings_by_depth"))

	for building in buildings_to_draw:
		if (
			preview_mode == "move"
			and int(building.get("uid", -1)) == preview_ignore_uid
		):
			continue

		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty():
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var origin: Vector2i = building["origin"]
		var id := String(definition.get("id", ""))

		if id == "taxiway" or id == "service_road":
			_draw_pavement_tile(origin, id)
			if id == "taxiway":
				_draw_taxiway_detail(origin)
			else:
				_draw_service_road_detail(origin)
			continue

		var dimmed := _placement_focus_active()

		if _definition_has_world_sprite(definition):
			_draw_world_art_ground_pad(
				definition,
				origin,
				footprint
			)
			_draw_apron_surface_micro_detail(
				definition,
				origin,
				footprint,
				int(building["rotation"]),
				0.40 if dimmed else 1.0
			)
			_draw_building_sprite(
				definition,
				origin,
				footprint,
				int(building["rotation"]),
				EDIT_DIM_MODULATE if dimmed else Color.WHITE
			)
			_draw_apron_prop_micro_detail(
				definition,
				origin,
				footprint,
				int(building["rotation"]),
				0.40 if dimmed else 1.0
			)
		else:
			var color: Color = definition["color"]
			for y in range(footprint.y):
				for x in range(footprint.x):
					_draw_tile_overlay(
						origin + Vector2i(x, y),
						color,
						Color("eef2f1", 0.22),
						1.0
					)
			_draw_building_detail(
				building,
				definition,
				footprint
			)
			if dimmed:
				var dim_polygon := _footprint_polygon(
					origin,
					footprint
				)
				if dim_polygon.size() >= 4:
					draw_colored_polygon(
						dim_polygon,
						Color(0.05, 0.10, 0.10, 0.19)
					)




func _micro_alpha(
	color: Color,
	strength: float
) -> Color:
	return Color(
		color.r,
		color.g,
		color.b,
		color.a * clampf(strength, 0.0, 1.0)
	)


func _iso_box_points(
	center: Vector2,
	half_x: float,
	half_y: float
) -> PackedVector2Array:
	var axis_x := Vector2(
		half_x,
		-half_x * 0.5
	)
	var axis_y := Vector2(
		half_y,
		half_y * 0.5
	)
	return PackedVector2Array([
		center - axis_x - axis_y,
		center + axis_x - axis_y,
		center + axis_x + axis_y,
		center - axis_x + axis_y
	])


func _draw_iso_outline_box(
	center: Vector2,
	half_x: float,
	half_y: float,
	color: Color,
	width: float = 1.5
) -> void:
	var points := _iso_box_points(
		center,
		half_x,
		half_y
	)
	draw_polyline(
		PackedVector2Array([
			points[0],
			points[1],
			points[2],
			points[3],
			points[0]
		]),
		color,
		width
	)


func _draw_apron_surface_micro_detail(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i,
	rotation: int,
	strength: float = 1.0
) -> void:
	var id := String(
		definition.get("id", "")
	)
	var category := String(
		definition.get("category", "")
	)
	var polygon := _footprint_polygon(
		origin,
		footprint
	)
	if polygon.size() < 4:
		return
	var center := _footprint_center_world(
		origin,
		footprint
	)

	if id.contains("stand"):
		_draw_stand_guidance_detail(
			polygon,
			center,
			rotation,
			strength
		)
		return

	if category == "Passenger":
		_draw_passenger_pad_detail(
			polygon,
			center,
			strength
		)
	elif category == "Services":
		_draw_service_pad_detail(
			polygon,
			center,
			strength
		)


func _draw_stand_guidance_detail(
	polygon: PackedVector2Array,
	center: Vector2,
	rotation: int,
	strength: float
) -> void:
	var top_mid := polygon[0].lerp(
		polygon[1],
		0.5
	)
	var bottom_mid := polygon[3].lerp(
		polygon[2],
		0.5
	)
	var guidance := _micro_alpha(
		Color("f2c84b", 0.92),
		strength
	)
	var safety := _micro_alpha(
		Color("e66f67", 0.88),
		strength
	)
	var service := _micro_alpha(
		Color("f5f0df", 0.76),
		strength
	)

	draw_line(
		top_mid.lerp(center, 0.18),
		bottom_mid.lerp(center, 0.12),
		guidance,
		2.4
	)

	var wing_a := center + Vector2(
		-31 if rotation % 2 == 0 else -25,
		-3
	)
	var wing_b := center + Vector2(
		31 if rotation % 2 == 0 else 25,
		-3
	)
	draw_line(
		wing_a,
		wing_b,
		guidance,
		2.0
	)
	draw_line(
		wing_a + Vector2(8, 6),
		wing_a + Vector2(8, -6),
		guidance,
		1.5
	)
	draw_line(
		wing_b + Vector2(-8, 6),
		wing_b + Vector2(-8, -6),
		guidance,
		1.5
	)

	var front_a := polygon[3].lerp(
		polygon[2],
		0.16
	)
	var front_b := polygon[3].lerp(
		polygon[2],
		0.84
	)
	draw_dashed_line(
		front_a,
		front_b,
		safety,
		2.0,
		9.0
	)

	var left_zone := center.lerp(
		polygon[3].lerp(
			polygon[0],
			0.55
		),
		0.62
	)
	var right_zone := center.lerp(
		polygon[1].lerp(
			polygon[2],
			0.55
		),
		0.62
	)
	_draw_iso_outline_box(
		left_zone,
		13.0,
		8.0,
		service,
		1.4
	)
	_draw_iso_outline_box(
		right_zone,
		13.0,
		8.0,
		service,
		1.4
	)

	var stop_bar := center.lerp(
		bottom_mid,
		0.36
	)
	draw_line(
		stop_bar + Vector2(-10, 5),
		stop_bar + Vector2(10, -5),
		_micro_alpha(
			Color("f8f4e9", 0.88),
			strength
		),
		3.0
	)


func _draw_passenger_pad_detail(
	polygon: PackedVector2Array,
	center: Vector2,
	strength: float
) -> void:
	var front_a := polygon[3]
	var front_b := polygon[2]
	var edge := front_b - front_a
	if edge.length() <= 1.0:
		return
	var direction := edge.normalized()
	var crossing_center := front_a.lerp(
		front_b,
		0.50
	)
	var white := _micro_alpha(
		Color("f7f3e8", 0.72),
		strength
	)
	for offset in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var stripe_center := (
			crossing_center
			+ direction * offset
			+ Vector2(0, -2)
		)
		draw_line(
			stripe_center + Vector2(-5, 2),
			stripe_center + Vector2(5, -2),
			white,
			2.4
		)

	var safe_line := center.lerp(
		crossing_center,
		0.66
	)
	draw_dashed_line(
		safe_line + Vector2(-26, 13),
		safe_line + Vector2(26, -13),
		_micro_alpha(
			Color("f1c84e", 0.62),
			strength
		),
		1.7,
		7.0
	)


func _draw_service_pad_detail(
	polygon: PackedVector2Array,
	center: Vector2,
	strength: float
) -> void:
	var service_line := _micro_alpha(
		Color("efe9dc", 0.64),
		strength
	)
	var amber := _micro_alpha(
		Color("f0bd48", 0.60),
		strength
	)

	var left := center.lerp(
		polygon[3].lerp(
			polygon[0],
			0.55
		),
		0.55
	)
	var right := center.lerp(
		polygon[1].lerp(
			polygon[2],
			0.55
		),
		0.55
	)
	_draw_iso_outline_box(
		left,
		12.0,
		7.0,
		service_line,
		1.3
	)
	_draw_iso_outline_box(
		right,
		12.0,
		7.0,
		service_line,
		1.3
	)
	draw_dashed_line(
		left,
		right,
		amber,
		1.5,
		6.0
	)


func _draw_apron_prop_micro_detail(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i,
	rotation: int,
	strength: float = 1.0
) -> void:
	var id := String(
		definition.get("id", "")
	)
	var category := String(
		definition.get("category", "")
	)
	var center := _footprint_center_world(
		origin,
		footprint
	)
	var polygon := _footprint_polygon(
		origin,
		footprint
	)
	if polygon.size() < 4:
		return

	if id.contains("stand"):
		_draw_cart_bay_prop(
			center.lerp(
				polygon[1].lerp(
					polygon[2],
					0.63
				),
				0.70
			),
			rotation,
			strength
		)
		return

	if category in ["Passenger", "Services"]:
		var front := polygon[3].lerp(
			polygon[2],
			0.78
		)
		_draw_apron_utility_cabinet(
			front + Vector2(0, -5),
			rotation,
			strength
		)


func _draw_cart_bay_prop(
	base: Vector2,
	rotation: int,
	strength: float
) -> void:
	var body := _micro_alpha(
		Color("6b7780", 0.95),
		strength
	)
	var roof := _micro_alpha(
		Color("aeb8bb", 0.94),
		strength
	)
	var wheel := _micro_alpha(
		Color("283136", 0.92),
		strength
	)
	var step := (
		Vector2(8, -4)
		if rotation % 2 == 0
		else Vector2(8, 4)
	)

	for index in range(2):
		var pos := base + step * float(index)
		var box := _iso_box_points(
			pos,
			5.0,
			3.0
		)
		draw_colored_polygon(
			box,
			body
		)
		draw_line(
			box[0],
			box[1],
			roof,
			1.3
		)
		draw_circle(
			pos + Vector2(-3, 4),
			1.5,
			wheel
		)
		draw_circle(
			pos + Vector2(4, 1),
			1.5,
			wheel
		)


func _draw_apron_utility_cabinet(
	base: Vector2,
	rotation: int,
	strength: float
) -> void:
	var body := _micro_alpha(
		Color("5c7887", 0.96),
		strength
	)
	var face := _micro_alpha(
		Color("82a4b1", 0.96),
		strength
	)
	var yellow := _micro_alpha(
		Color("f1c44e", 0.92),
		strength
	)
	var shadow := _micro_alpha(
		Color(0.02, 0.05, 0.06, 0.24),
		strength
	)

	draw_set_transform(
		base + Vector2(3, 4),
		0.0,
		Vector2(1.0, 0.42)
	)
	draw_circle(
		Vector2.ZERO,
		8.0,
		shadow
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)

	var side := -1.0 if rotation % 2 == 0 else 1.0
	var cabinet := PackedVector2Array([
		base + Vector2(-6 * side, -13),
		base + Vector2(4 * side, -9),
		base + Vector2(4 * side, 1),
		base + Vector2(-6 * side, -3)
	])
	draw_colored_polygon(
		cabinet,
		body
	)
	draw_line(
		cabinet[0],
		cabinet[1],
		face,
		1.5
	)
	draw_circle(
		base + Vector2(-10 * side, 1),
		2.1,
		Color(0.03, 0.05, 0.05, 0.35)
	)
	draw_circle(
		base + Vector2(-10 * side, -1),
		1.3,
		yellow
	)
	draw_line(
		base + Vector2(8 * side, 1),
		base + Vector2(8 * side, -8),
		yellow,
		2.2
	)


func _building_ground_color(
	definition: Dictionary
) -> Color:
	var id := String(
		definition.get("id", "")
	)
	if id.contains("runway"):
		return Color("596167", 0.80)
	if id.contains("stand"):
		return Color("d3ccc1", 0.66)

	var category := String(
		definition.get("category", "")
	)
	match category:
		"Passenger":
			return Color("d0c9be", 0.58)
		"Services":
			return Color("c9c2b7", 0.56)
		"Operations":
			return Color("c5c1b8", 0.54)
		"Infrastructure":
			return Color("aaa89f", 0.50)
		_:
			return Color("c7c1b7", 0.50)


func _draw_world_art_ground_pad(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i
) -> void:
	var polygon := _footprint_polygon(
		origin,
		footprint
	)
	if polygon.size() < 4:
		return

	var fill := _building_ground_color(
		definition
	)
	var shadow := PackedVector2Array()
	for point_variant in polygon:
		var point: Vector2 = point_variant
		shadow.append(point + Vector2(2, 3))

	draw_colored_polygon(
		shadow,
		Color("202b2f", 0.16)
	)
	draw_colored_polygon(
		polygon,
		fill
	)

	# One continuous pad avoids the old checker/tile seams and follows
	# the same fixed upper-left light direction as the production art.
	draw_line(
		polygon[0],
		polygon[1],
		Color("fffaf0", 0.20),
		1.4
	)
	draw_line(
		polygon[0],
		polygon[3],
		Color("ffffff", 0.10),
		1.0
	)
	draw_line(
		polygon[2],
		polygon[3],
		Color("263238", 0.15),
		1.4
	)
	draw_line(
		polygon[1],
		polygon[2],
		Color("263238", 0.09),
		1.0
	)
	_draw_hardscape_curb_and_drainage(
		polygon,
		definition
	)
	_draw_runway_edge_detail(
		polygon,
		definition
	)


func _draw_hardscape_curb_and_drainage(
	polygon: PackedVector2Array,
	definition: Dictionary
) -> void:
	if polygon.size() < 4:
		return
	var id := String(definition.get("id", ""))
	if id.contains("runway") or id.contains("stand"):
		return

	var front_a := polygon[3]
	var front_b := polygon[2]
	draw_line(
		front_a + Vector2(0, -1),
		front_b + Vector2(0, -1),
		Color("eee9df", 0.28),
		1.3
	)
	draw_line(
		front_a + Vector2(0, 2),
		front_b + Vector2(0, 2),
		Color("3a4447", 0.20),
		1.6
	)

	var edge := front_b - front_a
	var edge_length := edge.length()
	if edge_length < 70.0:
		return
	var direction := edge.normalized()
	for fraction in [0.30, 0.70]:
		var center := front_a.lerp(
			front_b,
			float(fraction)
		) + Vector2(0, 1)
		draw_line(
			center - direction * 7.0,
			center + direction * 7.0,
			Color("4b5558", 0.64),
			3.0
		)
		for slot in [-4.0, 0.0, 4.0]:
			draw_circle(
				center + direction * slot,
				0.9,
				Color("1f292c", 0.80)
			)



func _draw_runway_edge_detail(
	polygon: PackedVector2Array,
	definition: Dictionary
) -> void:
	if polygon.size() < 4:
		return
	var id := String(definition.get("id", ""))
	if not id.contains("runway"):
		return

	var pairs := [
		[polygon[0], polygon[1]],
		[polygon[3], polygon[2]]
	]
	for pair_variant in pairs:
		var pair: Array = pair_variant
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var edge := b - a
		var length := edge.length()
		if length <= 1.0:
			continue
		var direction := edge.normalized()
		var normal := Vector2(-direction.y, direction.x)

		draw_line(
			a + normal * 2.0,
			b + normal * 2.0,
			Color("c8d19d", 0.28),
			3.0
		)
		draw_line(
			a - normal * 2.0,
			b - normal * 2.0,
			Color("273237", 0.22),
			2.0
		)

		var drain_count := maxi(int(length / 56.0), 2)
		for index in range(1, drain_count):
			var fraction := float(index) / float(drain_count)
			var center := a.lerp(b, fraction)
			draw_line(
				center - direction * 5.0,
				center + direction * 5.0,
				Color("343e42", 0.68),
				2.6
			)
			for slot in [-3.0, 0.0, 3.0]:
				draw_circle(
					center + direction * slot,
					0.8,
					Color("182226", 0.82)
				)


func _footprint_polygon(
	origin: Vector2i,
	footprint: Vector2i
) -> PackedVector2Array:
	if footprint.x <= 0 or footprint.y <= 0:
		return PackedVector2Array()

	var a := tile_to_world(
		Vector2(origin.x, origin.y)
	)
	var b := tile_to_world(
		Vector2(
			origin.x + footprint.x - 1,
			origin.y
		)
	)
	var c := tile_to_world(
		Vector2(
			origin.x + footprint.x - 1,
			origin.y + footprint.y - 1
		)
	)
	var d := tile_to_world(
		Vector2(
			origin.x,
			origin.y + footprint.y - 1
		)
	)

	return PackedVector2Array([
		a + Vector2(0, -TILE_HEIGHT * 0.5),
		b + Vector2(TILE_WIDTH * 0.5, 0),
		c + Vector2(0, TILE_HEIGHT * 0.5),
		d + Vector2(-TILE_WIDTH * 0.5, 0)
	])


func _building_front_depth(building: Dictionary) -> int:
	var origin: Vector2i = building.get(
		"origin",
		Vector2i.ZERO
	)
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return origin.x + origin.y

	var footprint := _footprint_for(
		definition,
		int(building.get("rotation", 0))
	)
	return (
		origin.x
		+ origin.y
		+ footprint.x
		+ footprint.y
		- 2
	)


func _sort_buildings_by_depth(a: Dictionary, b: Dictionary) -> bool:
	var a_depth := _building_front_depth(a)
	var b_depth := _building_front_depth(b)
	if a_depth != b_depth:
		return a_depth < b_depth

	var a_origin: Vector2i = a.get(
		"origin",
		Vector2i.ZERO
	)
	var b_origin: Vector2i = b.get(
		"origin",
		Vector2i.ZERO
	)
	if a_origin.y != b_origin.y:
		return a_origin.y < b_origin.y
	return a_origin.x < b_origin.x


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
		_draw_taxiway_detail(origin)

	elif id.contains("fuel"):
		var center := _footprint_center_world(origin, footprint)
		draw_circle(center + Vector2(-10, 0), 8.0, Color("f4e4b0"))
		draw_circle(center + Vector2(10, 0), 8.0, Color("f4e4b0"))

	elif id.contains("stand"):
		var center := _footprint_center_world(origin, footprint)
		draw_circle(center, 10.0, Color("dce5e7"), false, 3.0)

	elif id == "atc_tower":
		var center := _footprint_center_world(origin, footprint)
		draw_rect(
			Rect2(center + Vector2(-8, -32), Vector2(16, 34)),
			Color("9eb3ba")
		)
		draw_rect(
			Rect2(center + Vector2(-15, -42), Vector2(30, 12)),
			Color("334951")
		)
		draw_line(
			center + Vector2(0, -42),
			center + Vector2(0, -55),
			Color("d5e5e8"),
			2.0
		)
		draw_circle(
			center + Vector2(0, -57),
			3.0,
			Color("f0c95d")
		)

	elif id in [
		"travel_office",
		"shuttle_station",
		"ground_ops_depot",
		"cleaning_center",
		"passenger_service_hub",
		"baggage_depot",
		"catering_kitchen",
		"tow_operations"
	]:
		_draw_synergy_facility_detail(
			id,
			_footprint_center_world(origin, footprint),
			footprint
		)

	elif id == "autumn_event_flag":
		_draw_autumn_event_flag(origin)

	elif id == "autumn_leaf_garden":
		_draw_autumn_leaf_garden(origin, footprint)

	elif id == "winter_event_flag":
		_draw_winter_event_flag(origin)

	elif id == "winter_snow_globe_garden":
		_draw_winter_snow_globe_garden(origin, footprint)


func _draw_synergy_facility_detail(
	building_id: String,
	center: Vector2,
	footprint: Vector2i
) -> void:
	var width := clampf(
		float(footprint.x + footprint.y) * 13.0,
		38.0,
		76.0
	)
	var body_color := Color("5f7f8a")
	var accent := Color("d8c166")
	match building_id:
		"travel_office":
			body_color = Color("4d8f8e")
			accent = Color("bde8df")
		"shuttle_station":
			body_color = Color("4f7f9d")
			accent = Color("b8e1f2")
		"cleaning_center":
			body_color = Color("70a5a0")
			accent = Color("d3f0eb")
		"passenger_service_hub":
			body_color = Color("538eb0")
			accent = Color("b8e1f2")
		"baggage_depot":
			body_color = Color("8b765c")
			accent = Color("d6b77a")
		"catering_kitchen":
			body_color = Color("b98662")
			accent = Color("f1d8bd")
		"tow_operations":
			body_color = Color("667482")
			accent = Color("d9bd5b")

	var body := Rect2(
		center + Vector2(-width * 0.5, -44),
		Vector2(width, 42)
	)
	draw_rect(
		body.grow(4.0),
		Color(0.03, 0.07, 0.08, 0.34),
		true
	)
	draw_rect(body, body_color, true)
	draw_rect(body, body_color.lightened(0.20), false, 2.0)
	var door_width := maxf(width * 0.28, 14.0)
	draw_rect(
		Rect2(
			center + Vector2(-door_width * 0.5, -26),
			Vector2(door_width, 24)
		),
		body_color.darkened(0.34),
		true
	)

	match building_id:
		"travel_office":
			for x in [-20.0, 20.0]:
				draw_rect(
					Rect2(
						center + Vector2(x - 7, -37),
						Vector2(14, 9)
					),
					accent,
					true
				)
		"shuttle_station", "passenger_service_hub":
			draw_rect(
				Rect2(
					center + Vector2(-22, -36),
					Vector2(44, 11)
				),
				accent,
				true
			)
			draw_circle(
				center + Vector2(-17, -3),
				5.0,
				Color("26363d")
			)
			draw_circle(
				center + Vector2(17, -3),
				5.0,
				Color("26363d")
			)
		"cleaning_center":
			for offset in [
				Vector2(-14, -34),
				Vector2(0, -26),
				Vector2(16, -37)
			]:
				draw_circle(center + offset, 3.2, accent)
		"baggage_depot":
			for index in range(3):
				draw_rect(
					Rect2(
						center + Vector2(
							-25 + index * 18,
							-35
						),
						Vector2(13, 13)
					),
					accent.darkened(
						float(index) * 0.08
					),
					true
				)
		"catering_kitchen":
			draw_rect(
				Rect2(
					center + Vector2(-20, -55),
					Vector2(8, 13)
				),
				Color("9eabb0"),
				true
			)
			draw_rect(
				Rect2(
					center + Vector2(13, -59),
					Vector2(9, 17)
				),
				Color("9eabb0"),
				true
			)
			draw_circle(
				center + Vector2(0, -33),
				5.0,
				accent
			)
		"tow_operations":
			draw_rect(
				Rect2(
					center + Vector2(-21, -34),
					Vector2(42, 10)
				),
				accent,
				true
			)
			draw_circle(
				center + Vector2(-18, -3),
				5.0,
				Color("263238")
			)
			draw_circle(
				center + Vector2(18, -3),
				5.0,
				Color("263238")
			)
		_:
			draw_rect(
				Rect2(
					center + Vector2(-17, -36),
					Vector2(34, 9)
				),
				accent,
				true
			)


func set_event_visual_state(
	snapshot: Dictionary,
	owned_cosmetics: Dictionary
) -> void:
	event_visual_snapshot = snapshot.duplicate(true)
	event_owned_cosmetics = owned_cosmetics.duplicate(true)
	queue_redraw()


func _draw_event_theme_overlay() -> void:
	if not bool(event_visual_snapshot.get("active", false)):
		return

	var theme := String(
		event_visual_snapshot.get("theme", "")
	)
	if theme not in ["autumn", "winter"]:
		return

	for building in placed_buildings:
		if String(building.get("definition_id", "")) != "small_terminal":
			continue

		var definition := BuildingCatalog.get_definition("small_terminal")
		if definition.is_empty():
			continue
		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		var center := _footprint_center_world(
			building.get("origin", Vector2i.ZERO),
			footprint
		)

		match theme:
			"autumn":
				_draw_autumn_terminal_bunting(center)
				if bool(
					event_owned_cosmetics.get(
						"event_autumn_terminal_skin",
						false
					)
				):
					_draw_autumn_terminal_skin(center)
			"winter":
				_draw_winter_terminal_lights(center)
				if bool(
					event_owned_cosmetics.get(
						"event_winter_terminal_skin",
						false
					)
				):
					_draw_winter_terminal_skin(center)

	match theme:
		"autumn":
			if bool(
				event_owned_cosmetics.get(
					"event_autumn_airport_border",
					false
				)
			):
				_draw_autumn_airport_border()
		"winter":
			if bool(
				event_owned_cosmetics.get(
					"event_winter_airport_border",
					false
				)
			):
				_draw_winter_airport_border()


func _draw_autumn_terminal_bunting(center: Vector2) -> void:
	var y := center.y - 72.0
	draw_line(
		center + Vector2(-58, -70),
		center + Vector2(58, -70),
		Color("f0c36b"),
		2.0
	)
	var colors := [
		Color("d86f32"),
		Color("f0b54c"),
		Color("a84e2b")
	]
	for index in range(7):
		var x := -48.0 + float(index) * 16.0
		var top := center + Vector2(x, -69)
		var points := PackedVector2Array([
			top + Vector2(-5, 0),
			top + Vector2(5, 0),
			top + Vector2(0, 9)
		])
		draw_colored_polygon(
			points,
			colors[index % colors.size()]
		)


func _draw_autumn_terminal_skin(center: Vector2) -> void:
	var canopy := Rect2(
		center + Vector2(-74, -62),
		Vector2(148, 15)
	)
	draw_rect(canopy, Color("8f3f28", 0.82), true)
	draw_rect(canopy, Color("f1bd59", 0.95), false, 2.0)

	for index in range(5):
		var leaf_center := center + Vector2(
			-54 + index * 27,
			-82 + (index % 2) * 4
		)
		draw_circle(
			leaf_center,
			5.0,
			Color("de7835")
		)
		draw_line(
			leaf_center,
			leaf_center + Vector2(4, -6),
			Color("6f3b24"),
			1.0
		)


func _draw_autumn_airport_border() -> void:
	for parcel_variant in parcels.values():
		var parcel: Dictionary = parcel_variant
		if not bool(parcel.get("owned", false)):
			continue

		var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
		var sy := int(parcel.get("py", 0)) * PARCEL_SIZE
		for y in range(sy, sy + PARCEL_SIZE):
			for x in range(sx, sx + PARCEL_SIZE):
				if not (
					x == sx
					or x == sx + PARCEL_SIZE - 1
					or y == sy
					or y == sy + PARCEL_SIZE - 1
				):
					continue
				var p := _tile_points(
					tile_to_world(Vector2(x, y))
				)
				draw_polyline(
					PackedVector2Array([
						p[0], p[1], p[2], p[3], p[0]
					]),
					Color("d97833", 0.70),
					2.0
				)


func _draw_autumn_event_flag(origin: Vector2i) -> void:
	var center := tile_to_world(
		Vector2(origin.x, origin.y)
	)
	var base := center + Vector2(0, 8)
	var top := center + Vector2(0, -38)
	draw_line(base, top, Color("d9d2bf"), 3.0)
	var flag := PackedVector2Array([
		top,
		top + Vector2(25, 7),
		top + Vector2(0, 15)
	])
	draw_colored_polygon(flag, Color("c95c2a"))
	draw_circle(
		base + Vector2(0, 3),
		6.0,
		Color("8e6c3c")
	)


func _draw_autumn_leaf_garden(
	origin: Vector2i,
	footprint: Vector2i
) -> void:
	var center := _footprint_center_world(origin, footprint)
	var colors := [
		Color("b8572d"),
		Color("d97b34"),
		Color("eba84a"),
		Color("8b4a2d")
	]
	for index in range(10):
		var angle := float(index) * 0.63
		var radius := 8.0 + float(index % 4) * 5.0
		var leaf := center + Vector2(
			cos(angle) * radius,
			sin(angle) * radius * 0.45
		)
		draw_circle(
			leaf,
			3.5,
			colors[index % colors.size()]
		)
	draw_circle(
		center,
		14.0,
		Color("6d5631", 0.55),
		false,
		2.0
	)


func _draw_winter_terminal_lights(center: Vector2) -> void:
	var left := center + Vector2(-60, -72)
	var right := center + Vector2(60, -72)
	draw_line(left, right, Color("d8ecf2"), 2.0)

	var colors := [
		Color("d83f48"),
		Color("2f9b5f"),
		Color("f2c94c"),
		Color("7fc9e8")
	]
	for index in range(9):
		var bulb := center + Vector2(
			-52 + index * 13,
			-69 + (index % 2) * 3
		)
		draw_circle(
			bulb,
			3.2,
			colors[index % colors.size()]
		)


func _draw_winter_terminal_skin(center: Vector2) -> void:
	var canopy := Rect2(
		center + Vector2(-76, -63),
		Vector2(152, 16)
	)
	draw_rect(canopy, Color("dceef5", 0.92), true)
	draw_rect(canopy, Color("75b8d6", 0.95), false, 2.0)

	for index in range(7):
		var snow := center + Vector2(
			-60 + index * 20,
			-82 + (index % 2) * 4
		)
		draw_circle(snow, 4.0, Color("f8fdff"))
		draw_line(
			snow + Vector2(-4, 0),
			snow + Vector2(4, 0),
			Color("d8eef7"),
			1.0
		)


func _draw_winter_airport_border() -> void:
	var colors := [
		Color("75b8d6", 0.82),
		Color("e7f7ff", 0.82),
		Color("c93642", 0.82),
		Color("2f8f58", 0.82)
	]
	var color_index := 0

	for parcel_variant in parcels.values():
		var parcel: Dictionary = parcel_variant
		if not bool(parcel.get("owned", false)):
			continue

		var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
		var sy := int(parcel.get("py", 0)) * PARCEL_SIZE
		for y in range(sy, sy + PARCEL_SIZE):
			for x in range(sx, sx + PARCEL_SIZE):
				if not (
					x == sx
					or x == sx + PARCEL_SIZE - 1
					or y == sy
					or y == sy + PARCEL_SIZE - 1
				):
					continue
				var p := _tile_points(
					tile_to_world(Vector2(x, y))
				)
				draw_polyline(
					PackedVector2Array([
						p[0], p[1], p[2], p[3], p[0]
					]),
					colors[color_index % colors.size()],
					2.0
				)
				color_index += 1


func _draw_winter_event_flag(origin: Vector2i) -> void:
	var center := tile_to_world(
		Vector2(origin.x, origin.y)
	)
	var base := center + Vector2(0, 8)
	var top := center + Vector2(0, -38)
	draw_line(base, top, Color("e6edf0"), 3.0)
	var flag := PackedVector2Array([
		top,
		top + Vector2(25, 7),
		top + Vector2(0, 15)
	])
	draw_colored_polygon(flag, Color("3f8ebd"))
	draw_line(
		top + Vector2(4, 4),
		top + Vector2(18, 10),
		Color("f2c94c"),
		2.0
	)
	draw_circle(
		base + Vector2(0, 3),
		6.0,
		Color("8aa5b0")
	)


func _draw_winter_snow_globe_garden(
	origin: Vector2i,
	footprint: Vector2i
) -> void:
	var center := _footprint_center_world(origin, footprint)
	draw_circle(
		center + Vector2(0, -7),
		18.0,
		Color("d9f3ff", 0.45)
	)
	draw_circle(
		center + Vector2(0, -7),
		18.0,
		Color("eaf9ff"),
		false,
		2.0
	)
	draw_rect(
		Rect2(
			center + Vector2(-13, 10),
			Vector2(26, 7)
		),
		Color("537b8c"),
		true
	)

	var tree_top := center + Vector2(0, -20)
	for tier in range(3):
		var y := float(tier) * 8.0
		var half_width := 6.0 + float(tier) * 4.0
		var points := PackedVector2Array([
			tree_top + Vector2(0, y - 6),
			tree_top + Vector2(-half_width, y + 6),
			tree_top + Vector2(half_width, y + 6)
		])
		draw_colored_polygon(points, Color("2f8f58"))

	draw_circle(
		center + Vector2(0, -27),
		2.8,
		Color("f2c94c")
	)

	for index in range(6):
		var snow := center + Vector2(
			-10 + (index % 3) * 10,
			-16 + int(index / 3) * 11
		)
		draw_circle(snow, 1.8, Color("ffffff"))


func _definition_has_world_sprite(definition: Dictionary) -> bool:
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	if not atlas_path.is_empty():
		return true
	var variants: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	return (
		variants.size() > 0
		or not String(
			definition.get("world_sprite_path", "")
		).is_empty()
	)


func _sprite_path_for_rotation(
	definition: Dictionary,
	rotation: int
) -> String:
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	if not atlas_path.is_empty():
		return atlas_path

	var variants: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if variants.size() > 0:
		return variants[rotation % variants.size()]
	return String(definition.get("world_sprite_path", ""))


func _sprite_region_for_rotation(
	definition: Dictionary,
	rotation: int
) -> Rect2:
	var regions: Array = definition.get(
		"world_sprite_regions",
		[]
	)
	if regions.is_empty():
		return Rect2()

	var region: Rect2 = regions[rotation % regions.size()]
	return region


func _sprite_offset_for_rotation(
	definition: Dictionary,
	rotation: int
) -> Vector2:
	var offsets: Array = definition.get(
		"world_sprite_offsets",
		[]
	)
	if not offsets.is_empty():
		var value = offsets[rotation % offsets.size()]
		if value is Vector2:
			return value
	return definition.get(
		"world_sprite_offset",
		Vector2.ZERO
	)



func _building_sprite_rect(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i,
	rotation: int,
	extra_offset: Vector2 = Vector2.ZERO
) -> Rect2:
	var draw_size: Vector2 = definition.get(
		"world_sprite_size",
		Vector2(160, 120)
	)
	var offset := _sprite_offset_for_rotation(
		definition,
		rotation
	)
	var center := _footprint_center_world(
		origin,
		footprint
	)
	return Rect2(
		center - draw_size * 0.5 + offset + extra_offset,
		draw_size
	)


func _get_building_texture_image(
	path: String
):
	if building_texture_images.has(path):
		return building_texture_images[path]

	var texture := _get_building_texture(path)
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		return null

	building_texture_images[path] = image
	return image


func _building_at_visual_position(
	world_position: Vector2
) -> Dictionary:
	var buildings_to_check: Array[Dictionary] = (
		placed_buildings.duplicate(true)
	)
	buildings_to_check.sort_custom(
		Callable(self, "_sort_buildings_by_depth")
	)

	for index in range(
		buildings_to_check.size() - 1,
		-1,
		-1
	):
		var building: Dictionary = buildings_to_check[index]
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if (
			definition.is_empty()
			or not _definition_has_world_sprite(definition)
		):
			continue

		var rotation := int(
			building.get("rotation", 0)
		) % 2
		var footprint := _footprint_for(
			definition,
			rotation
		)
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		var rect := _building_sprite_rect(
			definition,
			origin,
			footprint,
			rotation
		)
		if not rect.has_point(world_position):
			continue

		var sprite_path := _sprite_path_for_rotation(
			definition,
			rotation
		)
		if sprite_path.is_empty():
			continue

		var image = _get_building_texture_image(
			sprite_path
		)
		if image == null:
			continue

		var local := Vector2(
			(world_position.x - rect.position.x)
				/ maxf(rect.size.x, 1.0),
			(world_position.y - rect.position.y)
				/ maxf(rect.size.y, 1.0)
		)
		local.x = clampf(local.x, 0.0, 0.9999)
		local.y = clampf(local.y, 0.0, 0.9999)

		var source := _sprite_region_for_rotation(
			definition,
			rotation
		)
		var pixel := Vector2i.ZERO
		if (
			source.size.x > 0.0
			and source.size.y > 0.0
		):
			pixel = Vector2i(
				int(
					source.position.x
					+ local.x * source.size.x
				),
				int(
					source.position.y
					+ local.y * source.size.y
				)
			)
		else:
			pixel = Vector2i(
				int(local.x * float(image.get_width())),
				int(local.y * float(image.get_height()))
			)

		if (
			pixel.x < 0
			or pixel.y < 0
			or pixel.x >= image.get_width()
			or pixel.y >= image.get_height()
		):
			continue

		if image.get_pixelv(pixel).a > 0.05:
			return building.duplicate(true)

	return {}


func _draw_building_sprite(
	definition: Dictionary,
	origin: Vector2i,
	footprint: Vector2i,
	rotation: int,
	modulate: Color = Color.WHITE,
	extra_offset: Vector2 = Vector2.ZERO
) -> void:
	var sprite_path := _sprite_path_for_rotation(
		definition,
		rotation
	)
	if sprite_path.is_empty():
		return

	var texture := _get_building_texture(sprite_path)
	if texture == null:
		return

	var rect := _building_sprite_rect(
		definition,
		origin,
		footprint,
		rotation,
		extra_offset
	)
	var source_region := _sprite_region_for_rotation(
		definition,
		rotation
	)
	if source_region.size.x > 0.0 and source_region.size.y > 0.0:
		draw_texture_rect_region(
			texture,
			rect,
			source_region,
			modulate
		)
	else:
		draw_texture_rect(texture, rect, false, modulate)



func get_airfield_detail_snapshot() -> Dictionary:
	var runway_count := 0
	var taxiway_tiles := 0
	var taxiway_open_edges := 0
	var service_road_tiles := 0
	var service_road_open_edges := 0
	var service_barrier_candidates := 0

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for building in placed_buildings:
		var id := String(
			building.get("definition_id", "")
		)
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)

		if id.contains("runway"):
			runway_count += 1
			continue

		if id == "taxiway":
			taxiway_tiles += 1
			for direction in directions:
				if not _taxiway_visually_connects_to(
					origin + direction
				):
					taxiway_open_edges += 1
			continue

		if id == "service_road":
			service_road_tiles += 1
			var connections := 0
			for direction in directions:
				if _service_road_visually_connects_to(
					origin + direction
				):
					connections += 1
				else:
					service_road_open_edges += 1
			if (
				connections <= 1
				and (origin.x + origin.y) % 2 == 0
			):
				service_barrier_candidates += 1

	return {
		"runways": runway_count,
		"taxiway_tiles": taxiway_tiles,
		"taxiway_open_edges": taxiway_open_edges,
		"service_road_tiles": service_road_tiles,
		"service_road_open_edges": service_road_open_edges,
		"service_barrier_candidates": service_barrier_candidates,
		"landside_scenery": get_landside_scenery_layout().size()
	}


func _draw_pavement_tile(
	origin: Vector2i,
	kind: String
) -> void:
	var center := tile_to_world(Vector2(origin.x, origin.y))
	var points := _tile_points(center)
	var outer := TAXIWAY_OUTER
	var inner := TAXIWAY_INNER
	if kind == "service_road":
		outer = SERVICE_ROAD_OUTER
		inner = SERVICE_ROAD_INNER

	draw_colored_polygon(points, outer)

	var inner_points := PackedVector2Array()
	for point_variant in points:
		var point: Vector2 = point_variant
		inner_points.append(
			center + (point - center) * 0.88
		)
	draw_colored_polygon(inner_points, inner)

	# Fixed upper-left sunlight: highlight the upper edges and darken
	# the lower edges so these flat surfaces match the building art.
	draw_line(
		points[0],
		points[1],
		PAVEMENT_HIGHLIGHT,
		1.8
	)
	draw_line(
		points[0],
		points[3],
		Color("ffffff", 0.10),
		1.2
	)
	draw_line(
		points[2],
		points[3],
		PAVEMENT_SHADOW,
		2.0
	)
	draw_line(
		points[1],
		points[2],
		Color("182226", 0.16),
		1.4
	)

	_draw_pavement_edge_detail(
		origin,
		kind,
		points
	)

	var seed := absi(origin.x * 29 + origin.y * 43)
	if seed % 2 == 0:
		var seam_color := (
			Color("b8c1c3", 0.12)
			if kind == "taxiway"
			else Color("eee6dc", 0.14)
		)
		draw_line(
			center + Vector2(-12, 6),
			center + Vector2(12, -6),
			seam_color,
			1.0
		)



func _draw_pavement_edge_detail(
	origin: Vector2i,
	kind: String,
	points: PackedVector2Array
) -> void:
	var directions := [
		[Vector2i(0, -1), points[0], points[1]],
		[Vector2i(1, 0), points[1], points[2]],
		[Vector2i(0, 1), points[2], points[3]],
		[Vector2i(-1, 0), points[3], points[0]]
	]
	for item_variant in directions:
		var item: Array = item_variant
		var direction: Vector2i = item[0]
		var neighbor := origin + direction
		var connected := false
		if kind == "taxiway":
			connected = _taxiway_visually_connects_to(neighbor)
		else:
			connected = _service_road_visually_connects_to(neighbor)
		if connected:
			continue

		var a: Vector2 = item[1]
		var b: Vector2 = item[2]
		var seam_color := (
			Color("9cb671", 0.30)
			if kind == "taxiway"
			else Color("b6aa8e", 0.28)
		)
		draw_line(
			a.lerp(b, 0.08),
			a.lerp(b, 0.92),
			seam_color,
			2.2
		)
		if kind == "service_road" and (
			origin.x * 7 + origin.y * 11
		) % 4 == 0:
			var center := a.lerp(b, 0.5)
			draw_line(
				center + Vector2(-4, 1),
				center + Vector2(4, -1),
				Color("4a5355", 0.42),
				1.4
			)


func _draw_service_road_detail(origin: Vector2i) -> void:
	var center := tile_to_world(Vector2(origin.x, origin.y))
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	var connections := 0
	for direction in directions:
		var neighbor := origin + direction
		if not _service_road_visually_connects_to(neighbor):
			continue
		connections += 1
		var edge_tile := (
			Vector2(origin.x, origin.y)
			+ Vector2(direction.x, direction.y) * 0.48
		)
		draw_dashed_line(
			center,
			tile_to_world(edge_tile),
			Color("f2eee6", 0.85),
			1.8,
			5.0
		)

	if connections == 0:
		draw_line(
			center + Vector2(-8, 4),
			center + Vector2(8, -4),
			Color("f2eee6", 0.75),
			1.8
		)

	# Small amber reflector at junctions reads clearly at default zoom.
	if connections >= 2:
		draw_circle(center, 3.0, Color(0.08, 0.10, 0.10, 0.55))
		draw_circle(center, 1.8, Color("ffd77a"))


func _service_road_visually_connects_to(cell: Vector2i) -> bool:
	var key := _cell_key(cell)
	if not occupied_cells.has(key):
		return false
	var building := _building_by_uid(int(occupied_cells[key]))
	if building.is_empty():
		return false
	return String(building.get("definition_id", "")) == "service_road"


func _draw_taxiway_detail(origin: Vector2i) -> void:
	var center := tile_to_world(Vector2(origin.x, origin.y))
	var connections := get_taxiway_connection_count(origin)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for direction: Vector2i in directions:
		var neighbor: Vector2i = origin + direction
		if not _taxiway_visually_connects_to(neighbor):
			continue
		var edge_tile := (
			Vector2(origin.x, origin.y)
			+ Vector2(direction.x, direction.y) * 0.48
		)
		var edge_world := tile_to_world(edge_tile)
		draw_line(
			center,
			edge_world,
			Color("f0c94c"),
			3.2
		)

		# Blue edge reflectors add airport character without changing
		# the actual taxi network.
		var dir_world := (edge_world - center).normalized()
		if dir_world != Vector2.ZERO:
			var normal := Vector2(-dir_world.y, dir_world.x)
			for side in [-1.0, 1.0]:
				var light_pos := (
					center
					+ dir_world * 18.0
					+ normal * 8.0 * float(side)
				)
				draw_circle(
					light_pos,
					2.5,
					Color(0.03, 0.08, 0.10, 0.72)
				)
				draw_circle(
					light_pos,
					1.4,
					Color("68c7f0")
				)

	if connections == 0:
		draw_line(
			center + Vector2(-8, 4),
			center + Vector2(8, -4),
			Color("f0c94c"),
			3.0
		)
	draw_circle(center, 3.5, Color("f4d866"))

	if connections >= 3:
		draw_circle(
			center,
			8.0,
			Color("f4d866"),
			false,
			1.5
		)


func _draw_airside_props() -> void:
	for building in placed_buildings:
		var id := String(building.get("definition_id", ""))
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		if id == "taxiway":
			var connections := get_taxiway_connection_count(origin)
			if (
				connections >= 2
				and (origin.x + origin.y) % 3 == 0
			):
				_draw_taxiway_sign(
					tile_to_world(Vector2(origin.x, origin.y))
					+ Vector2(18, -8)
				)
		elif id == "service_road":
			var road_connections := 0
			for direction in [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]:
				if _service_road_visually_connects_to(
					origin + direction
				):
					road_connections += 1

			if (origin.x * 3 + origin.y) % 5 == 0:
				var center := tile_to_world(
					Vector2(origin.x, origin.y)
				)
				_draw_safety_cone(center + Vector2(11, 5))
				_draw_safety_cone(center + Vector2(17, 2))
			if (
				road_connections <= 1
				and (origin.x + origin.y) % 2 == 0
			):
				_draw_service_barrier(
					tile_to_world(
						Vector2(origin.x, origin.y)
					) + Vector2(15, -3)
				)



func _draw_service_barrier(base: Vector2) -> void:
	draw_line(
		base + Vector2(-8, 5),
		base + Vector2(-8, -9),
		Color("555f62"),
		2.4
	)
	draw_line(
		base + Vector2(8, 5),
		base + Vector2(8, -9),
		Color("555f62"),
		2.4
	)
	draw_line(
		base + Vector2(-9, -7),
		base + Vector2(9, -7),
		Color("e6e2d8"),
		4.0
	)
	draw_line(
		base + Vector2(-7, -7),
		base + Vector2(-2, -7),
		Color("d95b3f"),
		3.0
	)
	draw_line(
		base + Vector2(3, -7),
		base + Vector2(8, -7),
		Color("d95b3f"),
		3.0
	)
	draw_circle(
		base + Vector2(0, -13),
		3.0,
		Color(0.04, 0.07, 0.07, 0.35)
	)
	draw_circle(
		base + Vector2(0, -13),
		1.6,
		Color("f1c65c")
	)


func _draw_taxiway_sign(base: Vector2) -> void:
	draw_line(
		base + Vector2(0, 4),
		base + Vector2(0, -9),
		Color("536168"),
		2.0
	)
	var sign_rect := Rect2(
		base + Vector2(-12, -18),
		Vector2(24, 10)
	)
	draw_rect(
		sign_rect.grow(2.0),
		Color(0.02, 0.05, 0.06, 0.32),
		true
	)
	draw_rect(sign_rect, Color("173d58"), true)
	draw_rect(sign_rect, Color("f0c94c"), false, 1.5)
	draw_line(
		base + Vector2(-7, -13),
		base + Vector2(7, -13),
		Color("f4dc6b"),
		2.0
	)


func _draw_safety_cone(base: Vector2) -> void:
	draw_circle(
		base + Vector2(1, 2),
		3.3,
		Color(0.02, 0.05, 0.05, 0.20)
	)
	var cone := PackedVector2Array([
		base + Vector2(0, -7),
		base + Vector2(-3, 1),
		base + Vector2(3, 1)
	])
	draw_colored_polygon(cone, Color("ef7f32"))
	draw_line(
		base + Vector2(-2, -2),
		base + Vector2(2, -2),
		Color("f9f4e9"),
		1.5
	)
	draw_line(
		base + Vector2(-4, 2),
		base + Vector2(4, 2),
		Color("bb4e20"),
		2.0
	)


func _draw_runway_hold_short_markings() -> void:
	var seen: Dictionary = {}
	for building in placed_buildings:
		if String(building.get("definition_id", "")) != "taxiway":
			continue

		var taxi_cell: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		for runway_cell in _adjacent_runway_cells(taxi_cell):
			var key := "%s>%s" % [
				_cell_key(taxi_cell),
				_cell_key(runway_cell)
			]
			if seen.has(key):
				continue
			seen[key] = true

			var taxi_center := tile_to_world(
				Vector2(taxi_cell.x, taxi_cell.y)
			)
			var runway_center := tile_to_world(
				Vector2(runway_cell.x, runway_cell.y)
			)
			var direction := (
				runway_center - taxi_center
			).normalized()
			if direction == Vector2.ZERO:
				continue

			var hold := _hold_short_world_position(
				taxi_cell,
				runway_cell
			)
			var runway_uid := _runway_uid_for_cell(
				runway_cell
			)
			var visual_state := get_runway_visual_state(
				runway_uid
			)
			var stop_color := _stop_bar_color_for_state(
				visual_state
			)
			var normal := Vector2(
				-direction.y,
				direction.x
			)
			var half_width := 12.0

			for distance in [-3.0, 1.0]:
				draw_line(
					hold
					+ direction * distance
					- normal * half_width,
					hold
					+ direction * distance
					+ normal * half_width,
					HOLD_SHORT_SOLID,
					2.0
				)

			for side in [-1.0, 1.0]:
				var dash_center: Vector2 = (
					hold
					+ direction * 5.0
					+ normal * 6.0 * float(side)
				)
				draw_line(
					dash_center - normal * 3.0,
					dash_center + normal * 3.0,
					HOLD_SHORT_DASH,
					2.0
				)

			for light_index in range(-2, 3):
				var light_center: Vector2 = (
					hold
					+ normal * float(light_index) * 5.0
					- direction * 6.0
				)
				draw_circle(
					light_center,
					3.0,
					Color(0, 0, 0, 0.55)
				)
				draw_circle(
					light_center,
					1.9,
					stop_color
				)


func set_runway_visual_state(
	runway_uid: int,
	state: Dictionary
) -> void:
	if runway_uid < 0:
		return
	runway_visual_states[runway_uid] = state.duplicate(true)
	queue_redraw()


func get_runway_visual_state(
	runway_uid: int
) -> Dictionary:
	if not runway_visual_states.has(runway_uid):
		return {
			"runway_uid": runway_uid,
			"status": "clear",
			"stop_bar": "off",
			"active_operation": "",
			"waiting_arrivals": 0,
			"waiting_departures": 0,
			"taxiing_departures": 0,
			"arrival_priority": false
		}
	return (
		runway_visual_states[runway_uid] as Dictionary
	).duplicate(true)


func _stop_bar_color_for_state(
	state: Dictionary
) -> Color:
	match String(state.get("stop_bar", "off")):
		"red":
			return STOP_BAR_RED
		"amber":
			return STOP_BAR_AMBER
		_:
			return STOP_BAR_OFF


func _draw_runway_operational_indicators() -> void:
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if definition.is_empty() or not _is_runway_definition(
			definition
		):
			continue

		var runway_uid := int(building.get("uid", -1))
		var state := get_runway_visual_state(runway_uid)
		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		var center := _footprint_center_world(
			building["origin"],
			footprint
		)
		var indicator := center + Vector2(0, -34)
		var color := RUNWAY_CLEAR
		var status := String(state.get("status", "clear"))
		if status.begins_with("occupied"):
			color = RUNWAY_OCCUPIED
		elif bool(state.get("arrival_priority", false)):
			color = RUNWAY_PRIORITY
		elif status in [
			"departure_wait",
			"departure_approaching",
			"runway_spacing"
		]:
			color = STOP_BAR_AMBER

		draw_circle(
			indicator,
			8.5,
			Color(0.03, 0.08, 0.10, 0.85)
		)
		draw_circle(
			indicator,
			5.0,
			color
		)
		draw_circle(
			indicator,
			2.0,
			Color("f7fff9")
		)

		if bool(state.get("arrival_priority", false)):
			draw_arc(
				indicator,
				11.0,
				0.0,
				TAU,
				16,
				RUNWAY_PRIORITY,
				1.5
			)


func _hold_short_world_position(
	taxiway_cell: Vector2i,
	runway_cell: Vector2i
) -> Vector2:
	var taxi_center := tile_to_world(
		Vector2(taxiway_cell.x, taxiway_cell.y)
	)
	var runway_center := tile_to_world(
		Vector2(runway_cell.x, runway_cell.y)
	)
	return taxi_center.lerp(runway_center, 0.58)


func _adjacent_runway_cells(
	taxiway_cell: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in _orthogonal_neighbors(taxiway_cell):
		for building in placed_buildings:
			var definition := BuildingCatalog.get_definition(
				String(building.get("definition_id", ""))
			)
			if definition.is_empty() or not _is_runway_definition(
				definition
			):
				continue
			var footprint := _footprint_for(
				definition,
				int(building.get("rotation", 0))
			)
			if _cells_for(
				building["origin"],
				footprint
			).has(neighbor):
				result.append(neighbor)
				break
	return result


func get_taxiway_connection_count(
	origin: Vector2i
) -> int:
	var count := 0
	for direction in [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]:
		if _taxiway_visually_connects_to(
			origin + direction
		):
			count += 1
	return count


func _taxiway_visually_connects_to(cell: Vector2i) -> bool:
	var key := _cell_key(cell)
	if not occupied_cells.has(key):
		return false

	var building := _building_by_uid(int(occupied_cells[key]))
	if building.is_empty():
		return false

	var id := String(building["definition_id"])
	return (
		id == "taxiway"
		or id.contains("runway")
		or id.contains("stand")
		or id.contains("hangar")
	)


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
			_draw_tile_overlay(
				preview_origin + Vector2i(x, y),
				fill,
				Color("ffffff", 0.52),
				1.4
			)

	var footprint_outline := _footprint_polygon(
		preview_origin,
		footprint
	)
	if footprint_outline.size() >= 4:
		var outline_color := (
			Color("8ff0ae", 0.95)
			if valid
			else Color("ff8c87", 0.95)
		)
		draw_polyline(
			PackedVector2Array([
				footprint_outline[0],
				footprint_outline[1],
				footprint_outline[2],
				footprint_outline[3],
				footprint_outline[0]
			]),
			outline_color,
			2.5
		)

	if _definition_has_world_sprite(definition):
		var shadow_center := (
			_footprint_center_world(
				preview_origin,
				footprint
			)
			+ Vector2(0, 9)
		)
		draw_set_transform(
			shadow_center,
			0.0,
			Vector2(1.0, 0.42)
		)
		draw_circle(
			Vector2.ZERO,
			maxf(
				16.0,
				float(
					footprint.x + footprint.y
				) * 6.5
			),
			Color(0.02, 0.05, 0.06, 0.21)
		)
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)

		var ghost := (
			Color(0.96, 1.0, 0.97, 0.95)
			if valid
			else Color(1.0, 0.78, 0.76, 0.90)
		)
		var lift := Vector2(0, -6)
		if preview_mode in ["move", "stored"]:
			lift = Vector2(0, -10)
		_draw_building_sprite(
			definition,
			preview_origin,
			footprint,
			preview_rotation,
			ghost,
			lift
		)


func _placement_focus_active() -> bool:
	return (
		not preview_building_id.is_empty()
		and preview_origin.x >= 0
		and preview_origin.y >= 0
	)


func is_placement_focus_active() -> bool:
	return _placement_focus_active()


func is_preview_snap_feedback_active() -> bool:
	return preview_snap_elapsed >= 0.0


func get_placement_confirm_feedback_count() -> int:
	return placement_confirm_fx.size()


func _start_preview_snap_fx(
	origin: Vector2i,
	footprint: Vector2i,
	valid: bool
) -> void:
	if origin.x < 0 or origin.y < 0:
		return
	preview_snap_origin = origin
	preview_snap_footprint = footprint
	preview_snap_valid = valid
	preview_snap_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _draw_preview_snap_fx() -> void:
	if preview_snap_elapsed < 0.0:
		return

	var progress := clampf(
		preview_snap_elapsed / PREVIEW_SNAP_FX_DURATION,
		0.0,
		1.0
	)
	var polygon := _footprint_polygon(
		preview_snap_origin,
		preview_snap_footprint
	)
	if polygon.size() < 4:
		return

	var base := (
		Color("8ff0ae")
		if preview_snap_valid
		else Color("ff8c87")
	)
	var alpha := (1.0 - progress) * 0.72
	var width := lerpf(4.2, 1.8, progress)
	draw_polyline(
		PackedVector2Array([
			polygon[0],
			polygon[1],
			polygon[2],
			polygon[3],
			polygon[0]
		]),
		Color(base.r, base.g, base.b, alpha),
		width
	)

	var center := _footprint_center_world(
		preview_snap_origin,
		preview_snap_footprint
	)
	draw_set_transform(
		center,
		0.0,
		Vector2(1.0, 0.42)
	)
	draw_arc(
		Vector2.ZERO,
		lerpf(8.0, 25.0, progress),
		0.0,
		TAU,
		24,
		Color(base.r, base.g, base.b, alpha * 0.85),
		2.0
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _start_placement_confirm_fx(
	origin: Vector2i,
	footprint: Vector2i
) -> void:
	placement_confirm_fx.append({
		"origin": origin,
		"footprint": footprint,
		"elapsed": 0.0
	})
	set_process(true)
	queue_redraw()


func _draw_placement_confirm_fx() -> void:
	for item in placement_confirm_fx:
		var elapsed := float(item.get("elapsed", 0.0))
		var progress := clampf(
			elapsed / PLACEMENT_CONFIRM_FX_DURATION,
			0.0,
			1.0
		)
		var origin: Vector2i = item.get(
			"origin",
			Vector2i.ZERO
		)
		var footprint: Vector2i = item.get(
			"footprint",
			Vector2i.ONE
		)
		var polygon := _footprint_polygon(
			origin,
			footprint
		)
		if polygon.size() < 4:
			continue

		draw_colored_polygon(
			polygon,
			Color(
				0.43,
				0.93,
				0.61,
				(1.0 - progress) * 0.18
			)
		)
		draw_polyline(
			PackedVector2Array([
				polygon[0],
				polygon[1],
				polygon[2],
				polygon[3],
				polygon[0]
			]),
			Color(
				0.54,
				0.96,
				0.69,
				(1.0 - progress) * 0.92
			),
			lerpf(4.0, 1.0, progress)
		)

		var center := _footprint_center_world(
			origin,
			footprint
		)
		draw_set_transform(
			center,
			0.0,
			Vector2(1.0, 0.42)
		)
		draw_arc(
			Vector2.ZERO,
			lerpf(12.0, 42.0, progress),
			0.0,
			TAU,
			30,
			Color(
				0.54,
				0.96,
				0.69,
				(1.0 - progress) * 0.75
			),
			2.2
		)
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)


func _draw_tile_overlay(tile: Vector2i, color: Color, line_color: Color, width: float) -> void:
	var center := tile_to_world(Vector2(tile.x, tile.y))
	var points := _tile_points(center)
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), line_color, width)


func _draw_preview_expansion_outline() -> void:
	var parcel_id := String(
		preview_status.get("locked_parcel_id", "")
	)
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return

	var parcel: Dictionary = parcels[parcel_id]
	var line_color := PREVIEW_EXPANSION_LINE
	if String(
		preview_status.get(
			"locked_parcel_state",
			"available"
		)
	) == "future":
		line_color = PREVIEW_FUTURE_LINE
	var sx := int(parcel.get("px", 0)) * PARCEL_SIZE
	var sy := int(parcel.get("py", 0)) * PARCEL_SIZE
	for y in range(sy, sy + PARCEL_SIZE):
		for x in range(sx, sx + PARCEL_SIZE):
			if not (
				x == sx
				or x == sx + PARCEL_SIZE - 1
				or y == sy
				or y == sy + PARCEL_SIZE - 1
			):
				continue
			var points := _tile_points(
				tile_to_world(Vector2(x, y))
			)
			draw_polyline(
				PackedVector2Array([
					points[0],
					points[1],
					points[2],
					points[3],
					points[0]
				]),
				line_color,
				3.0
			)


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
	var visual_building := _building_at_visual_position(
		world_position
	)
	if not visual_building.is_empty():
		selected_synergy_uid = int(
			visual_building.get("uid", -1)
		)
		_refresh_building_labels()
		queue_redraw()
		building_selected_world.emit(
			visual_building
		)
		return

	var tile := world_to_tile(world_position)
	if not _tile_in_world(tile):
		return

	var key := _cell_key(tile)
	if occupied_cells.has(key):
		var building := get_building(int(occupied_cells[key]))
		if not building.is_empty():
			selected_synergy_uid = int(building.get("uid", -1))
			_refresh_building_labels()
			queue_redraw()
			building_selected_world.emit(building)
			return

	selected_synergy_uid = -1
	_refresh_building_labels()
	queue_redraw()
	var parcel := _parcel_for_tile(tile)
	if not parcel.is_empty():
		select_parcel(String(parcel["id"]))


func clear_building_selection() -> void:
	var changed := (
		selected_synergy_uid >= 0
		or hovered_building_uid >= 0
	)
	selected_synergy_uid = -1
	hovered_building_uid = -1
	if changed:
		queue_redraw()


func select_parcel(parcel_id: String) -> void:
	if not parcels.has(parcel_id):
		return
	selected_id = parcel_id
	_refresh_parcel_labels()
	queue_redraw()
	parcel_selected.emit(
		parcel_id,
		_parcel_progression_data(parcel_id)
	)


func clear_parcel_selection() -> void:
	selected_id = ""
	_refresh_parcel_labels()
	queue_redraw()


func get_selected_parcel() -> Dictionary:
	if selected_id.is_empty() or not parcels.has(selected_id):
		return {}
	return _parcel_progression_data(selected_id)


func get_parcel(parcel_id: String) -> Dictionary:
	return _parcel_progression_data(parcel_id)


func get_expansion_frontier() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for parcel_id_variant in parcels.keys():
		var parcel_id := String(parcel_id_variant)
		var data := _parcel_progression_data(parcel_id)
		if String(
			data.get("progression_state", "")
		) == "available":
			result.append(data)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_level := int(a.get("level", 1))
			var b_level := int(b.get("level", 1))
			if a_level != b_level:
				return a_level < b_level
			return int(a.get("cost", 0)) < int(
				b.get("cost", 0)
			)
	)
	return result


func purchase_parcel(parcel_id: String) -> bool:
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return false

	var data := _parcel_progression_data(parcel_id)
	if String(
		data.get("progression_state", "")
	) != "available":
		return false

	parcels[parcel_id]["owned"] = true
	parcel_unlock_fx[parcel_id] = 0.0
	set_process(true)
	_refresh_parcel_labels()
	queue_redraw()
	if selected_id == parcel_id:
		parcel_selected.emit(
			parcel_id,
			_parcel_progression_data(parcel_id)
		)
	return true


func purchase_selected() -> bool:
	if selected_id.is_empty() or not parcels.has(selected_id):
		return false
	return purchase_parcel(selected_id)


func _refresh_preview_snap_feedback(
	previous_origin: Vector2i,
	previous_rotation: int
) -> void:
	if preview_building_id.is_empty():
		return
	if (
		previous_origin == preview_origin
		and previous_rotation == preview_rotation
	):
		return

	var definition := BuildingCatalog.get_definition(
		preview_building_id
	)
	if definition.is_empty():
		return
	_start_preview_snap_fx(
		preview_origin,
		_footprint_for(
			definition,
			preview_rotation
		),
		bool(preview_status.get("valid", false))
	)


func set_build_preview(
	building_id: String,
	world_position: Vector2,
	rotation: int
) -> Dictionary:
	var previous_origin := preview_origin
	var previous_rotation := preview_rotation
	preview_mode = "build"
	preview_ignore_uid = -1
	preview_stored_uid = -1
	preview_building_id = building_id
	preview_origin = world_to_tile(world_position)
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(
		building_id,
		preview_origin,
		preview_rotation
	)
	_refresh_preview_snap_feedback(
		previous_origin,
		previous_rotation
	)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func begin_move_preview(uid: int) -> Dictionary:
	var eligibility := get_move_eligibility(uid)
	if not bool(eligibility.get("movable", false)):
		return {
			"valid": false,
			"reason": String(
				eligibility.get(
					"reason",
					"This building cannot be moved."
				)
			)
		}

	var building := _building_by_uid(uid)
	if building.is_empty():
		return {
			"valid": false,
			"reason": "Building not found."
		}

	preview_mode = "move"
	preview_ignore_uid = uid
	preview_stored_uid = -1
	preview_building_id = String(
		building.get("definition_id", "")
	)
	preview_origin = building.get(
		"origin",
		Vector2i(-1, -1)
	)
	preview_rotation = int(
		building.get("rotation", 0)
	) % 2
	preview_status = _get_placement_status(
		preview_building_id,
		preview_origin,
		preview_rotation,
		preview_ignore_uid
	)
	preview_status["mode"] = "move"
	preview_status["building_uid"] = uid
	_refresh_building_labels()
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func set_move_preview(
	world_position: Vector2,
	rotation: int
) -> Dictionary:
	if preview_mode != "move" or preview_ignore_uid < 0:
		return {}

	var previous_origin := preview_origin
	var previous_rotation := preview_rotation
	preview_origin = world_to_tile(world_position)
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(
		preview_building_id,
		preview_origin,
		preview_rotation,
		preview_ignore_uid
	)
	preview_status["mode"] = "move"
	preview_status["building_uid"] = preview_ignore_uid
	_refresh_preview_snap_feedback(
		previous_origin,
		previous_rotation
	)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func begin_stored_building_preview(uid: int) -> Dictionary:
	var building := get_stored_building(uid)
	if building.is_empty():
		return {
			"valid": false,
			"reason": "Stored building not found."
		}

	preview_mode = "stored"
	preview_ignore_uid = -1
	preview_stored_uid = uid
	preview_building_id = String(
		building.get("definition_id", "")
	)
	preview_origin = Vector2i(-1, -1)
	preview_rotation = int(
		building.get("rotation", 0)
	) % 2
	preview_status = {}
	queue_redraw()
	return {
		"valid": true,
		"mode": "stored",
		"building_uid": uid
	}


func set_stored_building_preview(
	world_position: Vector2,
	rotation: int
) -> Dictionary:
	if preview_mode != "stored" or preview_stored_uid < 0:
		return {}

	var previous_origin := preview_origin
	var previous_rotation := preview_rotation
	preview_origin = world_to_tile(world_position)
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(
		preview_building_id,
		preview_origin,
		preview_rotation
	)
	preview_status["mode"] = "stored"
	preview_status["building_uid"] = preview_stored_uid
	_refresh_preview_snap_feedback(
		previous_origin,
		previous_rotation
	)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func refresh_build_preview(rotation: int) -> Dictionary:
	if preview_building_id.is_empty():
		return {}
	var previous_origin := preview_origin
	var previous_rotation := preview_rotation
	preview_rotation = rotation % 2
	preview_status = _get_placement_status(
		preview_building_id,
		preview_origin,
		preview_rotation,
		preview_ignore_uid
	)
	if preview_mode == "move":
		preview_status["mode"] = "move"
		preview_status["building_uid"] = preview_ignore_uid
	elif preview_mode == "stored":
		preview_status["mode"] = "stored"
		preview_status["building_uid"] = preview_stored_uid
	_refresh_preview_snap_feedback(
		previous_origin,
		previous_rotation
	)
	queue_redraw()
	build_preview_changed.emit(preview_status.duplicate(true))
	return preview_status.duplicate(true)


func get_build_preview_status() -> Dictionary:
	return preview_status.duplicate(true)


func has_build_preview() -> bool:
	return not preview_building_id.is_empty() and preview_origin.x >= 0 and preview_origin.y >= 0


func clear_build_preview() -> void:
	var was_move := preview_mode == "move"
	preview_building_id = ""
	preview_origin = Vector2i(-1, -1)
	preview_rotation = 0
	preview_status = {}
	preview_mode = "build"
	preview_ignore_uid = -1
	preview_stored_uid = -1
	preview_snap_elapsed = -1.0
	preview_snap_origin = Vector2i(-1, -1)
	if was_move:
		_refresh_building_labels()
	queue_redraw()


func confirm_build_preview() -> Dictionary:
	if preview_mode != "build":
		return {}
	if not bool(preview_status.get("valid", false)):
		return {}

	var definition := BuildingCatalog.get_definition(
		preview_building_id
	)
	var confirmed_origin := preview_origin
	var confirmed_footprint := _footprint_for(
		definition,
		preview_rotation
	)
	var placed := _place_building_internal(
		preview_building_id,
		preview_origin,
		preview_rotation
	)
	_rebuild_occupied_cells()
	_recalculate_airside_network()
	_refresh_building_labels()
	clear_build_preview()
	_start_placement_confirm_fx(
		confirmed_origin,
		confirmed_footprint
	)
	queue_redraw()
	building_placed.emit(placed.duplicate(true))
	return placed


func confirm_stored_building_preview() -> Dictionary:
	if (
		preview_mode != "stored"
		or preview_stored_uid < 0
		or not bool(preview_status.get("valid", false))
	):
		return {}

	for index in range(stored_buildings.size()):
		if int(
			stored_buildings[index].get("uid", -1)
		) != preview_stored_uid:
			continue

		var definition := BuildingCatalog.get_definition(
			preview_building_id
		)
		var confirmed_origin := preview_origin
		var confirmed_footprint := _footprint_for(
			definition,
			preview_rotation
		)
		var restored := stored_buildings[index].duplicate(true)
		restored["origin"] = preview_origin
		restored["rotation"] = preview_rotation
		stored_buildings.remove_at(index)
		placed_buildings.append(restored)

		_rebuild_occupied_cells()
		_recalculate_airside_network()
		clear_build_preview()
		_start_placement_confirm_fx(
			confirmed_origin,
			confirmed_footprint
		)
		_refresh_building_labels()
		queue_redraw()
		building_restored.emit(restored.duplicate(true))
		return restored

	return {}


func confirm_move_preview() -> Dictionary:
	if (
		preview_mode != "move"
		or preview_ignore_uid < 0
		or not bool(preview_status.get("valid", false))
	):
		return {}

	for index in range(placed_buildings.size()):
		if int(
			placed_buildings[index].get("uid", -1)
		) != preview_ignore_uid:
			continue

		var definition := BuildingCatalog.get_definition(
			preview_building_id
		)
		var confirmed_origin := preview_origin
		var confirmed_footprint := _footprint_for(
			definition,
			preview_rotation
		)
		var previous := placed_buildings[index].duplicate(true)
		placed_buildings[index]["origin"] = preview_origin
		placed_buildings[index]["rotation"] = preview_rotation
		var moved := placed_buildings[index].duplicate(true)

		_rebuild_occupied_cells()
		_recalculate_airside_network()
		clear_build_preview()
		_start_placement_confirm_fx(
			confirmed_origin,
			confirmed_footprint
		)
		_refresh_building_labels()
		queue_redraw()
		building_moved.emit(
			moved.duplicate(true),
			previous.duplicate(true)
		)
		return {
			"building": moved,
			"previous": previous
		}

	return {}


func restore_building_position(
	snapshot: Dictionary
) -> Dictionary:
	if snapshot.is_empty():
		return {
			"valid": false,
			"reason": "No move is available to undo."
		}

	var uid := int(snapshot.get("uid", -1))
	var current := _building_by_uid(uid)
	if current.is_empty():
		return {
			"valid": false,
			"reason": "Building no longer exists."
		}

	var definition_id := String(
		snapshot.get("definition_id", "")
	)
	if definition_id != String(
		current.get("definition_id", "")
	):
		return {
			"valid": false,
			"reason": "Building type changed."
		}

	var target_origin: Vector2i = snapshot.get(
		"origin",
		Vector2i(-1, -1)
	)
	var target_rotation := int(
		snapshot.get("rotation", 0)
	) % 2
	var status := _get_placement_status(
		definition_id,
		target_origin,
		target_rotation,
		uid
	)
	if not bool(status.get("valid", false)):
		return status

	for index in range(placed_buildings.size()):
		if int(
			placed_buildings[index].get("uid", -1)
		) != uid:
			continue

		var previous := placed_buildings[index].duplicate(true)
		placed_buildings[index]["origin"] = target_origin
		placed_buildings[index]["rotation"] = target_rotation
		var restored := placed_buildings[index].duplicate(true)

		_rebuild_occupied_cells()
		_recalculate_airside_network()
		_refresh_building_labels()
		_start_placement_confirm_fx(
			target_origin,
			_footprint_for(
				BuildingCatalog.get_definition(
					definition_id
				),
				target_rotation
			)
		)
		queue_redraw()
		building_moved.emit(
			restored.duplicate(true),
			previous.duplicate(true)
		)
		return {
			"valid": true,
			"building": restored,
			"previous": previous
		}

	return {
		"valid": false,
		"reason": "Building could not be restored."
	}


func get_storage_eligibility(uid: int) -> Dictionary:
	var move_state := get_move_eligibility(uid)
	if not bool(move_state.get("movable", false)):
		return {
			"storable": false,
			"reason": String(
				move_state.get(
					"reason",
					"This building cannot be stored."
				)
			)
		}
	return {
		"storable": true,
		"reason": "Stored buildings pause all airport effects."
	}


func store_building(uid: int) -> Dictionary:
	var eligibility := get_storage_eligibility(uid)
	if not bool(eligibility.get("storable", false)):
		return {
			"valid": false,
			"reason": String(
				eligibility.get(
					"reason",
					"This building cannot be stored."
				)
			)
		}

	for index in range(placed_buildings.size()):
		if int(
			placed_buildings[index].get("uid", -1)
		) != uid:
			continue

		if preview_mode == "move" and preview_ignore_uid == uid:
			clear_build_preview()

		var stored := placed_buildings[index].duplicate(true)
		stored["stored_at_unix"] = int(
			Time.get_unix_time_from_system()
		)
		placed_buildings.remove_at(index)
		stored_buildings.append(stored)

		_rebuild_occupied_cells()
		_recalculate_airside_network()
		_refresh_building_labels()
		queue_redraw()
		building_stored.emit(stored.duplicate(true))
		return {
			"valid": true,
			"building": stored
		}

	return {
		"valid": false,
		"reason": "Building not found."
	}


func get_stored_building(uid: int) -> Dictionary:
	for building in stored_buildings:
		if int(building.get("uid", -1)) == uid:
			return building.duplicate(true)
	return {}


func get_stored_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in stored_buildings:
		result.append(building.duplicate(true))
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("uid", -1)) < int(
				b.get("uid", -1)
			)
	)
	return result


func get_move_eligibility(uid: int) -> Dictionary:
	var building := _building_by_uid(uid)
	if building.is_empty():
		return {
			"movable": false,
			"reason": "Building not found."
		}

	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return {
			"movable": false,
			"reason": "Building definition is unavailable."
		}

	var building_id := String(
		definition.get("id", "")
	)
	if (
		not bool(definition.get("movable", true))
		or building_id.contains("runway")
		or building_id == "taxiway"
		or building_id == "service_road"
	):
		return {
			"movable": false,
			"reason": "Airport infrastructure is fixed in place."
		}

	return {
		"movable": true,
		"reason": "Move is free."
	}


func _get_placement_status(
	building_id: String,
	origin: Vector2i,
	rotation: int,
	ignore_uid: int = -1
) -> Dictionary:
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return {
			"valid": false,
			"reason": "Unknown building."
		}

	var footprint := _footprint_for(definition, rotation)
	var cells := _cells_for(origin, footprint)
	var locked_parcels: Dictionary = {}

	for cell in cells:
		if not _tile_in_world(cell):
			return {
				"valid": false,
				"reason": "Outside the airport map.",
				"origin": origin,
				"footprint": footprint
			}

		var cell_key := _cell_key(cell)
		if occupied_cells.has(cell_key):
			var occupying_uid := int(occupied_cells[cell_key])
			if occupying_uid != ignore_uid:
				return {
					"valid": false,
					"reason": "Another airport building already occupies this space.",
					"origin": origin,
					"footprint": footprint
				}

		var parcel := _parcel_for_tile(cell)
		if (
			not parcel.is_empty()
			and not bool(parcel.get("owned", false))
		):
			locked_parcels[
				String(parcel.get("id", ""))
			] = parcel.duplicate(true)

	if not locked_parcels.is_empty():
		var locked_ids: Array = locked_parcels.keys()
		locked_ids.sort()
		var available_ids: Array[String] = []
		for locked_id_variant in locked_ids:
			var locked_id := String(locked_id_variant)
			if _parcel_is_adjacent_to_owned(
				locked_id
			):
				available_ids.append(locked_id)

		var parcel_id := String(locked_ids[0])
		if not available_ids.is_empty():
			available_ids.sort()
			parcel_id = available_ids[0]

		var locked := _parcel_progression_data(
			parcel_id
		)
		var progression_state := String(
			locked.get(
				"progression_state",
				"future"
			)
		)
		var reason := "This land parcel is still locked."
		if progression_state == "future":
			reason = (
				"Expand a neighboring parcel first."
			)

		return {
			"valid": false,
			"reason": reason,
			"origin": origin,
			"footprint": footprint,
			"locked_parcel_id": parcel_id,
			"locked_parcel_level": int(
				locked.get("level", 1)
			),
			"locked_parcel_cost": int(
				locked.get("cost", 0)
			),
			"locked_parcel_count": locked_ids.size(),
			"locked_parcel_state": progression_state,
			"locked_parcel_adjacent": bool(
				locked.get(
					"adjacent_to_owned",
					false
				)
			)
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

	var synergy := get_preview_synergy_summary(
		building_id,
		origin,
		rotation,
		ignore_uid
	)
	if not synergy.is_empty():
		result["synergy"] = synergy

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
		"rotation": rotation % 2,
		"upgrade_level": 1
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


func _parcel_neighbor_ids(parcel_id: String) -> Array[String]:
	var result: Array[String] = []
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return result

	var parcel: Dictionary = parcels[parcel_id]
	var px := int(parcel.get("px", 0))
	var py := int(parcel.get("py", 0))
	for offset in [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]:
		var neighbor := _parcel_at(
			px + offset.x,
			py + offset.y
		)
		if neighbor.is_empty():
			continue
		result.append(
			String(neighbor.get("id", ""))
		)
	return result


func _owned_neighbor_ids(parcel_id: String) -> Array[String]:
	var result: Array[String] = []
	for neighbor_id in _parcel_neighbor_ids(parcel_id):
		if (
			parcels.has(neighbor_id)
			and bool(
				parcels[neighbor_id].get(
					"owned",
					false
				)
			)
		):
			result.append(neighbor_id)
	result.sort()
	return result


func _parcel_is_adjacent_to_owned(
	parcel_id: String
) -> bool:
	return not _owned_neighbor_ids(
		parcel_id
	).is_empty()


func _parcel_progression_data(
	parcel_id: String
) -> Dictionary:
	if parcel_id.is_empty() or not parcels.has(parcel_id):
		return {}

	var result: Dictionary = (
		parcels[parcel_id] as Dictionary
	).duplicate(true)
	var zone := AirportExpansionCatalog.get_zone(parcel_id)
	for key_variant in zone.keys():
		var key := String(key_variant)
		result[key] = zone[key_variant]

	var owned := bool(
		(parcels[parcel_id] as Dictionary).get("owned", false)
	)
	var owned_neighbors := _owned_neighbor_ids(parcel_id)
	var all_neighbors := _parcel_neighbor_ids(parcel_id)
	var state := "future"
	if owned:
		state = "owned"
	elif not owned_neighbors.is_empty():
		state = "available"

	result["owned"] = owned
	result["progression_state"] = state
	result["adjacent_to_owned"] = (
		not owned_neighbors.is_empty()
	)
	result["owned_neighbor_ids"] = owned_neighbors
	result["neighbor_ids"] = all_neighbors
	result["unlock_names"] = AirportExpansionCatalog.get_unlock_names(
		parcel_id
	)
	return result


func _refresh_parcel_labels() -> void:
	for parcel_id_variant in parcels.keys():
		_update_parcel_label(
			String(parcel_id_variant)
		)


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

	var parcel := _parcel_progression_data(id)
	var label: Label = parcel_labels[id]
	var state := String(
		parcel.get("progression_state", "future")
	)
	var zone_name := String(
		parcel.get(
			"name",
			id.replace("_", " ").capitalize()
		)
	)
	label.visible = false
	match state:
		"owned":
			label.visible = false
		"available":
			label.visible = true
			label.text = "%s\nLv %d • %s coins" % [
				zone_name.to_upper(),
				int(parcel.get("level", 1)),
				_format_number(
					int(parcel.get("cost", 0))
				)
			]
			label.add_theme_color_override(
				"font_color",
				Color("ffe19a")
			)
		_:
			label.visible = selected_id == id
			label.text = "%s\nConnect adjacent land" % zone_name.to_upper()
			label.add_theme_color_override(
				"font_color",
				Color("aab8b2")
			)


func _refresh_building_labels() -> void:
	for label in building_labels:
		if is_instance_valid(label):
			label.queue_free()
	building_labels.clear()

	for building in placed_buildings:
		if (
			preview_mode == "move"
			and int(building.get("uid", -1)) == preview_ignore_uid
		):
			continue

		var definition := BuildingCatalog.get_definition(
			String(building["definition_id"])
		)
		if definition.is_empty():
			continue

		var id := String(definition.get("id", ""))
		if id in ["taxiway", "service_road"]:
			continue

		var warning_text := _world_building_warning_text(
			building,
			definition
		)
		if warning_text.is_empty():
			continue

		var label_text := warning_text

		var footprint := _footprint_for(
			definition,
			int(building["rotation"])
		)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(150, 30)
		label.position = (
			_footprint_center_world(
				building["origin"],
				footprint
			)
			- Vector2(75, 39)
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override(
			"font_color",
			Color("ffe19a")
		)
		label.add_theme_color_override(
			"font_shadow_color",
			Color(0, 0, 0, 0.92)
		)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.text = label_text
		add_child(label)
		building_labels.append(label)


func _world_building_warning_text(
	building: Dictionary,
	definition: Dictionary
) -> String:
	var id := String(definition.get("id", ""))
	if (
		id.contains("stand")
		or id.contains("hangar")
	):
		if not _is_airside_building_connected(
			int(building.get("uid", -1))
		):
			return "⚠ TAXIWAY"
	return ""


func _building_label_text(building: Dictionary, definition: Dictionary) -> String:
	var id := String(definition["id"])
	if id.contains("runway"):
		return "RUNWAY  •  " + _size_text(definition)
	if id.contains("fuel"):
		var fuel_label := "FUEL  •  " + _size_text(definition)
		if ServiceUpgradeCatalog.is_upgradeable(id):
			fuel_label += "  •  LV %d" % int(building.get("upgrade_level", 1))
		return fuel_label
	if id.contains("stand"):
		if not _is_airside_building_connected(int(building["uid"])):
			return "STAND  •  " + _size_text(definition) + "  ⚠ TAXIWAY"
		return "STAND  •  " + _size_text(definition) + "  ✓"
	if id.contains("terminal"):
		var terminal_text := "TERMINAL"
		var terminal_synergy := get_building_synergy_summary(
			int(building.get("uid", -1))
		)
		if int(
			terminal_synergy.get("covered_count", 0)
		) > 0:
			terminal_text += "  ✦ %d" % int(
				terminal_synergy.get(
					"covered_count",
					0
				)
			)
		return terminal_text
	if id in ["travel_office", "shuttle_station"]:
		var passenger_text := "PASSENGERS  •  LV %d" % int(
			building.get("upgrade_level", 1)
		)
		var passenger_synergy := get_passenger_synergy(
			int(building.get("uid", -1))
		)
		if bool(
			passenger_synergy.get("active", false)
		):
			passenger_text += "  ✦ +%d%%" % int(
				passenger_synergy.get("bonus_pct", 0)
			)
		return passenger_text
	if id.contains("hangar"):
		if not _is_airside_building_connected(int(building["uid"])):
			return "HANGAR  •  " + _size_text(definition) + "  ⚠ TAXIWAY"
		return "HANGAR  •  " + _size_text(definition) + "  ✓"
	if ServiceUpgradeCatalog.is_upgradeable(id):
		var service_text := "%s  •  LV %d" % [
			String(definition["menu_name"]).to_upper(),
			int(building.get("upgrade_level", 1))
		]
		var coverage := get_service_coverage_summary(
			int(building.get("uid", -1))
		)
		if int(coverage.get("covered_count", 0)) > 0:
			service_text += "  ✦ %d" % int(
				coverage.get("covered_count", 0)
			)
		return service_text
	return String(definition["name"]).to_upper()


func _size_text(definition: Dictionary) -> String:
	var sizes: PackedStringArray = definition["sizes"]
	var result := ""
	for index in range(sizes.size()):
		if index > 0:
			result += "/"
		result += sizes[index]
	return result



func set_hover_world_position(
	world_position: Vector2
) -> void:
	if not preview_building_id.is_empty():
		clear_building_hover()
		return

	var building: Dictionary = {}
	var tile := world_to_tile(world_position)
	if _tile_in_world(tile):
		var key := _cell_key(tile)
		if occupied_cells.has(key):
			building = get_building(
				int(occupied_cells[key])
			)

	if building.is_empty():
		building = _building_at_visual_position(
			world_position
		)

	var next_uid := int(
		building.get("uid", -1)
	)
	if (
		next_uid >= 0
		and not bool(
			get_move_eligibility(next_uid).get(
				"movable",
				false
			)
		)
	):
		next_uid = -1
	if next_uid == hovered_building_uid:
		return
	hovered_building_uid = next_uid
	queue_redraw()


func clear_building_hover() -> void:
	if hovered_building_uid < 0:
		return
	hovered_building_uid = -1
	queue_redraw()


func get_hovered_building_uid() -> int:
	return hovered_building_uid


func _hovered_building_polygon() -> PackedVector2Array:
	if (
		hovered_building_uid < 0
		or hovered_building_uid == selected_synergy_uid
		or not preview_building_id.is_empty()
	):
		return PackedVector2Array()

	var building := _building_by_uid(
		hovered_building_uid
	)
	if building.is_empty():
		return PackedVector2Array()

	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return PackedVector2Array()
	return _footprint_polygon(
		building.get("origin", Vector2i.ZERO),
		_footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
	)


func _draw_hovered_building_outline() -> void:
	var polygon := _hovered_building_polygon()
	if polygon.size() < 4:
		return

	draw_colored_polygon(
		polygon,
		HOVER_BUILDING_FILL
	)
	draw_polyline(
		PackedVector2Array([
			polygon[0],
			polygon[1],
			polygon[2],
			polygon[3],
			polygon[0]
		]),
		HOVER_BUILDING_LINE,
		1.6
	)


func _selected_building_polygon() -> PackedVector2Array:
	if (
		selected_synergy_uid < 0
		or not preview_building_id.is_empty()
	):
		return PackedVector2Array()

	var building := _building_by_uid(
		selected_synergy_uid
	)
	if building.is_empty():
		return PackedVector2Array()

	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return PackedVector2Array()

	var footprint := _footprint_for(
		definition,
		int(building.get("rotation", 0))
	)
	return _footprint_polygon(
		building.get("origin", Vector2i.ZERO),
		footprint
	)


func _draw_selected_building_outline() -> void:
	var polygon := _selected_building_polygon()
	if polygon.size() < 4:
		return

	draw_colored_polygon(
		polygon,
		SELECTED_BUILDING_FILL
	)
	var selected_loop := PackedVector2Array([
		polygon[0],
		polygon[1],
		polygon[2],
		polygon[3],
		polygon[0]
	])
	draw_polyline(
		selected_loop,
		Color(0.02, 0.08, 0.11, 0.72),
		5.2
	)
	draw_polyline(
		selected_loop,
		SELECTED_BUILDING_LINE,
		2.5
	)

	for point_variant in polygon:
		var point: Vector2 = point_variant
		draw_circle(
			point,
			4.2,
			Color(0.03, 0.08, 0.11, 0.55)
		)
		draw_circle(
			point,
			2.4,
			SELECTED_BUILDING_LINE
		)


func _draw_synergy_overlay() -> void:
	var summary: Dictionary = {}
	var source_world := Vector2.ZERO
	var has_source := false

	if (
		not preview_building_id.is_empty()
		and preview_origin.x >= 0
		and preview_origin.y >= 0
	):
		var preview_value = preview_status.get(
			"synergy",
			{}
		)
		if preview_value is Dictionary:
			summary = preview_value
		if not summary.is_empty():
			var definition := BuildingCatalog.get_definition(
				preview_building_id
			)
			if not definition.is_empty():
				source_world = _footprint_center_world(
					preview_origin,
					_footprint_for(
						definition,
						preview_rotation
					)
				)
				has_source = true
	elif selected_synergy_uid >= 0:
		var selected := _building_by_uid(
			selected_synergy_uid
		)
		if not selected.is_empty():
			summary = get_building_synergy_summary(
				selected_synergy_uid
			)
			var definition := BuildingCatalog.get_definition(
				String(
					selected.get(
						"definition_id",
						""
					)
				)
			)
			if (
				not definition.is_empty()
				and not summary.is_empty()
			):
				source_world = _footprint_center_world(
					selected.get(
						"origin",
						Vector2i.ZERO
					),
					_footprint_for(
						definition,
						int(
							selected.get(
								"rotation",
								0
							)
						)
					)
				)
				has_source = true

	if not has_source or summary.is_empty():
		return

	var kind := String(summary.get("kind", ""))
	var color := Color("68d6c5")
	if kind == "service":
		color = Color("f2c566")

	draw_circle(
		source_world,
		18.0,
		Color(
			color.r,
			color.g,
			color.b,
			0.12
		)
	)
	draw_arc(
		source_world,
		20.0,
		0.0,
		TAU,
		28,
		color,
		2.2
	)

	var targets_value = summary.get(
		"target_uids",
		[]
	)
	if not (targets_value is Array):
		return

	for target_uid_variant in targets_value:
		var target_uid := int(target_uid_variant)
		if target_uid < 0:
			continue
		var target := _building_by_uid(target_uid)
		if target.is_empty():
			continue
		var target_definition := (
			BuildingCatalog.get_definition(
				String(
					target.get(
						"definition_id",
						""
					)
				)
			)
		)
		if target_definition.is_empty():
			continue
		var target_world := _footprint_center_world(
			target.get("origin", Vector2i.ZERO),
			_footprint_for(
				target_definition,
				int(target.get("rotation", 0))
			)
		)
		draw_dashed_line(
			source_world,
			target_world,
			color,
			2.0,
			8.0
		)
		draw_circle(
			target_world,
			15.0,
			Color(
				color.r,
				color.g,
				color.b,
				0.12
			)
		)
		draw_arc(
			target_world,
			16.0,
			0.0,
			TAU,
			24,
			color,
			2.0
		)


func get_passenger_synergy(
	building_uid: int
) -> Dictionary:
	return BuildingSynergyResolver.passenger_for_building(
		self,
		building_uid
	)


func get_service_synergy(
	station_uid: int,
	stand_uid: int,
	_service_type: String = ""
) -> Dictionary:
	return BuildingSynergyResolver.service_for(
		self,
		station_uid,
		stand_uid
	)


func get_service_coverage_summary(
	station_uid: int
) -> Dictionary:
	return BuildingSynergyResolver.service_coverage(
		self,
		station_uid
	)


func get_building_synergy_summary(
	building_uid: int
) -> Dictionary:
	return BuildingSynergyResolver.building_summary(
		self,
		building_uid
	)


func get_preview_synergy_summary(
	building_id: String,
	origin: Vector2i,
	rotation: int,
	ignore_uid: int = -1
) -> Dictionary:
	return BuildingSynergyResolver.preview_summary(
		self,
		building_id,
		origin,
		rotation,
		ignore_uid
	)


func clear_synergy_selection() -> void:
	selected_synergy_uid = -1
	_refresh_building_labels()
	queue_redraw()


func get_airside_status() -> Dictionary:
	return airside_status.duplicate(true)


func get_compatible_service_buildings(
	service_type: String,
	aircraft_size: String
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building["definition_id"])
		)
		if definition.is_empty():
			continue
		if not _definition_supports_size(definition, aircraft_size):
			continue

		var building_id := String(building.get("definition_id", ""))
		var level := int(building.get("upgrade_level", 1))
		var effective := ServiceUpgradeCatalog.effective_service_stats(building_id, service_type, level)
		var service_speed := 0.0
		var vehicle_capacity := 0
		var legacy_service := String(definition.get("service", ""))
		if not effective.is_empty():
			service_speed = float(effective.get("service_speed", 1.0))
			vehicle_capacity = int(effective.get("vehicle_capacity", 1))
		elif legacy_service == service_type:
			service_speed = float(definition.get("service_speed", 1.0))
			vehicle_capacity = int(definition.get("vehicle_capacity", 1))
		else:
			var services: Dictionary = definition.get("services", {})
			if not services.has(service_type):
				continue
			var service_data: Dictionary = services[service_type]
			service_speed = float(service_data.get("service_speed", 1.0))
			vehicle_capacity = int(service_data.get("vehicle_capacity", 1))

		var footprint := _footprint_for(
			definition,
			int(building["rotation"])
		)
		results.append({
			"uid": int(building["uid"]),
			"definition_id": building_id,
			"upgrade_level": level,
			"world_position": _footprint_center_world(
				building["origin"],
				footprint
			),
			"service_type": service_type,
			"service_speed": maxf(service_speed, 0.1),
			"vehicle_capacity": maxi(vehicle_capacity, 1),
			"sizes": definition.get("sizes", PackedStringArray())
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("service_speed", 1.0)) > float(
			b.get("service_speed", 1.0)
		)
	)
	return results


func get_best_service_building(service_type: String, aircraft_size: String) -> Dictionary:
	var compatible := get_compatible_service_buildings(service_type, aircraft_size)
	if compatible.is_empty():
		return {}
	return compatible[0].duplicate(true)


func get_service_route(station_uid: int, stand_uid: int) -> PackedVector2Array:
	var station := _building_by_uid(station_uid)
	var stand := _building_by_uid(stand_uid)
	if station.is_empty() or stand.is_empty():
		return PackedVector2Array()

	var station_definition := BuildingCatalog.get_definition(String(station["definition_id"]))
	var stand_definition := BuildingCatalog.get_definition(String(stand["definition_id"]))
	if station_definition.is_empty() or stand_definition.is_empty():
		return PackedVector2Array()

	var road_cells: Dictionary = {}
	for building in placed_buildings:
		if String(building["definition_id"]) != "service_road":
			continue
		var road_definition := BuildingCatalog.get_definition("service_road")
		var footprint := _footprint_for(road_definition, int(building["rotation"]))
		for cell in _cells_for(building["origin"], footprint):
			road_cells[_cell_key(cell)] = cell

	if road_cells.is_empty():
		return PackedVector2Array()

	var station_footprint := _footprint_for(station_definition, int(station["rotation"]))
	var stand_footprint := _footprint_for(stand_definition, int(stand["rotation"]))
	var station_cells := _cells_for(station["origin"], station_footprint)
	var stand_cells := _cells_for(stand["origin"], stand_footprint)

	var starts := _adjacent_cells_in_set(station_cells, road_cells)
	var goals := _adjacent_cells_in_set(stand_cells, road_cells)
	if starts.is_empty() or goals.is_empty():
		return PackedVector2Array()

	var road_path := _road_path_between(starts, goals, road_cells)
	if road_path.is_empty():
		return PackedVector2Array()

	var points := PackedVector2Array()
	points.append(_footprint_center_world(station["origin"], station_footprint))
	for cell in road_path:
		points.append(tile_to_world(Vector2(cell.x, cell.y)))
	points.append(_footprint_center_world(stand["origin"], stand_footprint))
	return points


func _adjacent_cells_in_set(cells: Array[Vector2i], allowed: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for cell in cells:
		for neighbor in _orthogonal_neighbors(cell):
			var key := _cell_key(neighbor)
			if allowed.has(key) and not seen.has(key):
				seen[key] = true
				result.append(neighbor)
	return result


func _road_path_between(
	starts: Array[Vector2i],
	goals: Array[Vector2i],
	allowed: Dictionary
) -> Array[Vector2i]:
	var goal_keys: Dictionary = {}
	for goal in goals:
		goal_keys[_cell_key(goal)] = true

	var queue: Array[Vector2i] = []
	var parent: Dictionary = {}
	for start in starts:
		var key := _cell_key(start)
		if parent.has(key):
			continue
		parent[key] = Vector2i(-999, -999)
		queue.append(start)

	var cursor := 0
	var found := Vector2i(-1, -1)
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1

		if goal_keys.has(_cell_key(current)):
			found = current
			break

		for neighbor in _orthogonal_neighbors(current):
			var key := _cell_key(neighbor)
			if allowed.has(key) and not parent.has(key):
				parent[key] = current
				queue.append(neighbor)

	if found.x < 0:
		return []

	var reversed: Array[Vector2i] = []
	var current := found
	while current != Vector2i(-999, -999):
		reversed.append(current)
		var key := _cell_key(current)
		if not parent.has(key):
			break
		current = parent[key]
	reversed.reverse()
	return reversed


func _definition_supports_size(definition: Dictionary, aircraft_size: String) -> bool:
	var sizes: PackedStringArray = definition.get("sizes", PackedStringArray())
	return sizes.has(aircraft_size)


func get_departure_routes(
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var connected_uids: Array = airside_status.get(
		"connected_uids",
		[]
	)
	if connected_uids.is_empty():
		return routes

	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building["definition_id"])
		)
		if (
			definition.is_empty()
			or not String(
				definition["id"]
			).contains("stand")
		):
			continue
		if not _definition_supports_size(
			definition,
			aircraft_size
		):
			continue

		var stand_uid := int(building["uid"])
		if not connected_uids.has(stand_uid):
			continue

		var options := get_departure_route_options_for_stand(
			stand_uid,
			aircraft_size
		)
		if not options.is_empty():
			routes.append(
				options[0].duplicate(true)
			)

	return routes


func get_departure_route_options(
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var connected_uids: Array = airside_status.get(
		"connected_uids",
		[]
	)
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if (
			definition.is_empty()
			or not String(
				definition.get("id", "")
			).contains("stand")
		):
			continue
		if not _definition_supports_size(
			definition,
			aircraft_size
		):
			continue

		var stand_uid := int(
			building.get("uid", -1)
		)
		if not connected_uids.has(stand_uid):
			continue

		for option in get_departure_route_options_for_stand(
			stand_uid,
			aircraft_size
		):
			result.append(option)

	return result


func get_departure_route_options_for_stand(
	stand_uid: int,
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stand := _building_by_uid(stand_uid)
	if stand.is_empty():
		return result

	var definition := BuildingCatalog.get_definition(
		String(stand.get("definition_id", ""))
	)
	if (
		definition.is_empty()
		or not String(
			definition.get("id", "")
		).contains("stand")
		or not _definition_supports_size(
			definition,
			aircraft_size
		)
	):
		return result

	var connected_uids: Array = airside_status.get(
		"connected_uids",
		[]
	)
	if not connected_uids.has(stand_uid):
		return result

	var footprint := _footprint_for(
		definition,
		int(stand.get("rotation", 0))
	)
	var stand_cells := _cells_for(
		stand["origin"],
		footprint
	)
	var start_taxiway := _first_adjacent_reachable_taxiway(
		stand_cells
	)
	if start_taxiway.x < 0:
		return result

	var stand_position := _footprint_center_world(
		stand["origin"],
		footprint
	)

	for runway in placed_buildings:
		var runway_definition := BuildingCatalog.get_definition(
			String(runway.get("definition_id", ""))
		)
		if (
			runway_definition.is_empty()
			or not _is_runway_definition(
				runway_definition
			)
			or not _definition_supports_size(
				runway_definition,
				aircraft_size
			)
		):
			continue

		var runway_uid := int(
			runway.get("uid", -1)
		)
		var taxi_path := _taxiway_path_to_specific_runway(
			start_taxiway,
			runway_uid,
			aircraft_size
		)
		if taxi_path.is_empty():
			continue

		var last_taxi_cell: Vector2i = taxi_path[
			taxi_path.size() - 1
		]
		var runway_entry := _adjacent_runway_cell_for_uid(
			last_taxi_cell,
			runway_uid,
			aircraft_size
		)
		if runway_entry.x < 0:
			continue

		var runway_exit := _farthest_cell_on_runway_uid(
			runway_entry,
			runway_uid,
			aircraft_size
		)
		var hold_short_position := _hold_short_world_position(
			last_taxi_cell,
			runway_entry
		)

		var points := PackedVector2Array()
		points.append(stand_position)
		var taxi_distance := 0.0
		var previous_point := stand_position
		for taxi_cell in taxi_path:
			var taxi_point := tile_to_world(
				Vector2(taxi_cell.x, taxi_cell.y)
			)
			points.append(taxi_point)
			taxi_distance += previous_point.distance_to(
				taxi_point
			)
			previous_point = taxi_point

		points.append(hold_short_position)
		taxi_distance += previous_point.distance_to(
			hold_short_position
		)
		points.append(
			tile_to_world(
				Vector2(
					runway_entry.x,
					runway_entry.y
				)
			)
		)
		if runway_exit != runway_entry:
			points.append(
				tile_to_world(
					Vector2(
						runway_exit.x,
						runway_exit.y
					)
				)
			)

		result.append({
			"stand_uid": stand_uid,
			"stand_definition_id": String(
				stand.get("definition_id", "")
			),
			"stand_world_position": stand_position,
			"runway_uid": runway_uid,
			"runway_definition_id": String(
				runway.get("definition_id", "")
			),
			"hold_short_position": hold_short_position,
			"taxi_distance": taxi_distance,
			"route": points
		})

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_distance := float(
				a.get("taxi_distance", 0.0)
			)
			var b_distance := float(
				b.get("taxi_distance", 0.0)
			)
			if absf(a_distance - b_distance) > 0.01:
				return a_distance < b_distance
			return int(
				a.get("runway_uid", -1)
			) < int(
				b.get("runway_uid", -1)
			)
	)
	return result


func get_first_departure_route(
	aircraft_size: String = "S"
) -> PackedVector2Array:
	var routes: Array[Dictionary] = get_departure_routes(
		aircraft_size
	)
	if routes.is_empty():
		return PackedVector2Array()
	return routes[0]["route"] as PackedVector2Array


func get_departure_route_for_stand(
	stand_uid: int,
	aircraft_size: String = "S"
) -> Dictionary:
	var options := get_departure_route_options_for_stand(
		stand_uid,
		aircraft_size
	)
	if options.is_empty():
		return {}
	return options[0].duplicate(true)


func get_arrival_routes(
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var arrivals: Array[Dictionary] = []
	var departures: Array[Dictionary] = get_departure_routes(
		aircraft_size
	)
	for departure in departures:
		var arrival := _arrival_route_from_departure(
			departure
		)
		if not arrival.is_empty():
			arrivals.append(arrival)
	return arrivals


func get_arrival_route_options(
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var arrivals: Array[Dictionary] = []
	for departure in get_departure_route_options(
		aircraft_size
	):
		var arrival := _arrival_route_from_departure(
			departure
		)
		if not arrival.is_empty():
			arrivals.append(arrival)
	return arrivals


func get_arrival_route_options_for_stand(
	stand_uid: int,
	aircraft_size: String = "S"
) -> Array[Dictionary]:
	var arrivals: Array[Dictionary] = []
	for departure in get_departure_route_options_for_stand(
		stand_uid,
		aircraft_size
	):
		var arrival := _arrival_route_from_departure(
			departure
		)
		if not arrival.is_empty():
			arrivals.append(arrival)
	return arrivals


func _arrival_route_from_departure(
	departure: Dictionary
) -> Dictionary:
	var departure_points: PackedVector2Array = departure.get(
		"route",
		PackedVector2Array()
	)
	if departure_points.size() < 4:
		return {}

	var arrival_points := PackedVector2Array()
	for index in range(
		departure_points.size() - 1,
		-1,
		-1
	):
		arrival_points.append(
			departure_points[index]
		)

	return {
		"stand_uid": int(
			departure.get("stand_uid", -1)
		),
		"stand_definition_id": String(
			departure.get(
				"stand_definition_id",
				""
			)
		),
		"stand_world_position": departure.get(
			"stand_world_position",
			Vector2.ZERO
		),
		"runway_uid": int(
			departure.get("runway_uid", -1)
		),
		"runway_definition_id": String(
			departure.get(
				"runway_definition_id",
				""
			)
		),
		"hold_short_position": departure.get(
			"hold_short_position",
			Vector2.ZERO
		),
		"taxi_distance": float(
			departure.get("taxi_distance", 0.0)
		),
		"route": arrival_points
	}


func _first_adjacent_reachable_taxiway(cells: Array[Vector2i]) -> Vector2i:
	var reachable_keys: Array = airside_status.get("reachable_taxiway_cells", [])
	var reachable: Dictionary = {}
	for key in reachable_keys:
		reachable[String(key)] = true

	for cell in cells:
		for neighbor in _orthogonal_neighbors(cell):
			if reachable.has(_cell_key(neighbor)):
				return neighbor
	return Vector2i(-1, -1)


func _taxiway_path_to_specific_runway(
	start: Vector2i,
	runway_uid: int,
	aircraft_size: String = ""
) -> Array[Vector2i]:
	var reachable_keys: Array = airside_status.get(
		"reachable_taxiway_cells",
		[]
	)
	var reachable: Dictionary = {}
	for key in reachable_keys:
		reachable[String(key)] = true

	if not reachable.has(_cell_key(start)):
		return []

	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {}
	parent[_cell_key(start)] = Vector2i(-999, -999)
	var cursor := 0
	var goal := Vector2i(-1, -1)

	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1

		if _adjacent_runway_cell_for_uid(
			current,
			runway_uid,
			aircraft_size
		).x >= 0:
			goal = current
			break

		for neighbor in _orthogonal_neighbors(current):
			var key := _cell_key(neighbor)
			if (
				reachable.has(key)
				and not parent.has(key)
			):
				parent[key] = current
				queue.append(neighbor)

	if goal.x < 0:
		return []

	var reversed: Array[Vector2i] = []
	var cursor_cell := goal
	while cursor_cell != Vector2i(-999, -999):
		reversed.append(cursor_cell)
		var key := _cell_key(cursor_cell)
		if not parent.has(key):
			break
		cursor_cell = parent[key]

	reversed.reverse()
	return reversed


func _taxiway_path_to_runway(start: Vector2i, aircraft_size: String = "") -> Array[Vector2i]:
	var reachable_keys: Array = airside_status.get("reachable_taxiway_cells", [])
	var reachable: Dictionary = {}
	for key in reachable_keys:
		reachable[String(key)] = true

	if not reachable.has(_cell_key(start)):
		return []

	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {}
	parent[_cell_key(start)] = Vector2i(-999, -999)
	var cursor := 0
	var goal := Vector2i(-1, -1)

	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1

		if _adjacent_runway_cell(current, aircraft_size).x >= 0:
			goal = current
			break

		for neighbor in _orthogonal_neighbors(current):
			var key := _cell_key(neighbor)
			if reachable.has(key) and not parent.has(key):
				parent[key] = current
				queue.append(neighbor)

	if goal.x < 0:
		return []

	var reversed: Array[Vector2i] = []
	var cursor_cell := goal
	while cursor_cell != Vector2i(-999, -999):
		reversed.append(cursor_cell)
		var key := _cell_key(cursor_cell)
		if not parent.has(key):
			break
		cursor_cell = parent[key]

	reversed.reverse()
	return reversed


func _adjacent_runway_cell_for_uid(
	taxiway: Vector2i,
	runway_uid: int,
	aircraft_size: String = ""
) -> Vector2i:
	var runway := _building_by_uid(runway_uid)
	if runway.is_empty():
		return Vector2i(-1, -1)

	var definition := BuildingCatalog.get_definition(
		String(runway.get("definition_id", ""))
	)
	if (
		definition.is_empty()
		or not _is_runway_definition(definition)
	):
		return Vector2i(-1, -1)
	if (
		not aircraft_size.is_empty()
		and not _definition_supports_size(
			definition,
			aircraft_size
		)
	):
		return Vector2i(-1, -1)

	var footprint := _footprint_for(
		definition,
		int(runway.get("rotation", 0))
	)
	var runway_cells := _cells_for(
		runway["origin"],
		footprint
	)
	for neighbor in _orthogonal_neighbors(taxiway):
		if runway_cells.has(neighbor):
			return neighbor
	return Vector2i(-1, -1)


func _adjacent_runway_cell(taxiway: Vector2i, aircraft_size: String = "") -> Vector2i:
	for neighbor in _orthogonal_neighbors(taxiway):
		for building in placed_buildings:
			var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
			if definition.is_empty() or not _is_runway_definition(definition):
				continue
			if not aircraft_size.is_empty() and not _definition_supports_size(definition, aircraft_size):
				continue
			var footprint := _footprint_for(definition, int(building["rotation"]))
			for runway_cell in _cells_for(building["origin"], footprint):
				if runway_cell == neighbor:
					return runway_cell
	return Vector2i(-1, -1)


func _runway_uid_for_cell(cell: Vector2i, aircraft_size: String = "") -> int:
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty() or not _is_runway_definition(definition):
			continue
		if not aircraft_size.is_empty() and not _definition_supports_size(definition, aircraft_size):
			continue
		var footprint := _footprint_for(definition, int(building["rotation"]))
		if _cells_for(building["origin"], footprint).has(cell):
			return int(building["uid"])
	return -1


func _farthest_cell_on_runway_uid(
	entry: Vector2i,
	runway_uid: int,
	aircraft_size: String = ""
) -> Vector2i:
	var runway := _building_by_uid(runway_uid)
	if runway.is_empty():
		return entry

	var definition := BuildingCatalog.get_definition(
		String(runway.get("definition_id", ""))
	)
	if (
		definition.is_empty()
		or not _is_runway_definition(definition)
	):
		return entry
	if (
		not aircraft_size.is_empty()
		and not _definition_supports_size(
			definition,
			aircraft_size
		)
	):
		return entry

	var footprint := _footprint_for(
		definition,
		int(runway.get("rotation", 0))
	)
	var cells := _cells_for(
		runway["origin"],
		footprint
	)
	if not cells.has(entry):
		return entry

	var farthest := entry
	var best_distance := -1
	for cell in cells:
		var distance := (
			absi(cell.x - entry.x)
			+ absi(cell.y - entry.y)
		)
		if distance > best_distance:
			best_distance = distance
			farthest = cell
	return farthest


func _farthest_cell_on_same_runway(entry: Vector2i, aircraft_size: String = "") -> Vector2i:
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(String(building["definition_id"]))
		if definition.is_empty() or not _is_runway_definition(definition):
			continue
		if not aircraft_size.is_empty() and not _definition_supports_size(definition, aircraft_size):
			continue

		var footprint := _footprint_for(definition, int(building["rotation"]))
		var cells := _cells_for(building["origin"], footprint)
		if not cells.has(entry):
			continue

		var farthest := entry
		var best_distance := -1
		for cell in cells:
			var distance := absi(cell.x - entry.x) + absi(cell.y - entry.y)
			if distance > best_distance:
				best_distance = distance
				farthest = cell
		return farthest

	return entry




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




func get_building(uid: int) -> Dictionary:
	for building in placed_buildings:
		if int(building.get("uid", -1)) == uid:
			return building.duplicate(true)
	return {}


func export_airport_storage() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in stored_buildings:
		var origin: Vector2i = building.get(
			"origin",
			Vector2i(-1, -1)
		)
		result.append({
			"uid": int(building.get("uid", -1)),
			"definition_id": String(
				building.get("definition_id", "")
			),
			"x": origin.x,
			"y": origin.y,
			"rotation": int(
				building.get("rotation", 0)
			) % 2,
			"upgrade_level": maxi(
				int(building.get("upgrade_level", 1)),
				1
			),
			"stored_at_unix": int(
				building.get("stored_at_unix", 0)
			)
		})
	return result


func export_airport_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in placed_buildings:
		var origin: Vector2i = building.get(
			"origin",
			Vector2i.ZERO
		)
		result.append({
			"uid": int(building.get("uid", -1)),
			"definition_id": String(
				building.get("definition_id", "")
			),
			"x": origin.x,
			"y": origin.y,
			"rotation": int(
				building.get("rotation", 0)
			) % 2,
			"upgrade_level": maxi(
				int(building.get("upgrade_level", 1)),
				1
			)
		})
	return result


func export_owned_parcels() -> Array[String]:
	var result: Array[String] = []
	for parcel_id in parcels.keys():
		if bool(
			(parcels[parcel_id] as Dictionary).get(
				"owned",
				false
			)
		):
			result.append(String(parcel_id))
	result.sort()
	return result


func apply_saved_airport_layout(
	saved_layout: Array,
	saved_owned_parcels: Array,
	saved_storage: Array = []
) -> bool:
	var owned: Dictionary = {"home": true}
	for parcel_id_variant in saved_owned_parcels:
		var parcel_id := String(parcel_id_variant)
		if parcels.has(parcel_id):
			owned[parcel_id] = true

	var restored: Array[Dictionary] = []
	var restored_storage: Array[Dictionary] = []
	var restored_cells: Dictionary = {}
	var seen_uids: Dictionary = {}
	var max_uid := 0

	if not saved_layout.is_empty():
		for item_variant in saved_layout:
			if not (item_variant is Dictionary):
				return false
			var item: Dictionary = item_variant
			var definition_id := String(
				item.get("definition_id", "")
			)
			var definition := BuildingCatalog.get_definition(
				definition_id
			)
			var uid := int(item.get("uid", -1))
			if definition.is_empty() or uid <= 0 or seen_uids.has(uid):
				return false

			var origin := Vector2i(
				int(item.get("x", -1)),
				int(item.get("y", -1))
			)
			var rotation := int(
				item.get("rotation", 0)
			) % 2
			var footprint := _footprint_for(
				definition,
				rotation
			)
			for cell in _cells_for(origin, footprint):
				if not _tile_in_world(cell):
					return false
				var parcel := _parcel_for_tile(cell)
				if (
					parcel.is_empty()
					or not owned.has(
						String(parcel.get("id", ""))
					)
				):
					return false
				var key := _cell_key(cell)
				if restored_cells.has(key):
					return false
				restored_cells[key] = uid

			seen_uids[uid] = true
			max_uid = maxi(max_uid, uid)
			restored.append({
				"uid": uid,
				"definition_id": definition_id,
				"origin": origin,
				"rotation": rotation,
				"upgrade_level": maxi(
					int(item.get("upgrade_level", 1)),
					1
				)
			})

	if not saved_storage.is_empty():
		for item_variant in saved_storage:
			if not (item_variant is Dictionary):
				return false
			var item: Dictionary = item_variant
			var definition_id := String(
				item.get("definition_id", "")
			)
			var definition := BuildingCatalog.get_definition(
				definition_id
			)
			var uid := int(item.get("uid", -1))
			if (
				definition.is_empty()
				or uid <= 0
				or seen_uids.has(uid)
			):
				return false

			seen_uids[uid] = true
			max_uid = maxi(max_uid, uid)
			restored_storage.append({
				"uid": uid,
				"definition_id": definition_id,
				"origin": Vector2i(
					int(item.get("x", -1)),
					int(item.get("y", -1))
				),
				"rotation": int(
					item.get("rotation", 0)
				) % 2,
				"upgrade_level": maxi(
					int(item.get("upgrade_level", 1)),
					1
				),
				"stored_at_unix": int(
					item.get("stored_at_unix", 0)
				)
			})

	for parcel_id in parcels.keys():
		parcels[parcel_id]["owned"] = (
			String(parcel_id) == "home"
			or owned.has(String(parcel_id))
		)
	_refresh_parcel_labels()

	if (
		not saved_layout.is_empty()
		or not saved_storage.is_empty()
	):
		placed_buildings = restored
		stored_buildings = restored_storage
		next_building_uid = max_uid + 1

	_rebuild_occupied_cells()
	_recalculate_airside_network()
	_refresh_building_labels()
	queue_redraw()
	return true


func get_building_key(building: Dictionary) -> String:
	if building.is_empty():
		return ""
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	return "%s@%d,%d" % [
		String(building.get("definition_id", "")),
		origin.x,
		origin.y
	]


func get_runway_buildings(
	aircraft_size: String = ""
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if (
			definition.is_empty()
			or not _is_runway_definition(definition)
		):
			continue
		if (
			not aircraft_size.is_empty()
			and not _definition_supports_size(
				definition,
				aircraft_size
			)
		):
			continue

		var footprint := _footprint_for(
			definition,
			int(building.get("rotation", 0))
		)
		result.append({
			"uid": int(building.get("uid", -1)),
			"building_key": get_building_key(building),
			"definition_id": String(
				building.get("definition_id", "")
			),
			"upgrade_level": int(
				building.get("upgrade_level", 1)
			),
			"world_position": _footprint_center_world(
				building["origin"],
				footprint
			),
			"sizes": definition.get(
				"sizes",
				PackedStringArray()
			)
		})
	return result


func get_air_traffic_control_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if not bool(
			definition.get("air_traffic_control", false)
		):
			continue

		var info := building.duplicate(true)
		var building_id := String(
			building.get("definition_id", "")
		)
		var level := int(
			building.get("upgrade_level", 1)
		)
		info["separation_multiplier"] = (
			AirTrafficUpgradeCatalog.separation_multiplier(
				building_id,
				level
			)
		)
		result.append(info)
	return result


func get_best_air_traffic_control() -> Dictionary:
	var best: Dictionary = {}
	var best_multiplier := 1.0
	for building in get_air_traffic_control_buildings():
		var multiplier := float(
			building.get(
				"separation_multiplier",
				1.0
			)
		)
		if best.is_empty() or multiplier < best_multiplier:
			best = building.duplicate(true)
			best_multiplier = multiplier
	return best


func get_passenger_generator_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in placed_buildings:
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if bool(definition.get("passenger_generator", false)):
			result.append(building.duplicate(true))
	return result


func set_building_upgrade_level(uid: int, level: int) -> bool:
	for index in range(placed_buildings.size()):
		if int(placed_buildings[index].get("uid", -1)) != uid:
			continue
		placed_buildings[index]["upgrade_level"] = maxi(level, 1)
		_refresh_building_labels()
		queue_redraw()
		return true
	return false


func apply_saved_building_upgrades(saved: Dictionary) -> void:
	for index in range(placed_buildings.size()):
		var building: Dictionary = placed_buildings[index]
		var key := get_building_key(building)
		if key.is_empty() or not saved.has(key):
			continue
		placed_buildings[index]["upgrade_level"] = maxi(
			int(saved[key]),
			1
		)
	_refresh_building_labels()
	queue_redraw()

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
