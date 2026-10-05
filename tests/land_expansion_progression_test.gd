extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var frontier := grid.get_expansion_frontier()
	var frontier_ids: Array[String] = []
	for parcel in frontier:
		frontier_ids.append(
			String(parcel.get("id", ""))
		)
	frontier_ids.sort()

	var expected_initial: Array[String] = [
		"east",
		"north",
		"south",
		"west"
	]
	expected_initial.sort()
	if frontier_ids != expected_initial:
		_fail(
			"Initial expansion frontier should be the four parcels next to home."
		)
		return

	var north_west := grid.get_parcel("north_west")
	if String(
		north_west.get("progression_state", "")
	) != "future":
		_fail("North-west should begin as future land.")
		return
	if bool(
		north_west.get("adjacent_to_owned", true)
	):
		_fail("North-west should not initially touch owned land.")
		return
	if grid.purchase_parcel("north_west"):
		_fail("Disconnected corner purchase must be rejected.")
		return

	var north := grid.get_parcel("north")
	if String(
		north.get("progression_state", "")
	) != "available":
		_fail("North should begin as the first expansion ring.")
		return
	if not grid.purchase_parcel("north"):
		_fail("Connected north parcel should be purchasable.")
		return

	north_west = grid.get_parcel("north_west")
	if String(
		north_west.get("progression_state", "")
	) != "available":
		_fail("Buying north should unlock north-west as the next frontier.")
		return
	if not bool(
		north_west.get("adjacent_to_owned", false)
	):
		_fail("North-west should now report an owned neighbor.")
		return

	var north_east := grid.get_parcel("north_east")
	if String(
		north_east.get("progression_state", "")
	) != "available":
		_fail("Buying north should also unlock north-east.")
		return

	if not grid.purchase_parcel("north_west"):
		_fail("Newly connected corner should now be purchasable.")
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

	var restored_corner := restored.get_parcel("north_west")
	if not bool(restored_corner.get("owned", false)):
		_fail("Owned corner should survive save/restore.")
		return

	print(
		"Land progression passed: frontier, adjacency, corner gating and restore."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
