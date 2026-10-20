extends SceneTree

const GROUND_OUTPUT := "res://artifacts/pico_refined_ground.png"
const TAKEOFF_OUTPUT := "res://artifacts/pico_refined_takeoff.png"


func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, id: String, tile: Vector2i) -> bool:
	var result := grid.set_build_preview(
		id, grid.tile_to_world(Vector2(tile)), 0
	)
	if not bool(result.get("valid", false)):
		push_error("Plane visual QA could not place %s: %s" % [
			id, String(result.get("reason", "invalid"))
		])
		return false
	return not grid.confirm_build_preview().is_empty()


func _capture(path: String) -> bool:
	for _frame in range(5):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	return image.save_png(absolute) == OK


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	var background := AirportBackdrop.new()
	world.add_child(background)
	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(grid, "short_runway", Vector2i(2, 2)):
		quit(1)
		return
	if not _place(grid, "fuel_parking_s", Vector2i(5, 7)):
		quit(1)
		return
	if not _place(grid, "cargo_parking_s", Vector2i(9, 7)):
		quit(1)
		return
	var pads := grid.get_simple_service_parking_pads("fuel", "S")
	if pads.is_empty():
		push_error("Pico QA needs its separate fuel parking pad.")
		quit(1)
		return

	var plane := CareerAircraft.new()
	plane.name = "SO-001"
	plane.z_index = 90
	world.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	plane.rotation = -PI * 0.25
	plane.start_simple_fueling(
		pads[0].get("world_position", Vector2.ZERO), 24.0
	)
	plane.rotation = -PI * 0.25
	plane.set_selection_highlight(true)
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position = grid.tile_to_world(Vector2(6.3, 5.0))
	camera.zoom = Vector2(2.0, 2.0)
	world.add_child(camera)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_airport_identity("Skyport", "AMS", "Netherlands", "guest")
	hud.set_player_data(4, 24250, 40)
	hud.set_fuel_data(120, 240, 1.0)
	hud.set_passenger_data(28, 80, 1.5)
	hud.set_operation_status("Pico P8 • fueling on a dedicated parking pad", "normal")
	plane._process(3.8)
	if not await _capture(GROUND_OUTPUT):
		push_error("Failed to capture Pico ground shadow screenshot.")
		quit(1)
		return

	plane.set_selection_highlight(false)
	plane.clear_turnaround_status()
	plane.clear_handling_action()
	plane.simple_stage_remaining = 0.0
	var runway := grid.get_simple_runway_animation_route("S")
	if runway.is_empty():
		push_error("Pico QA needs the placed small runway.")
		quit(1)
		return
	plane.set_simple_runway_route(
		runway.get("start_world", Vector2.ZERO),
		runway.get("end_world", Vector2.ZERO),
		int(runway.get("runway_uid", -1))
	)
	plane.position = runway.get("start_world", Vector2.ZERO)
	plane.state = "TAKEOFF_ROLL"
	plane.visible = true
	plane.rotation = PI * 0.25
	camera.position = runway.get("start_world", Vector2.ZERO)
	hud.set_operation_status("Pico P8 • runway departure underway", "success")
	plane._process(0.12)
	if not await _capture(TAKEOFF_OUTPUT):
		push_error("Failed to capture Pico runway screenshot.")
		quit(1)
		return
	print("PICO_VISUAL_CAPTURES_OK ground=%s runway=%s" % [
		GROUND_OUTPUT, TAKEOFF_OUTPUT
	])
	quit(0)
