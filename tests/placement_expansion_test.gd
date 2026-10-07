extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var target := Vector2i(13, 0)
	var status := grid.set_build_preview(
		"basic_fuel",
		grid.tile_to_world(
			Vector2(target.x, target.y)
		),
		0
	)
	if bool(status.get("valid", false)):
		_fail("Locked north parcel should block this placement.")
		return
	if String(
		status.get("locked_parcel_id", "")
	) != "north":
		_fail("Placement should identify the north parcel as the blocker.")
		return
	if int(status.get("locked_parcel_level", 0)) != 5:
		_fail("Placement should expose the parcel level requirement.")
		return
	if int(status.get("locked_parcel_cost", 0)) != 25000:
		_fail("Placement should expose the parcel expansion cost.")
		return
	if not grid.has_build_preview():
		_fail("Blocked placement should remain an active preview.")
		return

	var parcel := grid.get_parcel("north")
	if parcel.is_empty() or bool(parcel.get("owned", true)):
		_fail("North parcel should begin locked.")
		return

	if not grid.purchase_parcel("north"):
		_fail("Direct parcel purchase should unlock locked placement land.")
		return
	if not grid.is_parcel_unlock_animation_active("north"):
		_fail("Placement-time expansion should trigger the unlock effect.")
		return

	parcel = grid.get_parcel("north")
	if not bool(parcel.get("owned", false)):
		_fail("Purchased parcel should report owned immediately.")
		return

	var refreshed := grid.refresh_build_preview(0)
	if not bool(refreshed.get("valid", false)):
		_fail(
			"Same building preview should become valid after expansion: %s"
			% String(refreshed.get("reason", "unknown"))
		)
		return
	if not grid.has_build_preview():
		_fail("Expansion must not clear the active placement preview.")
		return
	if refreshed.get("origin", Vector2i.ZERO) != target:
		_fail("Expansion must preserve the exact preview origin.")
		return

	var placed := grid.confirm_build_preview()
	if placed.is_empty():
		_fail("Expanded placement should still be confirmable.")
		return
	if placed.get("origin", Vector2i.ZERO) != target:
		_fail("Confirmed building should remain at the previewed target.")
		return

	var multi_grid := AirportGrid.new()
	root.add_child(multi_grid)
	await process_frame

	var future_only := multi_grid.set_build_preview(
		"basic_fuel",
		multi_grid.tile_to_world(Vector2(3, 3)),
		0
	)
	if String(
		future_only.get("locked_parcel_id", "")
	) != "north_west":
		_fail("Future-only placement should identify north-west.")
		return
	if String(
		future_only.get("locked_parcel_state", "")
	) != "future":
		_fail("Disconnected placement land should report future state.")
		return
	if bool(
		future_only.get("locked_parcel_adjacent", true)
	):
		_fail("Future-only parcel should not report owned adjacency.")
		return

	var multi_target := Vector2i(13, 4)
	var multi_status := multi_grid.set_build_preview(
		"small_hangar",
		multi_grid.tile_to_world(
			Vector2(multi_target.x, multi_target.y)
		),
		0
	)
	if int(multi_status.get("locked_parcel_count", 0)) != 2:
		_fail("Large footprint should report both locked parcels.")
		return

	var first_locked := String(
		multi_status.get("locked_parcel_id", "")
	)
	if first_locked.is_empty():
		_fail("Multi-parcel placement should expose the first expansion.")
		return
	if not multi_grid.purchase_parcel(first_locked):
		_fail("First required parcel should be purchasable.")
		return

	multi_status = multi_grid.refresh_build_preview(0)
	if bool(multi_status.get("valid", false)):
		_fail("One expansion should not unlock a two-parcel footprint.")
		return
	var second_locked := String(
		multi_status.get("locked_parcel_id", "")
	)
	if (
		second_locked.is_empty()
		or second_locked == first_locked
	):
		_fail("Revalidation should advance to the next locked parcel.")
		return
	if not multi_grid.purchase_parcel(second_locked):
		_fail("Second required parcel should be purchasable.")
		return

	multi_status = multi_grid.refresh_build_preview(0)
	if not bool(multi_status.get("valid", false)):
		_fail("Preview should become valid after both parcels unlock.")
		return
	if multi_status.get("origin", Vector2i.ZERO) != multi_target:
		_fail("Sequential expansion must preserve the large preview origin.")
		return

	print(
		"Placement expansion passed: locked parcel metadata, purchase, "
		+ "preview preservation and immediate confirmation."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
