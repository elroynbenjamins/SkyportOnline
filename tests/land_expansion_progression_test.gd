extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for starter_id in ["north_west", "north", "west", "home"]:
		var starter := grid.get_parcel(starter_id)
		if not bool(starter.get("owned", false)):
			_fail("Starter 16x16 area should own %s." % starter_id)
			return

	var frontier := grid.get_expansion_frontier()
	var frontier_ids: Array[String] = []
	for parcel in frontier:
		frontier_ids.append(String(parcel.get("id", "")))
	frontier_ids.sort()

	var expected_initial: Array[String] = [
		"east",
		"north_east",
		"south",
		"south_west"
	]
	expected_initial.sort()
	if frontier_ids != expected_initial:
		_fail(
			"Initial expansion frontier should surround the new 16x16 starter airfield."
		)
		return

	var south_east := grid.get_parcel("south_east")
	if String(south_east.get("progression_state", "")) != "future":
		_fail("South-east runway reserve should begin disconnected.")
		return
	if bool(south_east.get("adjacent_to_owned", true)):
		_fail("South-east should not initially touch the starter 16x16 area.")
		return
	if grid.purchase_parcel("south_east"):
		_fail("Disconnected south-east purchase must be rejected.")
		return

	var east := grid.get_parcel("east")
	if String(east.get("progression_state", "")) != "available":
		_fail("Regional Apron should begin on the first expansion frontier.")
		return
	if not grid.purchase_parcel("east"):
		_fail("Connected east parcel should be purchasable.")
		return

	south_east = grid.get_parcel("south_east")
	if String(south_east.get("progression_state", "")) != "available":
		_fail("Buying east should connect the south-east runway reserve.")
		return
	if not bool(south_east.get("adjacent_to_owned", false)):
		_fail("South-east should now report an owned neighbor.")
		return

	if not grid.purchase_parcel("south_east"):
		_fail("Newly connected runway reserve should now be purchasable.")
		return

	var restored := AirportGrid.new()
	root.add_child(restored)
	await process_frame
	if not restored.apply_saved_airport_layout(
		grid.export_airport_layout(),
		grid.export_owned_parcels(),
		grid.export_airport_storage()
	):
		_fail("Expanded ownership should restore cleanly.")
		return

	for starter_id in ["north_west", "north", "west", "home"]:
		if not bool(restored.get_parcel(starter_id).get("owned", false)):
			_fail("Starter 16x16 ownership should survive save/restore.")
			return
	if not bool(restored.get_parcel("south_east").get("owned", false)):
		_fail("Purchased runway reserve should survive save/restore.")
		return

	print(
		"Land progression passed: 16x16 starter ownership, frontier, "
		+ "runway-reserve gating and restore."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
