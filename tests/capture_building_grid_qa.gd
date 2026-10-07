extends SceneTree

const OUTPUT_PATH := "res://artifacts/building_grid_qa.png"
const COLUMNS := 7
const CELL_SPACING := Vector2i(5, 5)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(2048, 1400)

	var world := Node2D.new()
	world.name = "BuildingGridQA"
	root.add_child(world)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame

	# Remove gameplay layout so this image is a clean art/footprint inspection.
	grid.placed_buildings.clear()
	grid.stored_buildings.clear()
	grid.occupied_cells.clear()
	grid.selected_id = ""
	for parcel_id in grid.parcels.keys():
		grid.parcels[parcel_id]["owned"] = true

	var samples: Array[Dictionary] = []
	for definition in BuildingCatalog.all():
		if not grid._definition_has_world_sprite(definition):
			continue
		var rotations := 2 if bool(
			definition.get("rotatable", false)
		) else 1
		for rotation in range(rotations):
			samples.append({
				"definition": definition,
				"rotation": rotation
			})

	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var uid := 1
	for index in range(samples.size()):
		var sample: Dictionary = samples[index]
		var definition: Dictionary = sample["definition"]
		var rotation := int(sample["rotation"])
		var column := index % COLUMNS
		var row := int(index / COLUMNS)
		var origin := Vector2i(
			1 + column * CELL_SPACING.x,
			1 + row * CELL_SPACING.y
		)
		grid.placed_buildings.append({
			"uid": uid,
			"definition_id": String(definition.get("id", "")),
			"origin": origin,
			"rotation": rotation,
			"upgrade_level": 1
		})
		uid += 1

		var footprint := grid._footprint_for(
			definition,
			rotation
		)
		var polygon := grid._footprint_polygon(
			origin,
			footprint
		)
		if polygon.size() < 4:
			continue

		var overlay := Polygon2D.new()
		overlay.polygon = polygon
		overlay.color = Color(0.15, 0.72, 0.95, 0.16)
		overlay.z_index = 90
		world.add_child(overlay)

		var outline := Line2D.new()
		for point_variant in polygon:
			outline.add_point(point_variant as Vector2)
		outline.add_point(polygon[0])
		outline.width = 2.0
		outline.default_color = Color(0.40, 0.90, 1.0, 0.90)
		outline.z_index = 91
		world.add_child(outline)

		var center := grid._footprint_center_world(
			origin,
			footprint
		)
		var label := Label.new()
		label.text = "%s  R%d  %dx%d" % [
			String(definition.get("id", "")),
			rotation,
			footprint.x,
			footprint.y
		]
		label.position = center + Vector2(-84, -104)
		label.size = Vector2(180, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("fff8de"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.z_index = 92
		world.add_child(label)

		min_pos.x = minf(min_pos.x, polygon[3].x)
		min_pos.y = minf(min_pos.y, polygon[0].y - 120.0)
		max_pos.x = maxf(max_pos.x, polygon[1].x)
		max_pos.y = maxf(max_pos.y, polygon[2].y + 45.0)

	grid._rebuild_occupied_cells()
	grid._recalculate_airside_network()
	grid.queue_redraw()

	var camera := Camera2D.new()
	camera.position = (min_pos + max_pos) * 0.5
	var scene_size := max_pos - min_pos
	var zoom_x := float(root.size.x - 80) / maxf(scene_size.x, 1.0)
	var zoom_y := float(root.size.y - 80) / maxf(scene_size.y, 1.0)
	var zoom_value := minf(zoom_x, zoom_y)
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	world.add_child(camera)

	for _frame in range(8):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var output_absolute := ProjectSettings.globalize_path(
		OUTPUT_PATH
	)
	DirAccess.make_dir_recursive_absolute(
		output_absolute.get_base_dir()
	)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Building-grid QA viewport image is empty.")
		quit(1)
		return
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error(
			"Building-grid QA screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"BUILDING_GRID_QA_OK samples=%d path=%s"
		% [samples.size(), output_absolute]
	)
	quit(0)
