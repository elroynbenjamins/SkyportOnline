extends SceneTree

# V1 has independent runway slots and tap-to-transfer handling. Taxiways,
# stand service routing and alternate taxi-path decisions are retired.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	grid.select_parcel("east")
	grid.purchase_selected()
	grid.select_parcel("south_east")
	grid.purchase_selected()

	var runway_preview := grid.set_build_preview(
		"regional_runway",
		grid.tile_to_world(Vector2(20, 8)),
		1
	)
	if not bool(runway_preview.get("valid", false)):
		_fail("Regional Runway must fit its purchased square-grid area.")
		return
	var regional: Dictionary = grid.confirm_build_preview()
	if regional.is_empty():
		_fail("Regional Runway should be placeable without taxi roads.")
		return

	var runways := grid.get_runway_buildings()
	if runways.size() != 2:
		_fail("Two constructed runways should remain independently registered.")
		return
	var ids: Dictionary = {}
	for building in runways:
		ids[int(building.get("uid", -1))] = true
	if ids.size() != 2:
		_fail("Each placed runway needs its own runway UID.")
		return

	var short_route := grid.get_simple_runway_animation_route("S")
	var medium_route := grid.get_simple_runway_animation_route("M")
	if short_route.is_empty() or medium_route.is_empty():
		_fail("Compatible S and M runways must expose landing/takeoff animation routes.")
		return
	if int(medium_route.get("runway_uid", -1)) != int(regional.get("uid", -1)):
		_fail("M-class planes may only use the Regional Runway.")
		return
	if not ids.has(int(short_route.get("runway_uid", -1))):
		_fail("S-class route must use a runway actually built on the grid.")
		return
	if not BuildingCatalog.get_definition("taxiway").is_empty():
		_fail("Physical taxiway buildings must remain retired in V1.")
		return

	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	var snapshot: Dictionary = dispatcher.get_atc_snapshot()
	var tracked: Array = snapshot.get("runways", [])
	if tracked.size() != 2:
		_fail("Runway control should track both physical runway slots.")
		return

	print("MULTI_RUNWAY_ROADLESS_OK distinct_slots=2 s_class=true m_class=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
