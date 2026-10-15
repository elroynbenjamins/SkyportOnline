extends SceneTree

# Only the three approved grid-authored airport assets, captured directly
# from the Godot renderer (not a composited image or concept illustration).
const OUTPUT := "res://artifacts/airport_core_art_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, id: String, cell: Vector2i) -> bool:
	var placement := grid.set_build_preview(
		id, grid.tile_to_world(Vector2(cell.x, cell.y)), 0
	)
	if not bool(placement.get("valid", false)):
		push_error("Cannot place %s: %s" % [
			id, String(placement.get("reason", "invalid"))
		])
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := Node2D.new()
	scene.name = "AirportCoreVisualQA"
	root.add_child(scene)

	var backdrop := AirportBackdrop.new()
	scene.add_child(backdrop)
	var grid := AirportGrid.new()
	scene.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(grid, "medium_hangar", Vector2i(3, 4)):
		quit(1)
		return
	if not _place(grid, "small_hangar", Vector2i(11, 4)):
		quit(1)
		return
	if not _place(grid, "short_runway", Vector2i(5, 10)):
		quit(1)
		return

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(8.0, 8.0))
	camera.zoom = Vector2(1.80, 1.80)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	scene.add_child(camera)

	for _i in range(22):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var full_path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var captured := root.get_texture().get_image()
	if captured == null or captured.is_empty():
		push_error("Real Godot capture failed.")
		quit(1)
		return
	if captured.save_png(full_path) != OK:
		push_error("Could not write airport core visual screenshot.")
		quit(1)
		return
	print(
		"AIRPORT_CORE_ART_SCREENSHOT_OK "
		+ "small=3x2 medium=4x3 runway=5x2 "
		+ "roads=none path=%s" % full_path
	)
	quit(0)
