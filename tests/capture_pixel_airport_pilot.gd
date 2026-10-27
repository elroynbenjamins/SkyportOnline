extends SceneTree

# REAL Godot pixel-style pilot. No precomposed concept screenshot:
# every visible placed structure comes from BuildingCatalog and AirportGrid.
const OUTPUT := "res://artifacts/pixel_airport_pilot.png"


func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, building_id: String, origin: Vector2i) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(Vector2(origin.x, origin.y)),
		0
	)
	if not bool(preview.get("valid", false)):
		push_error("Pilot could not place %s: %s" % [
			building_id, String(preview.get("reason", "unknown"))
		])
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := Node2D.new()
	root.add_child(scene)
	scene.add_child(AirportBackdrop.new())
	scene.add_child(AirportPixelTerrain.new())

	var grid := AirportGrid.new()
	scene.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	for build in [
		["small_hangar", Vector2i(10, 2)],
		["short_runway", Vector2i(4, 11)],
		["basic_fuel", Vector2i(2, 3)],
		["ground_ops_depot", Vector2i(4, 3)],
		["fuel_parking_s", Vector2i(3, 7)],
		["cargo_parking_s", Vector2i(9, 7)],
		["apron_tile", Vector2i(7, 8)],
		["apron_tile", Vector2i(8, 8)],
		["apron_tile", Vector2i(7, 9)],
		["apron_tile", Vector2i(8, 9)]
	]:
		if not _place(grid, String(build[0]), build[1]):
			quit(1)
			return

	var fuel_pads := grid.get_simple_service_parking_pads("fuel", "S")
	var cargo_pads := grid.get_simple_service_parking_pads("cargo", "S")
	if fuel_pads.is_empty() or cargo_pads.is_empty():
		push_error("Pilot service parking missing after placement.")
		quit(1)
		return

	for type in ["fuel", "cargo"]:
		var plane := CareerAircraft.new()
		plane.name = "Pilot-%s" % type
		plane.configure_aircraft_type(
			"pico_p8" if type == "fuel" else "swift_s14"
		)
		plane.configure_skyrama_handling(true)
		plane.z_index = 60
		scene.add_child(plane)
		if type == "fuel":
			plane.start_simple_fueling(fuel_pads[0]["world_position"], 120.0)
		else:
			plane.start_simple_unloading(cargo_pads[0]["world_position"], 120.0)

	var camera := Camera2D.new()
	camera.position = grid.tile_to_world(Vector2(7.8, 7.9))
	camera.zoom = Vector2(1.35, 1.35)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	scene.add_child(camera)

	grid.clear_build_preview()
	for _frame in range(20):
		await process_frame
	RenderingServer.force_draw()
	await process_frame

	var absolute := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(absolute) != OK:
		push_error("Pixel airport pilot screenshot failed.")
		quit(1)
		return

	print("PIXEL_AIRPORT_PILOT_OK path=%s" % absolute)
	quit(0)
