extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var art_check := AirsideGroundArt.validate_catalog()
	if not bool(art_check.get("valid", false)):
		_fail(
			"Airside ground art should fully import: %s"
			% str(art_check.get("errors", []))
		)
		return
	if AirsideGroundArt.frame_count() != 45:
		_fail("Airside ground atlas should expose 45 modular frames.")
		return

	var straight := AirsideGroundArt.taxi_texture(
		AirsideGroundArt.EAST | AirsideGroundArt.WEST
	)
	var corner := AirsideGroundArt.taxi_texture(
		AirsideGroundArt.EAST | AirsideGroundArt.SOUTH
	)
	var junction := AirsideGroundArt.taxi_texture(
		AirsideGroundArt.EAST
		| AirsideGroundArt.SOUTH
		| AirsideGroundArt.WEST
	)
	var crossing := AirsideGroundArt.taxi_texture(
		AirsideGroundArt.NORTH
		| AirsideGroundArt.EAST
		| AirsideGroundArt.SOUTH
		| AirsideGroundArt.WEST
	)
	if (
		straight == null
		or corner == null
		or junction == null
		or crossing == null
	):
		_fail("Taxi straight/corner/T/crossing art should all load.")
		return
	if (
		(straight as AtlasTexture).region
		== (corner as AtlasTexture).region
	):
		_fail("Taxi straight and corner should use distinct atlas frames.")
		return
	if AirsideGroundArt.hold_short_texture(Vector2i(1, 0)) == null:
		_fail("Runway hold-short art should load.")
		return
	if AirsideGroundArt.stand_texture("S") == null:
		_fail("Small stand ground art should load.")
		return
	if AirsideGroundArt.stand_texture("M") == null:
		_fail("Medium stand ground art should load.")
		return

	var available: Dictionary = {}
	for cell in [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(3, 1),
		Vector2i(3, 2),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(2, 2),
	]:
		available["%d,%d" % [cell.x, cell.y]] = cell
	var goals := {"3,2": true}
	var smooth := AirsideRoutingRules.find_smooth_path(
		available,
		Vector2i(0, 0),
		goals
	)
	if smooth.is_empty():
		_fail("Airside Routing V2 should find the synthetic taxi path.")
		return
	if AirsideRoutingRules.turn_count(smooth) != 1:
		_fail("Airside Routing V2 should prefer the one-turn taxi path.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.size() != 2:
		_fail("Starter airport should still expose two small-aircraft routes.")
		return
	var route_info: Dictionary = routes[0]
	if int(route_info.get("routing_version", 0)) != 2:
		_fail("Starter departure should use Airside Routing V2.")
		return
	var taxi_cells: Array = route_info.get("taxi_cells", [])
	if taxi_cells.is_empty():
		_fail("Routing V2 should expose the taxi cells used by the aircraft.")
		return
	if int(route_info.get("taxi_turns", -1)) < 0:
		_fail("Routing V2 should expose taxi turn count.")
		return

	var route: PackedVector2Array = route_info.get(
		"route",
		PackedVector2Array()
	)
	var access: Vector2 = route_info.get(
		"stand_access_position",
		Vector2.ZERO
	)
	if route.size() < 6:
		_fail("Routing V2 route should include stand access and hold short.")
		return
	if route[1].distance_to(access) > 0.1:
		_fail("Second departure waypoint should be the stand-access point.")
		return
	if route[0].distance_to(route[1]) < 4.0:
		_fail("Stand access should provide a meaningful pushback/taxi lead-in.")
		return

	var tile_visual := grid.get_airside_tile_visual(
		Vector2i(12, 10),
		"taxiway"
	)
	if tile_visual.get("texture") == null:
		_fail("Starter taxiway should resolve to generated ground art.")
		return
	if int(tile_visual.get("mask", 0)) == 0:
		_fail("Starter taxiway should expose its real connection mask.")
		return

	grid.set_build_preview(
		"taxiway",
		grid.tile_to_world(Vector2(14, 10)),
		0
	)
	var preview_visual := grid.get_airside_preview_visual()
	if preview_visual.get("texture") == null:
		_fail("Taxiway placement preview should use production ground art.")
		return
	if int(preview_visual.get("mask", 0)) == 0:
		_fail("Taxiway placement preview should show live neighbor connections.")
		return
	if String(preview_visual.get("building_id", "")) != "taxiway":
		_fail("Airside preview snapshot should identify the selected ground piece.")
		return
	grid.clear_build_preview()

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.set_departure_route(
		route,
		"S",
		int(route_info.get("stand_uid", -1)),
		int(route_info.get("runway_uid", -1))
	)
	var pushback_target := plane.get_pushback_target_position()
	if pushback_target.distance_to(route[0]) < 4.0:
		_fail("Pushback target should follow the new stand-access lead-in.")
		return

	print(
		"AIRSIDE_ROUTING_V2_OK art_frames=45 "
		+ "routing_version=2 stand_access=true smoother_paths=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
