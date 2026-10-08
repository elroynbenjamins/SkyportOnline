extends SceneTree

const LANDING_OUTPUT := "res://artifacts/skyrama_landing_fx.png"
const TAKEOFF_OUTPUT := "res://artifacts/skyrama_takeoff_fx.png"


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


func _save_viewport(path: String) -> bool:
	RenderingServer.force_draw()
	await process_frame
	var output_absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(
		output_absolute.get_base_dir()
	)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Flight FX screenshot viewport image is empty.")
		return false
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error("Could not save flight FX screenshot: %d" % error)
		return false
	print(
		"SKYRAMA_FLIGHT_FX_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	return true


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

	if not _place(grid, "short_runway", Vector2i(4, 4)):
		quit(1)
		return

	var runway := grid.get_simple_runway_animation_route("S")
	if runway.is_empty():
		push_error("Flight FX QA needs a Short Runway.")
		quit(1)
		return

	var plane := CareerAircraft.new()
	plane.name = "SO-001"
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.z_index = 90
	world.add_child(plane)
	await process_frame
	plane.set_simple_runway_route(
		runway.get("start_world", Vector2.ZERO),
		runway.get("end_world", Vector2.ZERO),
		int(runway.get("runway_uid", -1))
	)
	plane.visible = true

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(6.0, 4.4))
	camera.zoom = Vector2(2.0, 2.0)
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

	# Touchdown frame near the first third of the runway.
	var start: Vector2 = runway.get("start_world", Vector2.ZERO)
	var end: Vector2 = runway.get("end_world", Vector2.ZERO)
	plane.position = start.lerp(end, 0.34)
	plane.rotation = (end - start).angle()
	plane._set_state("LANDING_ROLL")
	plane._process(0.18)
	hud.set_operation_status(
		"SO-001 touchdown • rollout to runway end"
	)
	for _frame in range(3):
		await process_frame
	if not await _save_viewport(LANDING_OUTPUT):
		quit(1)
		return

	# High-speed departure frame just before rotation.
	plane.position = start.lerp(end, 0.62)
	plane.rotation = (end - start).angle()
	plane.takeoff_velocity = plane.takeoff_speed * 0.88
	plane._set_state("TAKEOFF_ROLL")
	plane._process(0.12)
	hud.set_operation_status(
		"SO-001 takeoff roll • accelerating"
	)
	for _frame in range(3):
		await process_frame
	if not await _save_viewport(TAKEOFF_OUTPUT):
		quit(1)
		return

	quit(0)
