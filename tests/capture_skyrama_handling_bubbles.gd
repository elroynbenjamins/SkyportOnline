extends SceneTree

const OUTPUT_PATH := "res://artifacts/skyrama_handling_bubbles.png"


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


func _make_plane(
	name_text: String
) -> CareerAircraft:
	var plane := CareerAircraft.new()
	plane.name = name_text
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.z_index = 90
	root.add_child(plane)
	return plane


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "SkyramaHandlingBubbleQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(grid, "short_runway", Vector2i(2, 2)):
		quit(1)
		return
	if not _place(grid, "basic_fuel", Vector2i(2, 8)):
		quit(1)
		return
	if not _place(grid, "ground_ops_depot", Vector2i(6, 8)):
		quit(1)
		return
	if not _place(grid, "small_hangar", Vector2i(9, 7)):
		quit(1)
		return

	var runway := grid.get_simple_runway_animation_route("S")
	var fuel := grid.get_best_service_building("fuel", "S")
	var cargo := grid.get_best_service_building("cargo", "S")
	if runway.is_empty() or fuel.is_empty() or cargo.is_empty():
		push_error("Visual QA needs runway, fuel and cargo structures.")
		quit(1)
		return

	var landed := _make_plane("SO-001")
	landed.set_simple_runway_route(
		runway.get("start_world", Vector2.ZERO),
		runway.get("end_world", Vector2.ZERO),
		int(runway.get("runway_uid", -1))
	)
	landed.position = runway.get("end_world", Vector2.ZERO)
	landed.visible = true
	landed._set_state("SIMPLE_WAITING_UNLOAD")
	landed.set_turnaround_status(
		"LANDED • READY",
		"warning"
	)
	landed.set_handling_action("UNLOAD")

	var fueling := _make_plane("SO-002")
	fueling.start_simple_fueling(
		fuel.get("world_position", Vector2.ZERO),
		18.0
	)
	fueling._process(9.3)

	var loading := _make_plane("SO-003")
	loading.start_simple_loading(
		cargo.get("world_position", Vector2.ZERO),
		20.0
	)
	loading._process(13.6)

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(6.0, 5.4))
	camera.zoom = Vector2(1.45, 1.45)
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
		"Owned aircraft handling • tap bubbles to continue"
	)

	for _frame in range(12):
		await process_frame
		landed._process(0.05)
		fueling._process(0.05)
		loading._process(0.05)

	RenderingServer.force_draw()
	await process_frame

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(
		output_absolute.get_base_dir()
	)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Handling bubble screenshot is empty.")
		quit(1)
		return

	var error := image.save_png(output_absolute)
	if error != OK:
		push_error(
			"Handling bubble screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"SKYRAMA_HANDLING_BUBBLE_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
