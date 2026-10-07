extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var starter := grid.prepare_new_airport_builder_layout()
	if int(starter.get("owned_width_tiles", 0)) != 16:
		_fail("New airport builder should start with 16 tiles of width.")
		return
	if int(starter.get("owned_height_tiles", 0)) != 16:
		_fail("New airport builder should start with 16 tiles of height.")
		return

	var initial_layout := grid.export_airport_layout()
	if initial_layout.size() != 1:
		_fail("Builder start should contain only the Airport Office.")
		return
	var initial: Dictionary = initial_layout[0]
	if String(initial.get("definition_id", "")) != "airport_office":
		_fail("Fixed Airport Office should be the only initial structure.")
		return

	var airside := grid.get_airside_status()
	if int(airside.get("runways", -1)) != 0:
		_fail("Player should place the starter runway.")
		return
	if int(airside.get("stands_total", -1)) != 0:
		_fail("Player should place the starter stand.")
		return
	if int(airside.get("hangars_total", -1)) != 0:
		_fail("Player should place the starter hangar.")
		return

	if not _place(grid, "short_runway", Vector2i(0, 0)):
		return
	if not _place(grid, "small_hangar", Vector2i(0, 6)):
		return
	if not _place(grid, "small_stand", Vector2i(4, 6)):
		return
	for y in range(2, 8):
		if not _place(grid, "taxiway", Vector2i(3, y)):
			return

	if not _place(grid, "basic_fuel", Vector2i(8, 6)):
		return
	if not _place(grid, "ground_ops_depot", Vector2i(8, 8)):
		return
	for cell in [
		Vector2i(6, 7),
		Vector2i(7, 7),
		Vector2i(7, 8)
	]:
		if not _place(grid, "service_road", cell):
			return

	airside = grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Placed runway should become operational.")
		return
	if int(airside.get("stands_connected", 0)) != 1:
		_fail("Placed stand should connect through Taxiways.")
		return
	if int(airside.get("hangars_connected", 0)) != 1:
		_fail("Player-built hangar should connect through Taxiways.")
		return

	var departures := grid.get_departure_routes("S")
	if departures.size() != 1:
		_fail("One connected stand should create one departure route.")
		return
	var stand_uid := int(departures[0].get("stand_uid", -1))

	var hangar_routes := grid.get_hangar_to_stand_routes(stand_uid, "S")
	if hangar_routes.size() != 1:
		_fail("Player-built hangar should route to the stand.")
		return
	var hangar_route: PackedVector2Array = hangar_routes[0].get(
		"route",
		PackedVector2Array()
	)
	if hangar_route.size() < 4:
		_fail("Hangar route should visibly follow Taxiways.")
		return

	for service_type in [
		"fuel", "cleaning", "catering", "cargo", "passenger", "pushback"
	]:
		var station := grid.get_best_service_building(service_type, "S")
		if station.is_empty():
			_fail("Tutorial airport should provide %s service." % service_type)
			return
		var route := grid.get_service_route(
			int(station.get("uid", -1)),
			stand_uid
		)
		if route.size() < 3:
			_fail("%s service should reach the stand by Service Road." % service_type)
			return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	var departure_route: PackedVector2Array = departures[0].get(
		"route",
		PackedVector2Array()
	)
	plane.set_departure_route(
		departure_route,
		"S",
		stand_uid,
		int(departures[0].get("runway_uid", -1))
	)
	if not plane.set_predeparture_transfer_route(hangar_route):
		_fail("Aircraft should accept the player-built hangar-to-stand taxi.")
		return

	for _step in range(600):
		plane._process(0.1)
		if plane.state == "WAITING_FUEL":
			break
	if plane.state != "WAITING_FUEL":
		_fail("Aircraft should reach the stand before service starts.")
		return

	print(
		"STARTER_AIRPORT_NETWORK_V2_OK initial=office_only "
		+ "player_built_airside=true player_built_services=true"
	)
	quit(0)


func _place(grid: AirportGrid, building_id: String, cell: Vector2i) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(Vector2(cell.x, cell.y)),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [building_id, str(cell), String(preview.get("reason", "invalid"))]
		)
		return false
	if grid.confirm_build_preview().is_empty():
		_fail("Placement confirmation failed for %s." % building_id)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
