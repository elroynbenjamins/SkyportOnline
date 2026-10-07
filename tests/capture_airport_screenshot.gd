extends SceneTree

const OUTPUT_PATH := "res://artifacts/current_airport.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "VisualQAAirport"
	root.add_child(world)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame

	var camera := Camera2D.new()
	# Visual QA should judge the actual airport, not primarily the expansion
	# overlay. Keep the starter airfield large enough to inspect at a glance.
	camera.position = Vector2(95, 355)
	camera.zoom = Vector2(1.10, 1.10)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	world.add_child(camera)

	var ambient := AirportAmbientLife.new()
	ambient.z_index = 78
	world.add_child(ambient)
	ambient.configure(grid)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(7, 42850, 120)
	hud.set_airport_identity(
		"Skyport",
		"AMS",
		"Netherlands",
		"guest"
	)
	hud.set_airside_status(grid.get_airside_status())
	hud.set_operation_status(
		"2 aircraft awaiting turnaround"
	)

	# Add a small screenshot-only apron patch next to the starter terminal.
	# This never touches saved gameplay state; it simply keeps the new
	# purchasable ground surface visible in visual regression artifacts.
	for apron_cell in [
		Vector2i(8, 12),
		Vector2i(9, 12),
		Vector2i(8, 13),
		Vector2i(9, 13)
	]:
		var apron_status := grid.set_build_preview(
			"apron_tile",
			grid.tile_to_world(Vector2(apron_cell)),
			0
		)
		if bool(apron_status.get("valid", false)):
			grid.confirm_build_preview()
	grid.clear_build_preview()

	var routes: Array[Dictionary] = grid.get_departure_routes("S")
	var plane_count := mini(routes.size(), 2)
	for index in range(plane_count):
		var route: PackedVector2Array = routes[index].get(
			"route",
			PackedVector2Array()
		)
		if route.size() < 2:
			continue
		var aircraft := CareerAircraft.new()
		aircraft.configure_aircraft_type(
			"pico_p8" if index == 0 else "swift_s14"
		)
		aircraft.name = "SO-%03d" % (index + 1)
		aircraft.z_index = 82 + index
		world.add_child(aircraft)
		await process_frame
		aircraft.position = route[0]
		aircraft.rotation = (
			route[1] - route[0]
		).angle()
		aircraft.state = (
			"SERVICING"
			if index == 0
			else "WAITING_PASSENGERS"
		)
		aircraft.set_turnaround_status(
			"SERVICE"
			if index == 0
			else "PAX WAIT",
			"success"
			if index == 0
			else "warning"
		)
		aircraft.queue_redraw()

	for _frame in range(6):
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
		push_error("Airport screenshot viewport image is empty.")
		quit(1)
		return
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error(
			"Airport screenshot could not be saved: %d"
			% error
		)
		quit(1)
		return

	print(
		"AIRPORT_SCREENSHOT_OK path=%s size=%dx%d"
		% [
			output_absolute,
			image.get_width(),
			image.get_height()
		]
	)
	quit(0)
