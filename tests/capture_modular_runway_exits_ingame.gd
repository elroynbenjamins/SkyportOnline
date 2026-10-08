extends SceneTree

const OUTPUT_PATH := "res://artifacts/modular_runway_exits_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i,
	rotation: int = 0
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		rotation
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
	world.name = "ModularRunwayExitQA"
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
		Vector2i(4, 4)
	):
		quit(1)
		return

	# Lane A uses its side socket, then continues as real 1x1 Taxiway blocks.
	for cell in [
		Vector2i(8, 3),
		Vector2i(8, 2),
		Vector2i(8, 1)
	]:
		if not _place(grid, "taxiway", cell):
			quit(1)
			return

	# Lane B uses its forward socket and continues as a longer straight Taxiway.
	for cell in [
		Vector2i(9, 5),
		Vector2i(10, 5),
		Vector2i(11, 5),
		Vector2i(12, 5)
	]:
		if not _place(grid, "taxiway", cell):
			quit(1)
			return

	var runway_uid := -1
	for building_variant in grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get(
				"definition_id",
				""
			)
		) == "short_runway":
			runway_uid = int(
				building.get("uid", -1)
			)
			break

	if runway_uid < 0:
		push_error("Visual QA could not resolve Short Runway UID.")
		quit(1)
		return

	var visual_state := grid.get_runway_modular_visual_state(
		runway_uid
	)
	print(
		"MODULAR_RUNWAY_VISUAL_STATE %s"
		% str(visual_state)
	)

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(
		Vector2(7.4, 3.8)
	)
	camera.zoom = Vector2(1.62, 1.62)
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
		"Small Runway • modular 1x1 taxi exits"
	)

	for _frame in range(10):
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
		push_error("Modular runway screenshot viewport image is empty.")
		quit(1)
		return

	var error := image.save_png(
		output_absolute
	)
	if error != OK:
		push_error(
			"Modular runway screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"MODULAR_RUNWAY_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
