extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i,
	rotation: int = 0
) -> Dictionary:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		rotation
	)
	if not bool(preview.get("valid", false)):
		return {
			"placed": false,
			"preview": preview
		}
	return {
		"placed": not grid.confirm_build_preview().is_empty(),
		"preview": preview
	}


func _preview(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i,
	rotation: int = 0
) -> Dictionary:
	var status := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		rotation
	)
	grid.clear_build_preview()
	return status


func _run() -> void:
	var short_def := BuildingCatalog.get_definition(
		"short_runway"
	)
	var regional_def := BuildingCatalog.get_definition(
		"regional_runway"
	)
	for definition in [short_def, regional_def]:
		if String(
			definition.get(
				"runway_direction_policy",
				""
			)
		) != "origin_to_long_axis_end":
			_fail("Every runway must declare the directional runway policy.")
			return
		if String(
			definition.get(
				"runway_taxi_exit_policy",
				""
			)
		) != "rollout_end_four":
			_fail("Every runway must use rollout_end_four taxi exits.")
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	var runway_result := _place(
		grid,
		"short_runway",
		Vector2i(4, 4),
		0
	)
	if not bool(runway_result.get("placed", false)):
		_fail("Could not place horizontal Short Runway for policy test.")
		return

	var runway_uid := -1
	for building_variant in grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get(
				"definition_id",
				""
			)
		) == "short_runway":
			runway_uid = int(
				building.get("uid", -1)
			)
			break
	if runway_uid < 0:
		_fail("Placed Short Runway UID not found.")
		return

	var snapshot := grid.get_runway_exit_policy_snapshot(
		runway_uid
	)
	if String(
		snapshot.get(
			"taxi_exit_policy",
			""
		)
	) != "rollout_end_four":
		_fail("Short Runway snapshot should expose rollout_end_four.")
		return
	var nodes: Array = snapshot.get(
		"exit_nodes",
		[]
	)
	if nodes.size() != 4:
		_fail("Short Runway should expose exactly four rollout-end exit nodes.")
		return

	var expected_horizontal := [
		Vector2i(9, 4),
		Vector2i(9, 5),
		Vector2i(8, 3),
		Vector2i(8, 6)
	]
	for expected in expected_horizontal:
		var found := false
		for node_variant in nodes:
			var node: Dictionary = node_variant
			if node.get(
				"taxiway_cell",
				Vector2i(-1, -1)
			) == expected:
				found = true
				break
		if not found:
			_fail(
				"Missing horizontal runway exit node: %s"
				% str(expected)
			)
			return

	for invalid_cell in [
		Vector2i(4, 3),
		Vector2i(4, 6),
		Vector2i(6, 3),
		Vector2i(6, 6)
	]:
		var status := _preview(
			grid,
			"taxiway",
			invalid_cell
		)
		if bool(status.get("valid", true)):
			_fail(
				"Taxiway must be rejected at runway start/middle: %s"
				% str(invalid_cell)
			)
			return
		if String(
			status.get(
				"runway_exit_rule",
				""
			)
		) != "rollout_end_four":
			_fail("Rejected taxiway should expose the runway exit rule.")
			return

	for valid_cell in expected_horizontal:
		var status := _preview(
			grid,
			"taxiway",
			valid_cell
		)
		if not bool(status.get("valid", false)):
			_fail(
				"Approved runway exit should accept Taxiway: %s (%s)"
				% [
					str(valid_cell),
					String(status.get("reason", "invalid"))
				]
			)
			return

	# Verify rotation keeps START at the origin side and moves END to +Y.
	var rotated := AirportGrid.new()
	root.add_child(rotated)
	await process_frame
	rotated.prepare_new_airport_builder_layout()

	var rotated_result := _place(
		rotated,
		"short_runway",
		Vector2i(4, 4),
		1
	)
	if not bool(rotated_result.get("placed", false)):
		_fail("Could not place rotated Short Runway for policy test.")
		return

	var rotated_uid := -1
	for building_variant in rotated.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get(
				"definition_id",
				""
			)
		) == "short_runway":
			rotated_uid = int(
				building.get("uid", -1)
			)
			break
	var rotated_snapshot := rotated.get_runway_exit_policy_snapshot(
		rotated_uid
	)
	var rotated_nodes: Array = rotated_snapshot.get(
		"exit_nodes",
		[]
	)
	var expected_rotated := [
		Vector2i(4, 9),
		Vector2i(5, 9),
		Vector2i(3, 8),
		Vector2i(6, 8)
	]
	for expected in expected_rotated:
		var found := false
		for node_variant in rotated_nodes:
			var node: Dictionary = node_variant
			if node.get(
				"taxiway_cell",
				Vector2i(-1, -1)
			) == expected:
				found = true
				break
		if not found:
			_fail(
				"Missing rotated runway exit node: %s"
				% str(expected)
			)
			return

	for invalid_cell in [
		Vector2i(3, 4),
		Vector2i(6, 4),
		Vector2i(3, 6),
		Vector2i(6, 6)
	]:
		var status := _preview(
			rotated,
			"taxiway",
			invalid_cell
		)
		if bool(status.get("valid", true)):
			_fail(
				"Rotated runway start/middle must reject Taxiway: %s"
				% str(invalid_cell)
			)
			return

	print(
		"RUNWAY_TAXI_EXIT_POLICY_OK start_closed=true end_nodes=4 "
		+ "rotation=true short_runway=true regional_rule=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
