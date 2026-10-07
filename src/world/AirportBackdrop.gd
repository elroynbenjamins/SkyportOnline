class_name AirportBackdrop
extends Node2D

# Authored landscape beneath AirportGrid.
#
# This layer is intentionally scenery-only: rolling grass, distant hills,
# water and tree belts. It never owns placement, expansion parcels, routing or
# airport roads. Those remain grid-native gameplay assets above this layer.

const WORLD_RECT := Rect2(-2200, -1000, 4400, 3200)
const WORLD_GRASS := Color("5a9345")

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

	_draw_depth_shading()


func get_visual_snapshot() -> Dictionary:
	return {
		"world_rect": WORLD_RECT,
		"field_groups": 4,
		"tree_groups": 7,
		"hill_layers": 3,
		"water_strip": true,
		"parking_groups": 0,
		"road_sections": 0,
		"continuous_landscape": true,
		"airport_land_overlay": false,
		"production_environment_v3": true,
		"authored_backdrop_texture": landscape_texture != null,
		"background_asset": LANDSCAPE_TEXTURE_PATH,
		"independent_from_airport_grid": true,
		"grid_safe_center": true
	}


func _draw_fallback_landscape() -> void:
	for patch in [
		[Vector2(-1450, -350), 560.0, Color("86ad63", 0.18)],
		[Vector2(1450, -330), 600.0, Color("3f7541", 0.17)],
		[Vector2(-1380, 1320), 650.0, Color("83a45b", 0.12)],
		[Vector2(1380, 1340), 620.0, Color("35663c", 0.13)]
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
	for wash in [
		[Vector2(-1920, 620), 850.0, Color("173d2d", 0.055)],
		[Vector2(1920, 620), 850.0, Color("173d2d", 0.055)],
		[Vector2(0, 1950), 1080.0, Color("24472f", 0.060)]
	]:
		draw_set_transform(
			wash[0],
			0.0,
			Vector2(1.0, 0.58)
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
