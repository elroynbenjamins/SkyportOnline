extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var build_profile := PlacementVisualRules.profile(
		"build",
		true,
		true
	)
	var move_profile := PlacementVisualRules.profile(
		"move",
		true,
		true
	)
	if float(move_profile.get("lift_px", 0.0)) <= float(
		build_profile.get("lift_px", 0.0)
	):
		_fail("Move preview should look more lifted than build preview.")
		return
	if not bool(
		build_profile.get("show_rotation_hint", false)
	):
		_fail("Rotatable preview should expose its rotation cue.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var stand := _find_building(grid, "small_stand")
	if stand.is_empty():
		_fail("Starter airport should contain a Small Stand.")
		return

	var stand_uid := int(stand.get("uid", -1))
	var start_status := grid.begin_move_preview(stand_uid)
	if not bool(start_status.get("valid", false)):
		_fail("Starter stand should enter move preview.")
		return

	var start_visual := grid.get_preview_visual_snapshot()
	if String(start_visual.get("mode", "")) != "move":
		_fail("Move preview snapshot should report move mode.")
		return
	if float(start_visual.get("lift_px", 0.0)) < 12.0:
		_fail("Move preview should use a visibly lifted ghost.")
		return
	if not bool(start_visual.get("snap_active", false)):
		_fail("Entering move mode should trigger snap feedback.")
		return

	var start_connection: Dictionary = start_visual.get(
		"connection",
		{}
	)
	if not bool(start_connection.get("required", false)):
		_fail("Aircraft stand should require a taxiway connection hint.")
		return
	if not bool(start_connection.get("connected", false)):
		_fail("Starter Small Stand should show connected taxiway feedback.")
		return
	if int(start_connection.get("adjacent_count", 0)) <= 0:
		_fail("Connected stand should expose adjacent taxiway targets.")
		return

	var initial_sequence := int(
		start_visual.get("snap_sequence", 0)
	)
	var origin: Vector2i = stand.get(
		"origin",
		Vector2i.ZERO
	)
	grid.set_move_preview(
		grid.tile_to_world(Vector2(origin.x, origin.y)),
		int(stand.get("rotation", 0))
	)
	var same_tile := grid.get_preview_visual_snapshot()
	if int(same_tile.get("snap_sequence", 0)) != initial_sequence:
		_fail("Same snapped tile should not retrigger feedback.")
		return

	grid.select_parcel("north")
	grid.purchase_selected()
	var disconnected_target := Vector2i(9, 2)
	var target_status := grid.set_move_preview(
		grid.tile_to_world(
			Vector2(
				disconnected_target.x,
				disconnected_target.y
			)
		),
		0
	)
	if not bool(target_status.get("valid", false)):
		_fail(
			"Unlocked empty target should remain a valid move even "
			+ "without taxiway connection."
		)
		return

	var disconnected_visual := grid.get_preview_visual_snapshot()
	if int(
		disconnected_visual.get("snap_sequence", 0)
	) <= initial_sequence:
		_fail("Changing grid cell should trigger snap feedback.")
		return
	var disconnected: Dictionary = disconnected_visual.get(
		"connection",
		{}
	)
	if bool(disconnected.get("connected", true)):
		_fail("Remote stand preview should show missing taxiway connection.")
		return
	if not bool(disconnected.get("target_valid", false)):
		_fail(
			"Missing connection hint should point toward nearest "
			+ "reachable taxiway."
		)
		return
	if int(disconnected.get("distance", 0)) <= 1:
		_fail("Remote stand should report a non-adjacent taxiway distance.")
		return

	var before_rotate := int(
		disconnected_visual.get("snap_sequence", 0)
	)
	grid.refresh_build_preview(1)
	var rotated_visual := grid.get_preview_visual_snapshot()
	if int(rotated_visual.get("snap_sequence", 0)) <= before_rotate:
		_fail("Rotation should trigger snap/orientation feedback.")
		return

	grid.clear_build_preview()
	var cleared := grid.get_preview_visual_snapshot()
	if bool(cleared.get("active", true)):
		_fail("Clearing preview should remove placement visuals.")
		return
	if bool(cleared.get("snap_active", true)):
		_fail("Clearing preview should stop snap animation.")
		return

	var hangar_definition := BuildingCatalog.get_definition(
		"small_hangar"
	)
	if hangar_definition.is_empty():
		_fail("Small Hangar definition should exist.")
		return

	var build_status := grid.set_build_preview(
		"small_hangar",
		grid.tile_to_world(Vector2(10, 2)),
		0
	)
	if not bool(build_status.get("valid", false)):
		_fail("Small Hangar should preview on unlocked empty land.")
		return
	var build_visual := grid.get_preview_visual_snapshot()
	if String(build_visual.get("mode", "")) != "build":
		_fail("New placement should report build mode.")
		return
	if float(build_visual.get("lift_px", 0.0)) >= float(
		move_profile.get("lift_px", 0.0)
	):
		_fail("New-build ghost should be lifted less than move ghost.")
		return

	print(
		"Placement game-feel passed: lifted ghosts, snap feedback, "
		+ "rotation cue metadata and live taxiway connection hints."
	)
	quit(0)


func _find_building(
	grid: AirportGrid,
	definition_id: String
) -> Dictionary:
	for uid in range(1, 80):
		var building := grid.get_building(uid)
		if String(
			building.get("definition_id", "")
		) == definition_id:
			return building
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
