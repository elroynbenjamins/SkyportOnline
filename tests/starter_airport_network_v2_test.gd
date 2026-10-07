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

	var owned: Array[String] = grid.export_owned_parcels()
	for parcel_id in ["north_west", "north", "west", "home"]:
		if not owned.has(parcel_id):
			_fail("%s should be part of the free starter construction area." % parcel_id)
			return

	var airside := grid.get_airside_status()
	if int(airside.get("runways", -1)) != 0:
		_fail("Player should place the starter runway themselves.")
		return
	if int(airside.get("stands_total", -1)) != 0:
		_fail("Player should place the starter stand themselves.")
		return
	if int(airside.get("hangars_total", 0)) != 1:
		_fail("Builder starter should keep one small hangar as aircraft origin.")
		return
	if int(airside.get("hangars_connected", -1)) != 0:
		_fail("Starter hangar should require the player to connect taxiways.")
		return

	# Build a simple physical network:
	# runway -> taxi spine -> stand + hangar.
	if not _place(grid, "short_runway", Vector2i(0, 0)):
		return
	for y in range(2, 8):
		if not _place(grid, "taxiway", Vector2i(3, y)):
			return
	if not _place(grid, "small_stand", Vector2i(4, 5)):
		return

	# Extend the starter service-road spine to the chosen stand so the fuel
	# truck can actually reach it.
	for cell in [
		Vector2i(7, 7),
		Vector2i(7, 6),
		Vector2i(7, 5)
	]:
		if not _place(grid, "service_road", cell):
			return

	airside = grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Placed runway should become operational infrastructure.")
		return
	if int(airside.get("stands_connected", 0)) != 1:
		_fail("Placed stand should connect to runway through the taxi spine.")
		return
	if int(airside.get("hangars_connected", 0)) != 1:
		_fail("Hangar should connect to the same taxi network.")
		return

	var departures := grid.get_departure_routes("S")
	if departures.size() != 1:
		_fail("One connected stand should create one S-class departure route.")
		return

	var stand_uid := int(departures[0].get("stand_uid", -1))
	var hangar_routes := grid.get_hangar_to_stand_routes(stand_uid, "S")
	if hangar_routes.size() != 1:
		_fail("Connected starter hangar should route to the loading stand.")
		return
	var hangar_route: PackedVector2Array = hangar_routes[0].get(
		"route",
		PackedVector2Array()
	)
	if hangar_route.size() < 4:
		_fail("Hangar-to-stand route should visibly follow the taxi network.")
		return

	var fuel := grid.get_best_service_building("fuel", "S")
	if fuel.is_empty():
		_fail("Builder starter should retain its basic fuel station.")
		return
	var fuel_route := grid.get_service_route(
		int(fuel.get("uid", -1)),
		stand_uid
	)
	if fuel_route.size() < 3:
		_fail("Fuel truck should require and use a connected service-road route.")
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
		_fail("Aircraft should accept a hangar-to-stand predeparture taxi.")
		return
	if plane.state != "TAXIING_TO_STAND":
		_fail("Aircraft should leave the hangar in TAXIING_TO_STAND state.")
		return

	for _step in range(600):
		plane._process(0.1)
		if plane.state == "WAITING_FUEL":
			break
	if plane.state != "WAITING_FUEL":
		_fail("Aircraft should reach the stand before fueling/loading starts.")
		return
	if plane.position.distance_to(departure_route[0]) > 0.5:
		_fail("Hangar taxi should finish at the loading stand.")
		return

	print(
		"STARTER_AIRPORT_NETWORK_V2_OK area=16x16 "
		+ "player_runway=true taxi_connected=true "
		+ "hangar_to_stand=true fuel_by_service_road=true"
	)
	quit(0)


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(Vector2(cell.x, cell.y)),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	var placed := grid.confirm_build_preview()
	if placed.is_empty():
		_fail("Placement confirmation failed for %s." % building_id)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
