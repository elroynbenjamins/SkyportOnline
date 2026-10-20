extends SceneTree

# Fuel/cargo depots are buildings; aircraft stand on separately purchased
# 3x2 parking slabs, with no taxi-road adjacency required.
func _init() -> void:
	call_deferred("_run")


func _place(grid: AirportGrid, id: String, cell: Vector2i) -> bool:
	var state := grid.set_build_preview(
		id, grid.tile_to_world(Vector2(cell.x, cell.y)), 0
	)
	if not bool(state.get("valid", false)):
		push_error("Could not place %s: %s" % [id, str(state)])
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	for service_type in ["fuel", "cargo"]:
		var id := "%s_parking_s" % service_type
		var definition := BuildingCatalog.get_definition(id)
		if definition.get("footprint", Vector2i.ZERO) != Vector2i(3, 2):
			_fail("Parking %s must occupy 3x2 square cells." % id)
			return
		if String(definition.get("service_parking", "")) != service_type:
			_fail("Parking role not declared for %s." % id)
			return
		var paths: PackedStringArray = definition.get(
			"grid_native_surface_paths", PackedStringArray()
		)
		if paths.size() != 2:
			_fail("Parking needs separate 3x2 and 2x3 artwork.")
			return
		for path in paths:
			var texture = load(path)
			if not (texture is Texture2D) or texture.get_size() != Vector2(160, 80):
				_fail("Grid-native 160x80 pad import failed: %s" % path)
				return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()
	if not _place(grid, "fuel_parking_s", Vector2i(3, 7)):
		_fail("Cannot snap independent fuel parking.")
		return
	if not _place(grid, "cargo_parking_s", Vector2i(8, 7)):
		_fail("Cannot snap independent cargo parking.")
		return
	if grid.get_simple_service_parking_capacity("fuel", "S") != 0:
		_fail("A fuel parking pad without depot should not provide service.")
		return
	if grid.get_simple_service_parking_capacity("cargo", "S") != 0:
		_fail("A cargo parking pad without depot should not provide service.")
		return
	if not _place(grid, "basic_fuel", Vector2i(2, 2)):
		_fail("Cannot place separate fuel depot.")
		return
	if not _place(grid, "ground_ops_depot", Vector2i(9, 3)):
		_fail("Cannot place separate cargo building.")
		return
	for service_type in ["fuel", "cargo"]:
		if grid.get_simple_service_parking_capacity(service_type, "S") != 1:
			_fail("One parking pad plus one service slot should handle one plane.")
			return
		var pad: Dictionary = grid.get_simple_service_parking_pads(
			service_type, "S"
		)[0]
		var station := grid.get_best_service_building(service_type, "S")
		if (
			pad.is_empty()
			or station.is_empty()
			or pad.get("world_position", Vector2.ZERO) ==
			station.get("world_position", Vector2.ZERO)
		):
			_fail("Aircraft may not park on/in its service depot.")
			return

	# Each pad is only parking; a processing depot is required to create
	# service throughput. Additional pads cannot exceed that capacity.
	var fuel_pads := grid.get_simple_service_parking_pads("fuel", "S")
	var cargo_pads := grid.get_simple_service_parking_pads("cargo", "S")
	if fuel_pads.size() != 1 or cargo_pads.size() != 1:
		_fail("Exactly one of each independent parking pad should be found.")
		return
	# Processing capacity is not the same as occupancy. A completed
	# aircraft still blocks its slab, but it releases the depot's worker.
	var two_bays: Array[Dictionary] = [
		{"uid": 1, "world_position": Vector2(10, 10)},
		{"uid": 2, "world_position": Vector2(40, 10)}
	]
	var parked: Array[Dictionary] = [{
		"world_position": Vector2(10, 10),
		"state": "SIMPLE_WAITING_LOAD"
	}]
	var next_fuel := SkyramaParkingRules.select_available_pad(
		"fuel", two_bays, 1, parked
	)
	if int(next_fuel.get("uid", -1)) != 2:
		_fail("Completed fueling should free processing capacity, not its occupied bay.")
		return
	parked[0]["state"] = "SIMPLE_FUELING"
	if not SkyramaParkingRules.select_available_pad(
		"fuel", two_bays, 1, parked
	).is_empty():
		_fail("Active fueling must block another job at capacity one.")
		return

	parked[0]["state"] = "SIMPLE_WAITING_SEND"
	if int(SkyramaParkingRules.select_available_pad(
		"cargo", two_bays, 1, parked
	).get("uid", -1)) != 2:
		_fail("Finished cargo loading should release its processing slot.")
		return
	parked[0]["state"] = "SIMPLE_UNLOADING"
	if not SkyramaParkingRules.select_available_pad(
		"cargo", two_bays, 1, parked
	).is_empty():
		_fail("Active unloading must count against cargo processing capacity.")
		return

	parked[0]["state"] = "SIMPLE_WAITING_LOAD"
	parked.append({
		"world_position": Vector2(40, 10),
		"state": "SIMPLE_WAITING_LOAD"
	})
	if not SkyramaParkingRules.select_available_pad(
		"fuel", two_bays, 2, parked
	).is_empty():
		_fail("Two occupied bays cannot place a third plane, even with free workers.")
		return

	print("SEPARATE_HANDLING_PARKING_OK fuel=3x2 cargo=3x2 pads=2 roadless=true capacity=1 capacity_separated=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
