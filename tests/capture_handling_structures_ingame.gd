extends SceneTree

const OUTPUT_PATH := "res://artifacts/handling_structures_ingame.png"


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
		grid.tile_to_world(Vector2(cell.x, cell.y)),
		rotation
	)
	if not bool(preview.get("valid", false)):
		push_error(
			"Could not place %s at %s: %s"
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
	world.name = "HandlingStructureQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(grid, "basic_fuel", Vector2i(3, 5)):
		quit(1)
		return
	if not _place(grid, "ground_ops_depot", Vector2i(7, 6)):
		quit(1)
		return
	if not _place(grid, "small_hangar", Vector2i(9, 4)):
		quit(1)
		return

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(7.0, 5.4))
	camera.zoom = Vector2(1.75, 1.75)
	camera.enabled = true
	world.add_child(camera)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(3, 18000, 35)
	hud.set_airport_identity(
		"Skyport",
		"AMS",
		"Netherlands",
		"guest"
	)
	hud.set_operation_status(
		"V3 handling structures • Fuel • Cargo • Hangar"
	)

	for _frame in range(12):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(
		output_absolute.get_base_dir()
	)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Handling structure screenshot viewport image is empty.")
		quit(1)
		return
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error(
			"Handling structure screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"HANDLING_STRUCTURES_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
