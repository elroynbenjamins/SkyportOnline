extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var fuel := _find_building(grid, "basic_fuel")
	var runway := _find_building(grid, "short_runway")
	if fuel.is_empty() or runway.is_empty():
		_fail("Starter airport should contain fuel and runway buildings.")
		return

	var fuel_uid := int(fuel.get("uid", -1))
	if not grid.purchase_parcel("north"):
		_fail("North parcel should unlock for edit-feedback testing.")
		return

	var start := grid.begin_move_preview(fuel_uid)
	if not bool(start.get("valid", false)):
		_fail("Movable fuel building should enter move preview.")
		return
	if not grid.is_placement_focus_active():
		_fail("Active move preview should enable edit-focus dimming.")
		return

	var target := Vector2i(10, 3)
	var target_world := grid.tile_to_world(
		Vector2(target.x, target.y)
	)
	var status := grid.set_move_preview(
		target_world,
		0
	)
	if not bool(status.get("valid", false)):
		_fail("Feedback target should be a valid move position.")
		return
	if not grid.is_preview_snap_feedback_active():
		_fail("Crossing into a new grid cell should trigger snap feedback.")
		return

	grid._process(0.25)
	if grid.is_preview_snap_feedback_active():
		_fail("Snap feedback should expire quickly.")
		return

	grid.set_move_preview(target_world, 0)
	if grid.is_preview_snap_feedback_active():
		_fail("Remaining on the same grid cell must not retrigger snap feedback.")
		return

	var result := grid.confirm_move_preview()
	if result.is_empty():
		_fail("Valid move should confirm.")
		return
	if grid.is_placement_focus_active():
		_fail("Confirmed move should leave placement-focus mode.")
		return
	if grid.get_placement_confirm_feedback_count() != 1:
		_fail("Confirmed move should create one placement pulse.")
		return

	grid._process(0.60)
	if grid.get_placement_confirm_feedback_count() != 0:
		_fail("Placement confirmation pulse should expire automatically.")
		return

	start = grid.begin_move_preview(fuel_uid)
	if not bool(start.get("valid", false)):
		_fail("Moved building should remain movable.")
		return
	var second_target := Vector2i(12, 3)
	status = grid.set_move_preview(
		grid.tile_to_world(
			Vector2(second_target.x, second_target.y)
		),
		0
	)
	if not bool(status.get("valid", false)):
		_fail("Second edit target should be valid.")
		return
	if not grid.is_preview_snap_feedback_active():
		_fail("Second target should trigger snap feedback.")
		return

	grid.clear_build_preview()
	if grid.is_preview_snap_feedback_active():
		_fail("Cancel should immediately clear transient snap feedback.")
		return
	if grid.is_placement_focus_active():
		_fail("Cancel should restore normal airport focus.")
		return

	var moved := grid.get_building(fuel_uid)
	var moved_origin: Vector2i = moved.get(
		"origin",
		Vector2i.ZERO
	)
	grid.set_hover_world_position(
		grid.tile_to_world(
			Vector2(moved_origin.x, moved_origin.y)
		)
	)
	if grid.get_hovered_building_uid() != fuel_uid:
		_fail("Desktop hover should identify movable buildings.")
		return

	var runway_origin: Vector2i = runway.get(
		"origin",
		Vector2i.ZERO
	)
	grid.set_hover_world_position(
		grid.tile_to_world(
			Vector2(runway_origin.x, runway_origin.y)
		)
	)
	if grid.get_hovered_building_uid() >= 0:
		_fail("Fixed runway infrastructure should not receive edit hover.")
		return

	grid.clear_building_selection()
	if grid.get_hovered_building_uid() >= 0:
		_fail("Clearing building selection should clear hover state too.")
		return

	print(
		"Layout edit feedback passed: focus dimming, snap lifetime, "
		+ "confirm pulse, cancel cleanup and movable-only hover."
	)
	quit(0)


func _find_building(
	grid: AirportGrid,
	definition_id: String
) -> Dictionary:
	for uid in range(1, 100):
		var building := grid.get_building(uid)
		if String(
			building.get("definition_id", "")
		) == definition_id:
			return building
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
