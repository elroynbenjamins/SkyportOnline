extends SceneTree

# Genuine Godot viewport capture: one built hangar and one rotated
# placement preview. Grid, sprite, shadow and pavement all use runtime art.
const OUTPUT_PATH := "res://artifacts/generated_hangar_grid_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	root.add_child(world)
	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	# Stable empty cells within the starter airport.
	var built := grid.set_build_preview(
		"small_hangar", grid.tile_to_world(Vector2(9, 4)), 0
	)
	if not bool(built.get("valid", false)):
		_fail("Could not snap 3x2 hangar.")
		return
	if grid.confirm_build_preview().is_empty():
		_fail("Could not confirm constructed 3x2 hangar.")
		return

	var rotated := grid.set_build_preview(
		"small_hangar", grid.tile_to_world(Vector2(3, 5)), 1
	)
	if not bool(rotated.get("valid", false)):
		_fail("Could not preview snapped 2x3 hangar.")
		return

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(7.0, 5.4))
	camera.zoom = Vector2(1.9, 1.9)
	camera.enabled = true
	world.add_child(camera)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(3, 18000, 35)
	hud.set_airport_identity(
		"Skyport", "AMS", "Netherlands", "guest"
	)
	hud.set_operation_status(
		"Hangar grid fit • 3x2 placed / 2x3 preview"
	)

	for _frame in range(14):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty():
		_fail("Godot viewport image is empty.")
		return
	var error := picture.save_png(output)
	if error != OK:
		_fail("Could not write viewport image: %d" % error)
		return
	print("GENERATED_HANGAR_SCREENSHOT_OK path=%s" % output)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
