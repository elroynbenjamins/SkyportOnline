extends SceneTree

const STARTER_IDS := [
	"small_terminal",
	"small_stand",
	"travel_office",
	"ground_ops_depot",
	"basic_fuel"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var samples := [
		Vector2i(0, 0),
		Vector2i(8, 8),
		Vector2i(15, 14),
		Vector2i(23, 23)
	]
	for tile in samples:
		var world := BuildingPlacementGrid.tile_to_world(
			Vector2(tile.x, tile.y)
		)
		var restored := BuildingPlacementGrid.world_to_tile(world)
		if restored != tile:
			_fail(
				"Placement V2 tile/world roundtrip failed for %s."
				% str(tile)
			)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for building_id in STARTER_IDS:
		var definition := BuildingCatalog.get_definition(
			building_id
		)
		if definition.is_empty():
			_fail("%s definition is missing." % building_id)
			return
		if not bool(
			definition.get(
				"world_sprite_auto_ground",
				false
			)
		):
			_fail(
				"%s should use Placement V2 alpha grounding."
				% building_id
			)
			return

		var footprint := BuildingPlacementGrid.footprint_for(
			definition,
			0
		)
		var rect := grid._building_sprite_rect(
			definition,
			Vector2i.ZERO,
			footprint,
			0
		)
		var source := grid._sprite_region_for_rotation(
			definition,
			0
		)
		var path := grid._sprite_path_for_rotation(
			definition,
			0
		)
		var image = grid._get_building_texture_image(path)
		if image == null:
			_fail("%s source art failed to load." % building_id)
			return

		var source_size := Vector2(
			image.get_width(),
			image.get_height()
		)
		if source.size.x > 0.0 and source.size.y > 0.0:
			source_size = source.size
		var bounds := grid._sprite_visible_bounds_for_rotation(
			definition,
			0
		)
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			_fail("%s has no visible source pixels." % building_id)
			return

		var polygon := BuildingPlacementGrid.footprint_polygon(
			Vector2i.ZERO,
			footprint
		)
		var front_y := -INF
		var min_x := INF
		var max_x := -INF
		for point_variant in polygon:
			var point: Vector2 = point_variant
			front_y = maxf(front_y, point.y)
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)

		var scale_y := rect.size.y / source_size.y
		var scale_x := rect.size.x / source_size.x
		var visible_bottom := (
			rect.position.y
			+ float(bounds.end.y) * scale_y
		)
		if absf(visible_bottom - front_y) > 1.25:
			_fail(
				"%s visible PNG base is %.2f px off the grid."
				% [
					building_id,
					visible_bottom - front_y
				]
			)
			return

		var visible_width := (
			float(bounds.size.x) * scale_x
		)
		var footprint_width := maxf(max_x - min_x, 1.0)
		var ratio := visible_width / footprint_width
		if absf(ratio - 1.0) > 0.03:
			_fail(
				"%s visible art should match its footprint width, got %.2fx."
				% [building_id, ratio]
			)
			return

		var poisoned := definition.duplicate(true)
		poisoned["world_sprite_offset"] = Vector2(900, 900)
		poisoned["world_sprite_offsets"] = [
			Vector2(900, 900),
			Vector2(-900, -900)
		]
		poisoned["world_sprite_size"] = Vector2(999, 999)
		var clean_rect := grid._building_sprite_rect(
			poisoned,
			Vector2i.ZERO,
			footprint,
			0
		)
		if (
			clean_rect.position.distance_to(rect.position) > 0.01
			or clean_rect.size.distance_to(rect.size) > 0.01
		):
			_fail(
				"%s Placement V2 must ignore legacy manual sprite offsets."
				% building_id
			)
			return

	print(
		"BUILDING_PLACEMENT_V2_OK geometry=centralized "
		+ "alpha_grounded=true legacy_offsets_ignored=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
