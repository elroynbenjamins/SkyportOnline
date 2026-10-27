extends SceneTree

# In-game Godot viewport: separate 3x2 fuel and cargo parking pads
# with aircraft visibly stopped on the slabs, depots elsewhere.
const OUTPUT_PATH := "res://artifacts/separate_service_parking_ingame.png"


func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, id: String, pos: Vector2i) -> bool:
	var state := grid.set_build_preview(
		id, grid.tile_to_world(Vector2(pos.x, pos.y)), 0
	)
	if not bool(state.get("valid", false)):
		push_error("%s: %s" % [id, str(state)])
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	world.add_child(AirportBackdrop.new())
	world.add_child(AirportPixelTerrain.new())
	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	for item in [
		["fuel_parking_s", Vector2i(4, 8)],
		["cargo_parking_s", Vector2i(9, 8)],
		["basic_fuel", Vector2i(3, 3)],
		["ground_ops_depot", Vector2i(10, 3)]
	]:
		if not _place(grid, String(item[0]), item[1]):
			quit(1)
			return

	for service in ["fuel", "cargo"]:
		var pads := grid.get_simple_service_parking_pads(service, "S")
		if pads.is_empty():
			push_error("Missing %s parking." % service)
			quit(1)
			return
		var plane := CareerAircraft.new()
		plane.configure_aircraft_type("pico_p8")
		plane.configure_skyrama_handling(true)
		plane.name = "%s-plane" % service
		plane.z_index = 50
		world.add_child(plane)
		if service == "fuel":
			plane.start_simple_fueling(pads[0]["world_position"], 120.0)
		else:
			plane.start_simple_unloading(pads[0]["world_position"], 120.0)

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(7.4, 6.9))
	camera.zoom = Vector2(1.6, 1.6)
	camera.enabled = true
	world.add_child(camera)

	for _frame in range(15):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(path) != OK:
		push_error("Unable to capture separate parking in Godot.")
		quit(1)
		return
	print("SEPARATE_PARKING_SCREENSHOT_OK path=%s" % path)
	quit(0)
