extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if grid.is_expansion_mode_active():
		_fail("Expansion mode should be off during normal airport play.")
		return
	if not grid.get_selected_parcel().is_empty():
		_fail("Normal airport view should not begin with a selected parcel.")
		return

	var north_visual := grid.get_parcel_visual_state("north")
	if bool(north_visual.get("show_boundary", true)):
		_fail("Normal airport view should hide expansion boundaries.")
		return

	var north_label: Label = grid.parcel_labels.get("north")
	if north_label == null or north_label.visible:
		_fail("Expansion sale labels should be hidden in normal play.")
		return

	grid.select_world_position(
		grid.get_parcel_world_center("north")
	)
	if not grid.get_selected_parcel().is_empty():
		_fail("Tapping empty expansion land in normal play should do nothing.")
		return

	grid.set_expansion_mode(true)
	if not grid.is_expansion_mode_active():
		_fail("Shop expansion action should enable expansion mode.")
		return

	var candidates := grid.get_expansion_candidate_ids()
	for expected_id in ["north", "east", "south", "west"]:
		if not candidates.has(expected_id):
			_fail("Expansion mode should expose adjacent plot: %s" % expected_id)
			return
	if candidates.has("north_west"):
		_fail("Disconnected future plots must not be selectable.")
		return

	north_visual = grid.get_parcel_visual_state("north")
	if not bool(north_visual.get("show_boundary", false)):
		_fail("Adjacent plot should become visible in expansion mode.")
		return
	if north_label == null or not north_label.visible:
		_fail("Available plot should show its price label in expansion mode.")
		return

	var future_visual := grid.get_parcel_visual_state("north_west")
	if bool(future_visual.get("show_boundary", true)):
		_fail("Future plots should remain hidden while choosing expansion.")
		return

	grid.select_world_position(
		grid.get_parcel_world_center("north")
	)
	if String(
		grid.get_selected_parcel().get("id", "")
	) != "north":
		_fail("Player should be able to select a highlighted adjacent plot.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.enter_expansion_mode()
	if not hud.is_expansion_mode_active():
		_fail("HUD should expose an explicit expansion selection mode.")
		return
	if not hud.parcel_panel.visible:
		_fail("Expansion context should appear only after entering expansion mode.")
		return
	if (
		hud.expansion_cancel_button == null
		or not hud.expansion_cancel_button.visible
	):
		_fail("Expansion mode should provide a clear cancel action.")
		return

	hud.show_parcel(grid.get_selected_parcel(), 5, 50000)
	if hud.purchase_button.disabled:
		_fail("Eligible selected land should be purchasable from expansion mode.")
		return

	hud.exit_expansion_mode(false)
	if hud.parcel_panel.visible:
		_fail("Leaving expansion mode should restore the clean airport view.")
		return

	grid.set_expansion_mode(false)
	if north_label.visible:
		_fail("Expansion labels should disappear immediately after leaving mode.")
		return

	print(
		"EXPANSION_SHOP_MODE_OK normal_hidden=true candidates=4 "
		+ "future_hidden=true selectable=true hud_mode=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
