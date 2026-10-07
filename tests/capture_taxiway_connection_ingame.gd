extends SceneTree

const OUTPUT_PATH := "res://artifacts/taxiway_connection_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		push_error(
			"Visual QA could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "TaxiwayVisualQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(
		grid,
		"short_runway",
		Vector2i(2, 2)
	):
		quit(1)
		return

	for cell in [
		Vector2i(4, 4),
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(5, 6)
	]:
		if not _place(grid, "taxiway", cell):
			quit(1)
			return

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(
		Vector2(4.0, 3.8)
	)
	camera.zoom = Vector2(1.78, 1.78)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	world.add_child(camera)

	var hud := preload(
		"res://src/ui/HUD.gd"
	).new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(
		BuildingCatalog.get_menu_definitions()
	)
	hud.set_player_data(3, 18000, 35)
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
		"Taxiway • automatic runway connection"
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
		push_error("Taxiway screenshot viewport image is empty.")
		quit(1)
		return
	var error := image.save_png(
		output_absolute
	)
	if error != OK:
		push_error(
			"Taxiway screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"TAXIWAY_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
