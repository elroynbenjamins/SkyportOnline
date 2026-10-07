extends SceneTree

const OUTPUT_DIR := "res://artifacts/plane_phases"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var world := Node2D.new()
	world.name = "PlanePhaseQA"
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)

	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _build_starter_network(grid):
		quit(1)
		return

	var camera := Camera2D.new()
	camera.position = Vector2(0, 230)
	camera.zoom = Vector2(1.02, 1.02)
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
	hud.set_player_data(1, 13525, 0)
	hud.set_airport_identity(
		"Skyport",
		"AMS",
		"Netherlands",
		"guest"
	)
	hud.set_airside_status(grid.get_airside_status())

	var departures: Array[Dictionary] = grid.get_departure_routes("S")
	if departures.is_empty():
		push_error("No starter departure route for phase capture.")
		quit(1)
		return
	var departure: Dictionary = departures[0]
	var stand_uid := int(departure.get("stand_uid", -1))
	var runway_uid := int(departure.get("runway_uid", -1))
	var departure_route: PackedVector2Array = departure.get(
		"route",
		PackedVector2Array()
	)
	var hangar_routes := grid.get_hangar_to_stand_routes(
		stand_uid,
		"S"
	)
	if hangar_routes.is_empty():
		push_error("No hangar-to-stand route for phase capture.")
		quit(1)
		return
	var hangar_route: PackedVector2Array = (
		hangar_routes[0] as Dictionary
	).get("route", PackedVector2Array())

	var plane := CareerAircraft.new()
	plane.configure_aircraft_type("pico_p8")
	plane.name = "SO-001"
	plane.z_index = 84
	world.add_child(plane)
	await process_frame
	plane.set_process(false)
	plane.set_departure_route(
		departure_route,
		"S",
		stand_uid,
		runway_uid
	)
	if not plane.set_predeparture_transfer_route(
		hangar_route
	):
		push_error("Could not start hangar taxi phase.")
		quit(1)
		return
	plane.set_turnaround_status(
		"TAXI TO STAND",
		"warning"
	)
	hud.set_operation_status(
		"SO-001 leaving hangar • taxiing to loading stand"
	)

	# Capture a short real taxi sequence plus a representative still.
	for index in range(12):
		plane._process(0.10)
		await _render_frame()
		if index == 4:
			await _save_view("taxiing.png")
		await _save_view(
			"taxi_%02d.png" % index
		)
		if plane.state != "TAXIING_TO_STAND":
			break

	# Ensure the aircraft reaches the stand.
	for _step in range(80):
		if plane.state != "TAXIING_TO_STAND":
			break
		plane._process(0.10)
	if plane.state == "TAXIING_TO_STAND":
		push_error("Plane did not reach stand for fueling capture.")
		quit(1)
		return

	plane._set_state("SERVICING")
	plane.set_turnaround_status(
		"FUELING",
		"success"
	)
	plane.queue_redraw()
	hud.set_operation_status(
		"SO-001 • fuel truck connected at the stand",
		"success"
	)

	var fuel_station := grid.get_best_service_building(
		"fuel",
		"S"
	)
	var fuel_route: PackedVector2Array = grid.get_service_route(
		int(fuel_station.get("uid", -1)),
		stand_uid
	)
	if fuel_route.size() < 2:
		push_error("Fuel route missing for phase capture.")
		quit(1)
		return

	var fuel_truck := FuelTruckPrototype.new()
	fuel_truck.z_index = 88
	world.add_child(fuel_truck)
	await process_frame
	fuel_truck.set_process(false)
	fuel_truck.set_service_connection_target(
		plane.global_position
	)
	fuel_truck.start_service(
		fuel_route,
		12.0
	)
	for _step in range(120):
		if fuel_truck.phase == "SERVICING":
			break
		fuel_truck._process(0.10)
	if fuel_truck.phase != "SERVICING":
		push_error("Fuel truck did not reach aircraft.")
		quit(1)
		return
	fuel_truck._process(0.35)
	await _render_frame()
	await _save_view("fueling.png")

	fuel_truck.queue_free()
	await process_frame

	# Departure taxi: the same plane leaves the stand on the player's route.
	plane.assign_flight_plan({
		"city": "Brussels",
		"destination_id": "brussels",
		"duration_seconds": 240.0,
		"fuel_required": 4,
		"passengers_required": 8
	})
	plane.set_departure_route(
		departure_route,
		"S",
		stand_uid,
		runway_uid
	)
	plane.begin_taxi_to_hold_short()
	plane.set_turnaround_status(
		"TAXI TO RUNWAY",
		"success"
	)
	hud.set_operation_status(
		"SO-001 loaded and fueled • taxiing to runway",
		"success"
	)
	for _step in range(4):
		plane._process(0.10)
	await _render_frame()
	await _save_view("departing_taxi.png")

	# Actual runway departure / takeoff.
	plane.begin_departure_after_clearance()
	hud.set_operation_status(
		"SO-001 cleared for takeoff",
		"success"
	)
	for _step in range(120):
		plane._process(0.10)
		if plane.state in [
			"TAKEOFF_ROLL",
			"CLIMBING"
		]:
			break
	await _render_frame()
	await _save_view("takeoff.png")

	# Inbound approach using the real arrival route.
	var arrivals: Array[Dictionary] = grid.get_arrival_route_options(
		"S"
	)
	if arrivals.is_empty():
		push_error("No arrival route for phase capture.")
		quit(1)
		return
	var arrival: Dictionary = arrivals[0]
	var arrival_route: PackedVector2Array = arrival.get(
		"route",
		PackedVector2Array()
	)
	plane.set_arrival_route(
		arrival_route,
		int(arrival.get("stand_uid", stand_uid)),
		int(arrival.get("runway_uid", runway_uid))
	)
	plane.begin_arrival_after_clearance()
	plane.set_turnaround_status(
		"ARRIVAL",
		"warning"
	)
	hud.set_operation_status(
		"SO-001 inbound • on approach"
	)
	for _step in range(80):
		plane._process(0.10)
		if (
			plane.state == "LANDING_ROLL"
			or (
				plane.state == "APPROACH"
				and plane.position.distance_to(
					arrival_route[0]
				) < 190.0
			)
		):
			break
	await _render_frame()
	await _save_view("arrival.png")

	print(
		"PLANE_PHASE_CAPTURES_OK taxiing fueling departure takeoff arrival"
	)
	quit(0)


func _build_starter_network(
	grid: AirportGrid
) -> bool:
	if not _place(
		grid,
		"short_runway",
		Vector2i(0, 0)
	):
		return false
	for y in range(2, 8):
		if not _place(
			grid,
			"taxiway",
			Vector2i(3, y)
		):
			return false
	if not _place(
		grid,
		"small_stand",
		Vector2i(4, 5)
	):
		return false
	for cell in [
		Vector2i(7, 7),
		Vector2i(7, 6),
		Vector2i(6, 6)
	]:
		if not _place(
			grid,
			"service_road",
			cell
		):
			return false
	return true


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
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	return not grid.confirm_build_preview().is_empty()


func _render_frame() -> void:
	await process_frame
	RenderingServer.force_draw()
	await process_frame


func _save_view(file_name: String) -> void:
	await _render_frame()
	var absolute := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join(file_name)
	)
	DirAccess.make_dir_recursive_absolute(
		absolute.get_base_dir()
	)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error(
			"Plane phase image is empty: %s" % file_name
		)
		return
	var error := image.save_png(absolute)
	if error != OK:
		push_error(
			"Could not save %s: %d"
			% [file_name, error]
		)
