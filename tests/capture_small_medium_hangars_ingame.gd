extends SceneTree

# Headful rendering screenshot of the real Godot airport, showing both
# independently constructed hangars at their exact square-grid footprints.
const OUTPUT_PATH := "res://artifacts/small_medium_hangars_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, id: String, cell: Vector2i) -> bool:
	var preview := grid.set_build_preview(
		id, grid.tile_to_world(Vector2(cell.x, cell.y)), 0
	)
	if not bool(preview.get("valid", false)):
		push_error(
			"Could not snap %s to %s: %s"
			% [id, str(cell), String(preview.get("reason", "unknown"))]
		)
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "SmallAndMediumHangarsQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	# Two REAL placed buildings. None of the visual positions are mocked.
	if not _place(grid, "medium_hangar", Vector2i(3, 4)):
		quit(1)
		return
	if not _place(grid, "small_hangar", Vector2i(10, 4)):
		quit(1)
		return

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(7.5, 5.0))
	camera.zoom = Vector2(1.75, 1.75)
	camera.enabled = true
	world.add_child(camera)

	# No QA overlays: user sees exactly what the actual Godot world renders.
	for _frame in range(16):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Small/medium hangar capture returned an empty viewport.")
		quit(1)
		return
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not write hangar screenshot: %d" % error)
		quit(1)
		return

	print(
		"SMALL_MEDIUM_HANGARS_SCREENSHOT_OK "
		+ "small=3x2 medium=4x3 path=%s" % output
	)
	quit(0)
