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
		_fail("Builder start should contain only the Main Airport Building.")
		return
	var initial: Dictionary = initial_layout[0]
	if String(initial.get("definition_id", "")) != "airport_office":
		_fail("Fixed Main Airport Building should be the only initial structure.")
		return

	# V1 owned-aircraft handling is deliberately Skyrama-like: the player
	# places the handling structures, but aircraft teleport between them.
	# Taxiway/service-road routing remains a later/advanced subsystem.
	for item in [
		["short_runway", Vector2i(0, 0)],
		["small_hangar", Vector2i(0, 10)],
		["basic_fuel", Vector2i(8, 5)],
		["ground_ops_depot", Vector2i(5, 10)]
	]:
		if not _place(
			grid,
			String(item[0]),
			item[1]
		):
			return

	var runway := grid.get_simple_runway_animation_route("S")
	if runway.is_empty():
		_fail("Starter runway should expose a direct landing/takeoff animation route.")
		return
	if int(runway.get("runway_uid", -1)) < 0:
		_fail("Simple runway route should expose a real runway UID.")
		return
	if (
		runway.get("start_world", Vector2.ZERO)
		== runway.get("end_world", Vector2.ZERO)
	):
		_fail("Simple runway route needs distinct start/end animation points.")
		return

	var hangar := grid.get_simple_hangar("S")
	if hangar.is_empty():
		_fail("Starter hangar should be available as aircraft inventory.")
		return

	var fuel := grid.get_best_service_building("fuel", "S")
	if fuel.is_empty():
		_fail("Starter fuel structure should be available without road routing.")
		return

	var cargo := grid.get_best_service_building("cargo", "S")
	if cargo.is_empty():
		_fail("Ground Ops should provide starter cargo/de-cargo handling.")
		return

	for station in [fuel, cargo]:
		if station.get("world_position", Vector2.ZERO) == Vector2.ZERO:
			_fail("Handling structures should expose teleport target positions.")
			return

	var airside := grid.get_airside_status()
	if int(airside.get("runways", 0)) != 1:
		_fail("Placed Short Runway should remain a real operational runway.")
		return
	if int(airside.get("hangars_total", 0)) != 1:
		_fail("Placed Small Hangar should remain part of airport state.")
		return

	print(
		"STARTER_AIRPORT_NETWORK_V2_OK initial=office_only "
		+ "simple_handling=true runway=true hangar=true fuel=true cargo=true"
	)
	quit(0)


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
		_fail(
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(
					preview.get(
						"reason",
						"invalid"
					)
				)
			]
		)
		return false
	if grid.confirm_build_preview().is_empty():
		_fail(
			"Placement confirmation failed for %s."
			% building_id
		)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
