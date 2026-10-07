class_name AirportBackdrop
extends Node2D

# Scene-level authored environment beneath AirportGrid.
#
# The playable airport remains fully owned by AirportGrid. This layer supplies
# only the surrounding landscape, airport land shoulder, roads and depth. That
# separation lets the square placement grid evolve without baking gameplay
# geometry into background artwork.

const WORLD_RECT := Rect2(-2200, -1000, 4400, 3200)
const WORLD_GRASS := Color("4f7c46")
const AIRPORT_LAND := Color("73a45b")
const AIRPORT_LAND_LIGHT := Color("82b064")
const AIRPORT_LAND_EDGE := Color("527746")
const AIRPORT_LAND_EDGE_DARK := Color("3d603c")
const AIRPORT_LAND_HIGHLIGHT := Color("a9c982", 0.18)
const AIRPORT_LAND_TEXTURE := Color("d6e5b3", 0.045)

const LANDSCAPE_TEXTURE_PATH := (
	"res://assets/production/environment_v3/airport_landscape_v3.svg"
)

var landscape_texture: Texture2D


func _ready() -> void:
	z_index = -200
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	landscape_texture = _load_texture(LANDSCAPE_TEXTURE_PATH)
	queue_redraw()


func _load_texture(path: String) -> Texture2D:
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _draw() -> void:
	# A solid base guarantees the world remains coherent even while Godot is
	# importing the authored SVG on first launch.
	draw_rect(WORLD_RECT, WORLD_GRASS, true)

	if landscape_texture != null:
		draw_texture_rect(
			landscape_texture,
			WORLD_RECT,
			false,
			Color.WHITE
		)
	else:
		_draw_fallback_landscape()

	_draw_airport_landmass()
	_draw_depth_shading()


func get_visual_snapshot() -> Dictionary:
	return {
		"world_rect": WORLD_RECT,
		"airport_land_points": _airport_land_polygon().size(),
		"field_groups": 4,
		"tree_groups": 6,
		"parking_groups": 1,
		"road_sections": 2,
		"production_environment_v3": true,
		"authored_backdrop_texture": landscape_texture != null,
		"background_asset": LANDSCAPE_TEXTURE_PATH,
		"independent_from_airport_grid": true,
		"grid_safe_center": true
	}


func _airport_land_polygon() -> PackedVector2Array:
	# The 24x24 projected build area is roughly 1536x768. The background land
	# shoulder is intentionally larger so the grid reads as part of the world,
	# not as a floating board.
	return PackedVector2Array([
		Vector2(0, -170),
		Vector2(965, 365),
		Vector2(0, 920),
		Vector2(-965, 365)
	])


func _draw_airport_landmass() -> void:
	var polygon := _airport_land_polygon()

	# Soft contact shadow, offset down-right to match the production building
	# lighting direction.
	var shadow := PackedVector2Array()
	for point_variant in polygon:
		var point: Vector2 = point_variant
		shadow.append(point + Vector2(18, 26))
	draw_colored_polygon(
		shadow,
		Color(0.025, 0.055, 0.035, 0.28)
	)

	# Two-stage edge gives the central site a polished cut-grass shoulder
	# without looking like a raised concrete platform.
	var center := Vector2(0, 370)
	var outer_dark := PackedVector2Array()
	var outer_light := PackedVector2Array()
	for point_variant in polygon:
		var point: Vector2 = point_variant
		outer_dark.append(
			center + (point - center) * 1.050
		)
		outer_light.append(
			center + (point - center) * 1.025
		)

	draw_colored_polygon(outer_dark, AIRPORT_LAND_EDGE_DARK)
	draw_colored_polygon(outer_light, AIRPORT_LAND_EDGE)
	draw_colored_polygon(polygon, AIRPORT_LAND)

	# Broad mowing stripes follow the isometric presentation instead of the
	# logical cell grid. This keeps the grass authored while placement remains
	# visually exact and easy to read.
	for fraction in [0.18, 0.34, 0.50, 0.66, 0.82]:
		var a := polygon[0].lerp(
			polygon[3],
			float(fraction)
		)
		var b := polygon[1].lerp(
			polygon[2],
			float(fraction)
		)
		draw_line(
			a,
			b,
			AIRPORT_LAND_TEXTURE,
			34.0
		)

	# Thin upper-left highlight and lower-right shade reinforce the same light
	# direction used by the building atlas.
	draw_line(
		polygon[3],
		polygon[0],
		AIRPORT_LAND_HIGHLIGHT,
		5.0
	)
	draw_line(
		polygon[0],
		polygon[1],
		Color("b8d18d", 0.10),
		3.0
	)
	draw_line(
		polygon[1],
		polygon[2],
		Color("315d39", 0.16),
		6.0
	)
	draw_line(
		polygon[2],
		polygon[3],
		Color("315d39", 0.13),
		5.0
	)

	# Small low-contrast turf variation prevents the center from reading as a
	# single flat fill once the player zooms out.
	for patch in [
		[Vector2(-430, 160), 205.0, Color("b7d48a", 0.045)],
		[Vector2(455, 185), 230.0, Color("315f3b", 0.045)],
		[Vector2(-300, 640), 260.0, Color("a5c77b", 0.040)],
		[Vector2(360, 650), 240.0, Color("365f3d", 0.040)]
	]:
		draw_set_transform(
			patch[0],
			0.0,
			Vector2(1.0, 0.38)
		)
		draw_circle(
			Vector2.ZERO,
			float(patch[1]),
			patch[2]
		)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_fallback_landscape() -> void:
	# Deliberately simple fallback only. The production path is the authored
	# environment-v3 texture above.
	for patch in [
		[Vector2(-1350, 120), 520.0, Color("86a85e", 0.18)],
		[Vector2(1400, 220), 560.0, Color("315e3a", 0.16)],
		[Vector2(-1250, 1250), 620.0, Color("789754", 0.14)],
		[Vector2(1280, 1270), 590.0, Color("2d5938", 0.14)]
	]:
		draw_set_transform(
			patch[0],
			0.0,
			Vector2(1.0, 0.42)
		)
		draw_circle(
			Vector2.ZERO,
			float(patch[1]),
			patch[2]
		)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_depth_shading() -> void:
	# Edge washes focus the eye on the playable site while preserving a bright,
	# colorful mobile-game background rather than a dark vignette.
	for wash in [
		[Vector2(-1860, 480), 820.0, Color("183d30", 0.070)],
		[Vector2(1860, 480), 820.0, Color("183d30", 0.070)],
		[Vector2(0, 1850), 1050.0, Color("203f31", 0.085)]
	]:
		draw_set_transform(
			wash[0],
			0.0,
			Vector2(1.0, 0.56)
		)
		draw_circle(
			Vector2.ZERO,
			float(wash[1]),
			wash[2]
		)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
