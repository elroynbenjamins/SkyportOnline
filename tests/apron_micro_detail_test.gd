extends SceneTree

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var snapshot := grid.get_apron_micro_detail_snapshot()
	if int(snapshot.get("stands", 0)) != 2:
		_fail("Starter airport should expose two detailed aircraft stands.")
	if int(snapshot.get("stand_guidance", 0)) != 2:
		_fail("Each starter stand should have guidance markings.")
	if int(snapshot.get("stand_service_zones", 0)) != 4:
		_fail("Each starter stand should expose two service staging zones.")
	if int(snapshot.get("cart_bays", 0)) != 2:
		_fail("Each starter stand should expose a cart bay.")
	if int(snapshot.get("passenger_pads", 0)) != 2:
		_fail("Starter Terminal and Travel Office should receive passenger pad detail.")
	if int(snapshot.get("pedestrian_crossings", 0)) != 2:
		_fail("Passenger pads should expose pedestrian/safety crossings.")
	if int(snapshot.get("service_pads", 0)) != 2:
		_fail("Ground Ops and Basic Fuel should receive service pad detail.")
	if int(snapshot.get("service_staging_zones", 0)) != 4:
		_fail("Starter service pads should expose two staging zones each.")
	if int(snapshot.get("utility_cabinets", 0)) != 4:
		_fail("Passenger/service facilities should expose apron utility props.")

	var terminal := _find_building(
		grid,
		"small_terminal"
	)
	if terminal.is_empty():
		_fail("Starter airport should contain the Small Terminal.")
	else:
		var terminal_uid := int(
			terminal.get("uid", -1)
		)
		var eligibility := grid.get_move_eligibility(
			terminal_uid
		)
		if not bool(eligibility.get("movable", false)):
			_fail("Small Terminal must remain movable after apron-detail changes.")
		else:
			grid.select_parcel("north")
			grid.purchase_selected()

			var begin := grid.begin_move_preview(
				terminal_uid
			)
			if not bool(begin.get("valid", false)):
				_fail("Movable Terminal should enter move mode.")
			else:
				var target := Vector2i(-1, -1)
				var target_status: Dictionary = {}
				for y in range(0, 8):
					for x in range(8, 16):
						var candidate := Vector2i(x, y)
						target_status = grid.set_move_preview(
							grid.tile_to_world(
								Vector2(
									candidate.x,
									candidate.y
								)
							),
							1
						)
						if bool(
							target_status.get(
								"valid",
								false
							)
						):
							target = candidate
							break
					if target.x >= 0:
						break

				if target.x < 0:
					_fail(
						"Purchased north land should offer a valid rotated Terminal move target."
					)
				else:
					var moved_result := (
						grid.confirm_move_preview()
					)
					if moved_result.is_empty():
						_fail(
							"Terminal move should confirm on valid owned land."
						)
					else:
						var moved := grid.get_building(
							terminal_uid
						)
						if (
							moved.get(
								"origin",
								Vector2i(-1, -1)
							) != target
						):
							_fail(
								"Moved Terminal should use its new apron-detail origin."
							)
						if int(
							moved.get(
								"rotation",
								0
							)
						) != 1:
							_fail(
								"Moved Terminal should keep the chosen alternate-angle rotation."
							)

						var after := grid.get_apron_micro_detail_snapshot()
						if after != snapshot:
							_fail(
								"Moving/rotating the Terminal must preserve apron micro-detail coverage counts."
							)

						var restored := grid.restore_building_position(
							terminal
						)
						if not bool(
							restored.get(
								"valid",
								false
							)
						):
							_fail(
								"Terminal should restore to its original placement after move testing."
							)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"APRON_MICRO_DETAIL_OK stands=%d passenger=%d service=%d utilities=%d terminal_move=true"
		% [
			int(snapshot.get("stands", 0)),
			int(snapshot.get("passenger_pads", 0)),
			int(snapshot.get("service_pads", 0)),
			int(snapshot.get("utility_cabinets", 0))
		]
	)
	quit(0)


func _find_building(
	grid: AirportGrid,
	definition_id: String
) -> Dictionary:
	for uid in range(1, 100):
		var building := grid.get_building(uid)
		if String(
			building.get(
				"definition_id",
				""
			)
		) == definition_id:
			return building
	return {}


func _fail(message: String) -> void:
	errors.append(message)
