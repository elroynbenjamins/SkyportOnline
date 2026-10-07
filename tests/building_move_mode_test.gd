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
	var runway_uid := int(runway.get("uid", -1))
	if not bool(
		grid.get_move_eligibility(fuel_uid).get("movable", false)
	):
		_fail("Basic Fuel Station should be movable.")
		return
	if bool(
		grid.get_move_eligibility(runway_uid).get("movable", true)
	):
		_fail("Runways should remain fixed infrastructure.")
		return

	grid.set_building_upgrade_level(fuel_uid, 3)
	var original := grid.get_building(fuel_uid)
	var original_origin: Vector2i = original.get(
		"origin",
		Vector2i(-1, -1)
	)

	var start_status := grid.begin_move_preview(fuel_uid)
	if not bool(start_status.get("valid", false)):
		_fail(
			"Move preview must ignore the selected building's own occupied cells."
		)
		return

	var blocked := grid.set_move_preview(
		grid.tile_to_world(Vector2(8, 8)),
		0
	)
	if bool(blocked.get("valid", false)):
		_fail("Move preview should reject overlap with the runway.")
		return

	grid.clear_build_preview()
	var after_cancel := grid.get_building(fuel_uid)
	if after_cancel.get("origin", Vector2i.ZERO) != original_origin:
		_fail("Cancel should restore the exact original building position.")
		return
	if int(after_cancel.get("upgrade_level", 1)) != 3:
		_fail("Cancel should preserve building upgrade state.")
		return

	grid.select_parcel("north")
	grid.purchase_selected()

	start_status = grid.begin_move_preview(fuel_uid)
	if not bool(start_status.get("valid", false)):
		_fail("Movable building should re-enter move mode after cancel.")
		return

	var target := Vector2i(13, 0)
	var target_status := grid.set_move_preview(
		grid.tile_to_world(Vector2(target.x, target.y)),
		0
	)
	if not bool(target_status.get("valid", false)):
		_fail(
			"Unlocked empty land should accept the building move: %s"
			% String(target_status.get("reason", "unknown"))
		)
		return

	var moved_result := grid.confirm_move_preview()
	if moved_result.is_empty():
		_fail("Confirm should commit a valid building move.")
		return

	var moved := grid.get_building(fuel_uid)
	if moved.get("origin", Vector2i.ZERO) != target:
		_fail("Confirmed building should use the new grid origin.")
		return
	if int(moved.get("upgrade_level", 1)) != 3:
		_fail("Moving a building must preserve its upgrade level.")
		return

	var undo_result := grid.restore_building_position(original)
	if not bool(undo_result.get("valid", false)):
		_fail("Undo should restore the previous valid building position.")
		return
	var undone := grid.get_building(fuel_uid)
	if undone.get("origin", Vector2i.ZERO) != original_origin:
		_fail("Undo should return the building to its original origin.")
		return
	if int(undone.get("upgrade_level", 1)) != 3:
		_fail("Undo must not roll back building upgrade progress.")
		return

	start_status = grid.begin_move_preview(fuel_uid)
	if not bool(start_status.get("valid", false)):
		_fail("Building should remain movable after an undo.")
		return
	target_status = grid.set_move_preview(
		grid.tile_to_world(Vector2(target.x, target.y)),
		0
	)
	if not bool(target_status.get("valid", false)):
		_fail("Move target should remain valid after undo.")
		return
	moved_result = grid.confirm_move_preview()
	if moved_result.is_empty():
		_fail("Building should be movable again after undo.")
		return

	var saved_layout := grid.export_airport_layout()
	var saved_parcels := grid.export_owned_parcels()
	if not saved_parcels.has("north"):
		_fail("Owned parcel state should be exported with the layout.")
		return

	var restored_grid := AirportGrid.new()
	root.add_child(restored_grid)
	await process_frame
	# Default AirportGrid is also the visual-QA showcase and now spans several
	# districts. Restore that showcase with all of its parcels available so this
	# test remains focused on move position and upgrade persistence.
	var restore_parcels: Array[String] = []
	for parcel_id_variant in grid.parcels.keys():
		restore_parcels.append(String(parcel_id_variant))
	if not restored_grid.apply_saved_airport_layout(
		saved_layout,
		restore_parcels
	):
		_fail("Saved airport layout should restore cleanly.")
		return

	var restored := restored_grid.get_building(fuel_uid)
	if restored.get("origin", Vector2i.ZERO) != target:
		_fail("Restored layout should keep the moved building position.")
		return
	if int(restored.get("upgrade_level", 1)) != 3:
		_fail("Restored layout should keep the moved building upgrade level.")
		return


	var atc := grid._place_building_internal(
		"atc_tower",
		Vector2i(2, 2),
		0
	)
	grid._rebuild_occupied_cells()
	var atc_definition := BuildingCatalog.get_definition(
		"atc_tower"
	)
	var atc_footprint := grid._footprint_for(
		atc_definition,
		0
	)
	var atc_center := grid._footprint_center_world(
		Vector2i(2, 2),
		atc_footprint
	)
	var tower_cab_point := atc_center + Vector2(0, -70)
	var cab_tile := grid.world_to_tile(tower_cab_point)
	if grid.occupied_cells.has(
		grid._cell_key(cab_tile)
	):
		_fail(
			"ATC visual-hit test point must sit above its ground footprint."
		)
		return

	var visual_hit := grid._building_at_visual_position(
		tower_cab_point
	)
	if int(visual_hit.get("uid", -1)) != int(
		atc.get("uid", -2)
	):
		_fail(
			"Tapping the visible upper ATC artwork should select the tower."
		)
		return

	var selected_visual_uids: Array[int] = []
	grid.building_selected_world.connect(
		func(selected: Dictionary) -> void:
			selected_visual_uids.append(
				int(selected.get("uid", -1))
			)
	)
	grid.select_world_position(tower_cab_point)
	if (
		selected_visual_uids.is_empty()
		or selected_visual_uids[-1] != int(
			atc.get("uid", -2)
		)
	):
		_fail(
			"World selection should use visible sprite art before ground-tile fallback."
		)
		return

	print(
		"Building move mode passed: eligibility, self-overlap, collision, "
		+ "cancel, confirm, upgrade preservation, layout restore and "
		+ "high-detail visual hit selection."
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
