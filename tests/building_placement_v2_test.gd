extends SceneTree

const PlacementGridV2 := preload(
	"res://src/build/BuildingPlacementGrid.gd"
)
const SpritePlacementV2 := preload(
	"res://src/build/BuildingSpritePlacement.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var samples: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(8, 8),
		Vector2i(15, 14),
		Vector2i(23, 23)
	]
	for tile in samples:
		var world := PlacementGridV2.tile_to_world(
			Vector2(tile.x, tile.y)
		)
		var restored := PlacementGridV2.world_to_tile(world)
		if restored != tile:
			_fail(
				"Placement V2 tile/world roundtrip failed for %s."
				% str(tile)
			)
			return

	var definition := {
		"footprint": Vector2i(3, 2),
		"rotatable": true
	}
	if (
		PlacementGridV2.footprint_for(definition, 0)
		!= Vector2i(3, 2)
	):
		_fail("Rotation A should keep the 3x2 footprint.")
		return
	if (
		PlacementGridV2.footprint_for(definition, 1)
		!= Vector2i(2, 3)
	):
		_fail("Rotation B should swap the 3x2 footprint.")
		return

	var cells := PlacementGridV2.cells_for(
		Vector2i(4, 5),
		Vector2i(3, 2)
	)
	if cells.size() != 6:
		_fail("3x2 footprint should occupy exactly six cells.")
		return
	if PlacementGridV2.cell_key(Vector2i(4, 5)) != "4:5":
		_fail("Placement V2 cell keys should remain save-compatible.")
		return

	# Synthetic transparent building image: the visible building occupies a
	# smaller rectangle inside a larger transparent PNG. Placement V2 should
	# ignore that transparent padding and put the visible bottom on the grid.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(
		Rect2i(24, 18, 80, 92),
		Color.WHITE
	)
	var bounds := SpritePlacementV2.visible_bounds(image)
	if bounds != Rect2i(24, 18, 80, 92):
		_fail(
			"Alpha bounds should come from visible building pixels only."
		)
		return

	var polygon := PlacementGridV2.footprint_polygon(
		Vector2i.ZERO,
		Vector2i(3, 2)
	)
	var center := PlacementGridV2.footprint_center_world(
		Vector2i.ZERO,
		Vector2i(3, 2)
	)
	var rect := SpritePlacementV2.grounded_rect(
		bounds,
		Vector2(128, 128),
		polygon,
		center,
		1.0
	)

	var front_y := -INF
	var min_x := INF
	var max_x := -INF
	for point_variant in polygon:
		var point: Vector2 = point_variant
		front_y = maxf(front_y, point.y)
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)

	var scale_x := rect.size.x / 128.0
	var scale_y := rect.size.y / 128.0
	var visible_bottom := (
		rect.position.y
		+ float(bounds.end.y) * scale_y
	)
	if absf(visible_bottom - front_y) > 0.01:
		_fail("Visible PNG base should sit directly on the grid.")
		return

	var visible_width := float(bounds.size.x) * scale_x
	var footprint_width := maxf(max_x - min_x, 1.0)
	if absf(visible_width - footprint_width) > 0.01:
		_fail(
			"Visible PNG width should derive directly from the footprint."
		)
		return

	print(
		"BUILDING_PLACEMENT_V2_OK geometry=centralized "
		+ "alpha_grounded=true png_padding_ignored=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
