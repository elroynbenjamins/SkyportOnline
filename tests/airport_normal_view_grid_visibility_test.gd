extends SceneTree

# The isometric construction grid is an editing tool, not permanent ground
# artwork. A player must see authored scenery in ordinary airport play.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if grid.is_placement_grid_visible():
		_fail("Normal airport view must hide construction grid.")
		return

	var preview := grid.set_build_preview(
		"short_runway",
		grid.tile_to_world(Vector2(3, 4)),
		0
	)
	if not grid.is_placement_grid_visible():
		_fail("Building preview must reveal construction grid.")
		return

	grid.clear_build_preview()
	if grid.is_placement_grid_visible():
		_fail("Closing placement must hide construction grid again.")
		return

	grid.set_expansion_mode(true)
	if grid.is_placement_grid_visible():
		_fail("Land-expansion highlights must not force every grid line.")
		return

	grid.set_expansion_mode(false)
	if grid.is_placement_grid_visible():
		_fail("Returning to normal play must keep grid hidden.")
		return

	print("AIRPORT_GRID_VISIBILITY_OK normal=hidden preview=visible")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
