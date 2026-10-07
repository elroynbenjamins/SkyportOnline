extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not grid.purchase_parcel("north"):
		_fail("North parcel should unlock for construction feedback testing.")
		return

	var target := Vector2i(13, 0)
	var status := grid.set_build_preview(
		"basic_fuel",
		grid.tile_to_world(
			Vector2(target.x, target.y)
		),
		0
	)
	if not bool(status.get("valid", false)):
		_fail("Construction feedback target should be buildable.")
		return

	var placed := grid.confirm_build_preview()
	if placed.is_empty():
		_fail("Valid new building should confirm.")
		return

	var uid := int(placed.get("uid", -1))
	if uid < 0:
		_fail("New building should retain a stable UID.")
		return
	if not grid.is_building_construction_feedback_active(uid):
		_fail("New building should start construction feedback.")
		return
	if grid.get_new_build_construction_feedback_count() != 1:
		_fail("Exactly one new-build construction effect should be active.")
		return
	if grid.get_placement_confirm_feedback_count() != 0:
		_fail(
			"New construction should not reuse the relocation confirmation pulse."
		)
		return

	var visual := grid.get_building_construction_feedback(uid)
	if visual.is_empty():
		_fail("Construction feedback should expose its visual state.")
		return
	if float(visual.get("alpha", 1.0)) >= 1.0:
		_fail("New building should initially fade into full opacity.")
		return
	if float(visual.get("vertical_offset", 0.0)) <= 0.0:
		_fail("New building should initially settle down into position.")
		return

	grid._process(0.41)
	visual = grid.get_building_construction_feedback(uid)
	if visual.is_empty():
		_fail("Construction feedback should still be active halfway through.")
		return
	if float(visual.get("progress", 0.0)) <= 0.0:
		_fail("Construction visual state should advance with time.")
		return
	if float(visual.get("alpha", 0.0)) <= 0.38:
		_fail("Building opacity should increase during construction feedback.")
		return
	if float(visual.get("vertical_offset", 20.0)) >= 12.0:
		_fail("Building should settle toward its final ground position.")
		return

	grid._process(0.50)
	if grid.is_building_construction_feedback_active(uid):
		_fail("Construction feedback should expire automatically.")
		return
	if grid.get_new_build_construction_feedback_count() != 0:
		_fail("Expired construction feedback should be removed.")
		return

	var move_start := grid.begin_move_preview(uid)
	if not bool(move_start.get("valid", false)):
		_fail("Completed new building should remain movable.")
		return

	var move_target := Vector2i(13, 3)
	var move_status := grid.set_move_preview(
		grid.tile_to_world(
			Vector2(move_target.x, move_target.y)
		),
		0
	)
	if not bool(move_status.get("valid", false)):
		_fail("Relocation target should be valid.")
		return

	var moved := grid.confirm_move_preview()
	if moved.is_empty():
		_fail("Completed building should relocate normally.")
		return
	if grid.get_placement_confirm_feedback_count() != 1:
		_fail("Relocation should keep the normal green confirmation pulse.")
		return
	if grid.is_building_construction_feedback_active(uid):
		_fail("Relocation must not restart construction feedback.")
		return

	var quick_grid := AirportGrid.new()
	root.add_child(quick_grid)
	await process_frame
	if not quick_grid.purchase_parcel("north"):
		_fail("Quick-edit construction grid should unlock north.")
		return
	var quick_status := quick_grid.set_build_preview(
		"basic_fuel",
		quick_grid.tile_to_world(Vector2(13, 0)),
		0
	)
	if not bool(quick_status.get("valid", false)):
		_fail("Quick-edit construction target should be valid.")
		return
	var quick_build := quick_grid.confirm_build_preview()
	var quick_uid := int(quick_build.get("uid", -1))
	if not quick_grid.is_building_construction_feedback_active(
		quick_uid
	):
		_fail("Quick-edit building should begin construction feedback.")
		return
	var quick_move := quick_grid.begin_move_preview(quick_uid)
	if not bool(quick_move.get("valid", false)):
		_fail("Freshly built structure should still be immediately editable.")
		return
	if quick_grid.is_building_construction_feedback_active(
		quick_uid
	):
		_fail("Immediate edit should cancel stale construction cosmetics.")
		return

	print(
		"New building construction feedback passed: distinct build-in effect, "
		+ "automatic completion and separate relocation pulse."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
