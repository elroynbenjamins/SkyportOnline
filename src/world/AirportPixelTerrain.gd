class_name AirportPixelTerrain
extends Node2D

# Pixel-material pilot: world-only decoration, never part of grid occupancy,
# pathfinding, building collisions, or infrastructure placement.
# The authored background remains underneath this layer.
const GROUND_AREA := Rect2(-2200, -130, 4400, 2330)
const PALETTE_GRASS_LIT := Color("b7ca6b")
const PALETTE_GRASS_DARK := Color("3f713a")
const PALETTE_TRUNK := Color("715a40")
const PALETTE_STONE := Color("929788")

var detail_texture: ImageTexture


func _ready() -> void:
	z_index = -190
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	detail_texture = _build_grass_detail_texture()
	queue_redraw()


func get_visual_snapshot() -> Dictionary:
	return {
		"pixel_material_pilot": true,
		"grass_texture": detail_texture != null,
		"static_pixel_clusters": true,
		"independent_from_grid": true,
		"ground_area": GROUND_AREA,
		"road_network_changed": false
	}


func _draw() -> void:
	if detail_texture != null:
		draw_texture_rect(
			detail_texture,
			GROUND_AREA,
			true,
			Color(1.0, 1.0, 1.0, 0.75)
		)
	_draw_edge_scenery()


func _build_grass_detail_texture() -> ImageTexture:
	# A transparent, repeating 256px texture leaves the authored hill/water
	# scene intact while adding grass blades, clover, earth and flower pixels.
	# Every mark is deterministic, so it never shimmers between frames.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(4, 254, 5):
		for x in range(3, 254, 5):
			var hash := posmod(x * 173 + y * 79 + x * y * 7, 1009)
			var cx := x + hash % 3
			var cy := y + (hash / 3) % 3
			if hash % 13 == 0:
				_put_pixels(img, cx, cy, 3, 1, Color("204f2d", 0.22))
				_put_pixels(img, cx + 1, cy - 2, 1, 2, Color("9fca60", 0.44))
				_put_pixels(img, cx + 3, cy - 1, 1, 2, Color("b7cf70", 0.31))
			elif hash % 9 == 0:
				_put_pixels(img, cx, cy, 2, 1, Color("3d733a", 0.24))
				_put_pixels(img, cx, cy - 2, 1, 2, Color("a4c45d", 0.40))
			elif hash % 17 == 0:
				_put_pixels(img, cx, cy, 4, 2, Color("977e4c", 0.14))
			elif hash % 19 == 0:
				_put_pixels(img, cx, cy, 2, 1, Color("c4d77c", 0.35))
			if hash % 317 == 0:
				_put_pixels(img, cx + 1, cy, 2, 2, Color("fff1b3", 0.72))
				_put_pixels(img, cx - 1, cy + 1, 1, 1, Color("ecd76a", 0.60))
			elif hash % 313 == 0:
				_put_pixels(img, cx, cy, 2, 1, Color("d9d7cb", 0.42))
	return ImageTexture.create_from_image(img)


func _put_pixels(
	img: Image,
	x: int,
	y: int,
	w: int,
	h: int,
	color: Color
) -> void:
	for py in range(maxi(y, 0), mini(y + h, img.get_height())):
		for px in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(px, py, color)


func _draw_edge_scenery() -> void:
	# Keep the central build area unobstructed. Soft green edge dressing
	# appears outside the owned 16x16 core, behind all airport structures.
	for i in range(42):
		var side := -1 if i % 2 == 0 else 1
		var distance := 620 + posmod(i * 113, 880)
		var x := float(side * distance)
		var y := float(-100 + posmod(i * 127 + 31, 2200))
		var scale := 0.70 + float(posmod(i * 17, 7)) * 0.085
		_draw_tree(Vector2(x, y), scale, i)

	for i in range(65):
		var side := -1 if i % 2 == 0 else 1
		var x := float(side * (605 + posmod(i * 83, 1070)))
		var y := float(-85 + posmod(i * 151, 2200))
		if i % 3 == 0:
			_draw_rock(Vector2(x, y), 0.65 + float(i % 4) * 0.16)
		else:
			_draw_bush(Vector2(x, y), 0.65 + float(i % 5) * 0.10)


func _draw_tree(location: Vector2, scale: float, seed: int) -> void:
	draw_set_transform(location.round(), 0.0, Vector2(scale, scale))
	# Long, offset flattened contact shadow ties trees to the terrain.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-25, 0), Vector2(-12, -5),
			Vector2(27, 7), Vector2(12, 12)
		]),
		Color(0.04, 0.16, 0.10, 0.18)
	)
	draw_rect(Rect2(-4, -27, 8, 27), PALETTE_TRUNK)
	draw_rect(Rect2(-3, -26, 2, 21), Color("ae8656"))
	var evergreen := seed % 4 != 0
	if evergreen:
		# Stepped shadow and highlight triangles produce a voxel/pixel
		# silhouette rather than smooth circles or vector blobs.
		for tier in range(3):
			var top := -90.0 + float(tier) * 19.0
			var width := 16.0 + float(tier) * 10.0
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0, top), Vector2(width, top + 34),
					Vector2(-width, top + 34)
				]),
				Color("265e42")
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0, top + 3), Vector2(2, top + 30),
					Vector2(-width + 4, top + 30)
				]),
				Color("57945b")
			)
			draw_rect(
				Rect2(-10, top + 21, 7, 3),
				Color("91b777", 0.80)
			)
	else:
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-24, -51), Vector2(-22, -69),
				Vector2(-14, -81), Vector2(3, -86),
				Vector2(20, -77), Vector2(28, -58),
				Vector2(15, -43), Vector2(-8, -42)
			]),
			Color("2d6745")
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-21, -61), Vector2(-15, -78),
				Vector2(0, -83), Vector2(8, -69),
				Vector2(-3, -57)
			]),
			Color("77a864")
		)
		draw_rect(Rect2(-13, -76, 7, 5), Color("b4c16f"))
		draw_rect(Rect2(8, -60, 6, 5), Color("4b8452"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rock(location: Vector2, scale: float) -> void:
	draw_set_transform(location.round(), 0.0, Vector2(scale, scale))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-18, 4), Vector2(-7, -6),
			Vector2(9, -10), Vector2(19, 0),
			Vector2(14, 7), Vector2(-14, 9)
		]),
		Color("6b7970")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-15, 1), Vector2(-6, -6),
			Vector2(7, -9), Vector2(0, 1)
		]),
		Color("b0b9a5")
	)
	draw_rect(Rect2(-7, -4, 5, 2), Color("d3d1b6"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bush(location: Vector2, scale: float) -> void:
	draw_set_transform(location.round(), 0.0, Vector2(scale, scale))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-19, 1), Vector2(-16, -10), Vector2(-6, -15),
			Vector2(1, -10), Vector2(12, -16),
			Vector2(19, -7), Vector2(18, 4)
		]),
		Color("2e6740")
	)
	draw_rect(Rect2(-15, -10, 11, 5), Color("6ba45e"))
	draw_rect(Rect2(-1, -13, 10, 4), Color("91b976"))
	draw_rect(Rect2(5, -5, 10, 3), Color("4b8755"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
