extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var target := Vector2i(18, 10)
	var status := grid.set_build_preview(
		"basic_fuel",
		grid.tile_to_world(Vector2(target.x, target.y)),
		0
	)
	if bool(status.get("valid", false)):
		_fail("Locked east parcel should block this placement.")
		return
	if String(status.get("locked_parcel_id", "")) != "east":
		_fail("Placement should identify the east parcel as the blocker.")
		return
	if int(status.get("locked_parcel_level", 0)) != 8:
		_fail("Placement should expose the Regional Apron level requirement.")
		return
	if int(status.get("locked_parcel_cost", 0)) != 50000:
		_fail("Placement should expose the Regional Apron expansion cost.")
		return
	if not grid.has_build_preview():
		_fail("Blocked placement should remain an active preview.")
		return

	if not grid.purchase_parcel("east"):
		_fail("Direct parcel purchase should unlock locked placement land.")
		return
	if not grid.is_parcel_unlock_animation_active("east"):
		_fail("Placement-time expansion should trigger the unlock effect.")
		return

	var refreshed := grid.refresh_build_preview(0)
	if not bool(refreshed.get("valid", false)):
		_fail(
			"Same building preview should become valid after expansion: %s"
			% String(refreshed.get("reason", "unknown"))
		)
		return
	if refreshed.get("origin", Vector2i.ZERO) != target:
		_fail("Expansion must preserve the exact preview origin.")
		return

	var placed := grid.confirm_build_preview()
	if placed.is_empty() or placed.get("origin", Vector2i.ZERO) != target:
		_fail("Expanded placement should confirm at the previewed target.")
		return

	var multi_grid := AirportGrid.new()
	root.add_child(multi_grid)
	await process_frame

	var future_only := multi_grid.set_build_preview(
		"basic_fuel",
		multi_grid.tile_to_world(Vector2(18, 18)),
		0
	)
	if String(future_only.get("locked_parcel_id", "")) != "south_east":
		_fail("Future-only placement should identify south-east.")
		return
	if String(future_only.get("locked_parcel_state", "")) != "future":
		_fail("Disconnected runway-reserve land should report future state.")
		return
	if bool(future_only.get("locked_parcel_adjacent", true)):
		_fail("Future-only parcel should not report owned adjacency.")
		return

	var multi_target := Vector2i(14, 17)
	var multi_status := multi_grid.set_build_preview(
		"short_runway",
		multi_grid.tile_to_world(Vector2(multi_target.x, multi_target.y)),
		0
	)
	if int(multi_status.get("locked_parcel_count", 0)) != 2:
		_fail("Large runway footprint should report south and south-east parcels.")
		return

	var first_locked := String(multi_status.get("locked_parcel_id", ""))
	if first_locked != "south":
		_fail("South should be the first adjacent expansion for this runway footprint.")
		return
	if not multi_grid.purchase_parcel(first_locked):
		_fail("First required parcel should be purchasable.")
		return

	multi_status = multi_grid.refresh_build_preview(0)
	if bool(multi_status.get("valid", false)):
		_fail("One expansion should not unlock a two-parcel runway footprint.")
		return
	var second_locked := String(multi_status.get("locked_parcel_id", ""))
	if second_locked != "south_east":
		_fail("Revalidation should advance to the runway reserve.")
		return
	if not multi_grid.purchase_parcel(second_locked):
		_fail("Second required parcel should be purchasable after south connects it.")
		return

	multi_status = multi_grid.refresh_build_preview(0)
	if not bool(multi_status.get("valid", false)):
		_fail("Preview should become valid after both parcels unlock.")
		return
	if multi_status.get("origin", Vector2i.ZERO) != multi_target:
		_fail("Sequential expansion must preserve the large preview origin.")
		return

	print(
		"Placement expansion passed: 16x16 starter boundary, locked parcel "
		+ "metadata, sequential runway expansion and preview preservation."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
