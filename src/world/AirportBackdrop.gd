class_name AirportBackdrop
extends Node2D

# A scene-level background that sits beneath AirportGrid. This deliberately
# owns only the world surrounding the playable airport. Placement terrain,
# parcels and building footprints remain AirportGrid responsibilities so the
# later terrain-art pass can evolve independently.

const WORLD_RECT := Rect2(-2200, -1000, 4400, 3200)
const WORLD_GRASS := Color("426f43")
const WORLD_GRASS_DARK := Color("335b3b")
const WORLD_GRASS_LIGHT := Color("628e50")
const AIRPORT_LAND := Color("719c58")
const AIRPORT_LAND_EDGE := Color("567c4a")
const FIELD_SOFT := Color("8fa966", 0.24)
const ROAD_SHOULDER := Color("a69e8d")
const ROAD_SURFACE := Color("5b5f5c")
const ROAD_LINE := Color("dfcc77", 0.76)

const FIELD_TEXTURE_PATH := "res://assets/production/environment_v2/distant_fields_v2.svg"
const TREE_TEXTURE_PATH := "res://assets/production/environment_v2/tree_cluster_v2.svg"
const CONIFER_TEXTURE_PATH := "res://assets/production/environment_v2/conifer_cluster_v2.svg"
const PARKING_TEXTURE_PATH := "res://assets/production/environment_v2/parking_lot_v2.svg"
const HEDGE_TEXTURE_PATH := "res://assets/production/environment_v2/hedge_strip_v2.svg"
const ENTRANCE_TEXTURE_PATH := "res://assets/production/environment_v2/entrance_sign_v2.svg"

var field_texture: Texture2D
var tree_texture: Texture2D
var conifer_texture: Texture2D
var parking_texture: Texture2D
var hedge_texture: Texture2D
var entrance_texture: Texture2D


func _ready() -> void:
	z_index = -200
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	field_texture = _load_texture(FIELD_TEXTURE_PATH)
	tree_texture = _load_texture(TREE_TEXTURE_PATH)
	conifer_texture = _load_texture(CONIFER_TEXTURE_PATH)
	parking_texture = _load_texture(PARKING_TEXTURE_PATH)
	hedge_texture = _load_texture(HEDGE_TEXTURE_PATH)
	entrance_texture = _load_texture(ENTRANCE_TEXTURE_PATH)
	queue_redraw()


func _load_texture(path: String) -> Texture2D:
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _draw() -> void:
	draw_rect(WORLD_RECT, WORLD_GRASS, true)
	_draw_landscape_bands()
	_draw_airport_landmass()
	_draw_distant_access_network()
	_draw_environment_scenery()
	_draw_depth_shading()


func get_visual_snapshot() -> Dictionary:
	return {
		"world_rect": WORLD_RECT,
		"airport_land_points": _airport_land_polygon().size(),
		"field_groups": 4,
		"tree_groups": 6,
		"parking_groups": 2,
		"road_sections": 2,
		"production_environment_v2": true,
		"independent_from_airport_grid": true
	}


func _airport_land_polygon() -> PackedVector2Array:
	# AirportGrid's 24 x 24 isometric build area is roughly a 1536 x 768
	# diamond. This larger shoulder remains visible around its edge and makes
	# the playable airport feel embedded in a continuous landscape.
	return PackedVector2Array([
		Vector2(0, -150),
		Vector2(930, 365),
		Vector2(0, 900),
		Vector2(-930, 365)
	])


func _draw_airport_landmass() -> void:
	var polygon := _airport_land_polygon()
	var shadow := PackedVector2Array()
	for point_variant in polygon:
		var point: Vector2 = point_variant
		shadow.append(point + Vector2(12, 18))
	draw_colored_polygon(
		shadow,
		Color(0.03, 0.07, 0.04, 0.24)
	)

	var outer := PackedVector2Array()
	var center := Vector2(0, 370)
	for point_variant in polygon:
		var point: Vector2 = point_variant
		outer.append(center + (point - center) * 1.035)
	draw_colored_polygon(outer, AIRPORT_LAND_EDGE)
	draw_colored_polygon(polygon, AIRPORT_LAND)

	# Very broad, low-contrast mowing/landscape bands. These are intentionally
	# unrelated to the gameplay grid.
	for fraction in [0.24, 0.52, 0.78]:
		var a := polygon[0].lerp(polygon[3], float(fraction))
		var b := polygon[1].lerp(polygon[2], float(fraction))
		draw_line(
			a,
			b,
			Color("a8c37c", 0.055),
			24.0
		)


