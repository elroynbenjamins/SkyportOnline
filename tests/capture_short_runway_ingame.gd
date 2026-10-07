extends SceneTree

const OUTPUT_PATH := "res://artifacts/short_runway_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "ShortRunwayVisualQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame

	grid.prepare_new_airport_builder_layout()
	await process_frame

	var definition := BuildingCatalog.get_definition(
		"short_runway"
	)
	if definition.get("footprint", Vector2i.ZERO) != Vector2i(5, 2):
		push_error("Visual QA requires the Short Runway to be 5x2.")
		quit(1)
		return

	var runway_origin := Vector2i(2, 2)
	var preview := grid.set_build_preview(
		"short_runway",
		grid.tile_to_world(
			Vector2(runway_origin.x, runway_origin.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		push_error(
			"Could not place 5x2 Short Runway for visual QA: %s"
			% String(preview.get("reason", "invalid"))
		)
		quit(1)
		return

	var placed := grid.confirm_build_preview()
	if placed.is_empty():
		push_error("Could not confirm Short Runway for visual QA.")
		quit(1)
		return

	var camera := Camera2D.new()
	camera.position = Vector2(0, 285)
	camera.zoom = Vector2(1.04, 1.04)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	world.add_child(camera)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(
		BuildingCatalog.get_menu_definitions()
	)
	hud.set_player_data(3, 18500, 35)
	hud.set_airport_identity(
		"Skyport",
		"AMS",
		"Netherlands",
		"guest"
	)
	hud.set_airside_status(
		grid.get_airside_status()
	)
	hud.set_operation_status(
		"Small Runway • 5×2 grid-native surface"
	)

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
		push_error("Short Runway screenshot viewport image is empty.")
		quit(1)
		return

	var error := image.save_png(output_absolute)
	if error != OK:
		push_error(
			"Short Runway screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"SHORT_RUNWAY_SCREENSHOT_OK path=%s size=%dx%d footprint=5x2"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