func _draw_landscape_bands() -> void:
	var bands := [
		[
			PackedVector2Array([
				Vector2(-2200, -1000),
				Vector2(-480, -1000),
				Vector2(-1040, 440),
				Vector2(-2200, 840)
			]),
			Color("527d46")
		],
		[
			PackedVector2Array([
				Vector2(520, -1000),
				Vector2(2200, -1000),
				Vector2(2200, 720),
				Vector2(1010, 425)
			]),
			Color("4b7847")
		],
		[
			PackedVector2Array([
				Vector2(-2200, 900),
				Vector2(-810, 610),
				Vector2(-80, 1110),
				Vector2(-2200, 2200)
			]),
			Color("3b673f")
		],
		[
			PackedVector2Array([
				Vector2(810, 610),
				Vector2(2200, 880),
				Vector2(2200, 2200),
				Vector2(90, 1110)
			]),
			Color("416d42")
		]
	]
	for band_variant in bands:
		var band: Array = band_variant
		draw_colored_polygon(
			band[0] as PackedVector2Array,
			band[1] as Color
		)

	# Soft patches keep the far background from reading like four flat shapes.
	for patch in [
		[Vector2(-1380, 180), 430.0, Color("85a95f", 0.11)],
		[Vector2(1400, 270), 520.0, Color("315c39", 0.12)],
		[Vector2(-1120, 1260), 560.0, Color("718f54", 0.09)],
		[Vector2(1220, 1290), 470.0, Color("2d5838", 0.11)]
	]:
		draw_set_transform(
			patch[0],
			0.0,
			Vector2(1.0, 0.42)
		)
		draw_circle(Vector2.ZERO, float(patch[1]), patch[2])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_distant_access_network() -> void:
	var south_road := PackedVector2Array([
		Vector2(-1510, 1010),
		Vector2(-920, 1210),
		Vector2(-260, 1330),
		Vector2(430, 1250),
		Vector2(1090, 1015),
		Vector2(1570, 920)
	])
	_draw_background_road(south_road)

	var west_road := PackedVector2Array([
		Vector2(-1540, 180),
		Vector2(-1360, 410),
		Vector2(-1260, 680),
		Vector2(-1080, 990)
	])
	_draw_background_road(west_road)


func _draw_background_road(points: PackedVector2Array) -> void:
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(8, 12))
	draw_polyline(
		shadow,
		Color(0.03, 0.05, 0.05, 0.20),
		66.0,
		true
	)
	draw_polyline(points, ROAD_SHOULDER, 60.0, true)
	draw_polyline(points, ROAD_SURFACE, 46.0, true)
	draw_polyline(points, Color("ece7da", 0.58), 2.0, true)

	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		if a.distance_to(b) < 20.0:
			continue
		draw_dashed_line(
			a.lerp(b, 0.10),
			a.lerp(b, 0.90),
			ROAD_LINE,
			2.0,
			20.0
		)


func _draw_environment_scenery() -> void:
	# Field artwork provides the large authored shapes that were missing from
	# the previous procedural-only background.
	_draw_texture_centered(
		field_texture,
		Vector2(-650, -35),
		Vector2(760, 390),
		0.92
	)
	_draw_texture_centered(
		field_texture,
		Vector2(675, -15),
		Vector2(730, 375),
		0.88
	)
	_draw_texture_centered(
		field_texture,
		Vector2(-720, 825),
		Vector2(700, 360),
		0.76
	)
	_draw_texture_centered(
		field_texture,
		Vector2(735, 845),
		Vector2(710, 365),
		0.78
	)

	_draw_texture_centered(
		parking_texture,
		Vector2(-760, 610),
		Vector2(430, 252),
		0.84
	)
	_draw_texture_centered(
		parking_texture,
		Vector2(790, 625),
		Vector2(390, 228),
		0.72
	)

	for item in [
		[tree_texture, Vector2(-610, 205), Vector2(250, 205), 0.96],
		[conifer_texture, Vector2(625, 220), Vector2(255, 215), 0.94],
		[tree_texture, Vector2(-620, 710), Vector2(235, 190), 0.90],
		[conifer_texture, Vector2(650, 735), Vector2(245, 205), 0.91],
		[tree_texture, Vector2(-420, -90), Vector2(205, 165), 0.86],
		[tree_texture, Vector2(445, -70), Vector2(210, 170), 0.86]
	]:
		_draw_texture_centered(
			item[0] as Texture2D,
			item[1] as Vector2,
			item[2] as Vector2,
			float(item[3])
		)

	_draw_texture_centered(
		hedge_texture,
		Vector2(-520, 720),
		Vector2(300, 120),
		0.74
	)
	_draw_texture_centered(
		hedge_texture,
		Vector2(545, 740),
		Vector2(300, 120),
		0.74
	)
	_draw_texture_centered(
		entrance_texture,
		Vector2(-610, 805),
		Vector2(175, 140),
		0.92
	)


func _draw_texture_centered(
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	alpha: float = 1.0
) -> void:
	if texture == null:
		return
	draw_texture_rect(
		texture,
		Rect2(center - size * 0.5, size),
		false,
		Color(1, 1, 1, clampf(alpha, 0.0, 1.0))
	)


func _draw_depth_shading() -> void:
	# A few transparent edge washes make the central airport read brighter and
	# more important than the far scenery without putting a UI vignette over it.
	for wash in [
		[Vector2(-1750, 500), 760.0, Color("183d30", 0.08)],
		[Vector2(1750, 500), 760.0, Color("183d30", 0.08)],
		[Vector2(0, 1750), 980.0, Color("203f31", 0.10)]
	]:
		draw_set_transform(
			wash[0],
			0.0,
			Vector2(1.0, 0.56)
		)
		draw_circle(Vector2.ZERO, float(wash[1]), wash[2])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
