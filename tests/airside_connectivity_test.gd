extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var starter := grid.get_airside_status()
	if int(starter.get("runways", 0)) != 1:
		_fail("Starter airport should have one runway.")
		return
	if int(starter.get("stands_total", 0)) != 1:
		_fail("Starter airport should have one stand.")
		return
	if int(starter.get("stands_connected", 0)) != 1:
		_fail("Starter stand should connect to its runway through taxiway.")
		return

	var starter_route := grid.get_first_departure_route()
	if starter_route.size() < 4:
		_fail("Starter airport should expose a stand-to-runway departure route.")
		return

	var disconnected_position := grid.tile_to_world(Vector2(14, 10))
	var preview := grid.set_build_preview("small_stand", disconnected_position, 0)
	if not bool(preview.get("valid", false)):
		_fail("Disconnected stand test placement should be buildable.")
		return
	if String(preview.get("warning", "")).is_empty():
		_fail("Disconnected stand preview should show a taxiway warning.")
		return

	grid.confirm_build_preview()
	var disconnected := grid.get_airside_status()
	if int(disconnected.get("stands_total", 0)) != 2:
		_fail("Expected two stands after test placement.")
		return
	if int(disconnected.get("stands_connected", 0)) != 1:
		_fail("Second stand should remain disconnected before adding taxiway.")
		return

	var connector_position := grid.tile_to_world(Vector2(13, 10))
	var connector_preview := grid.set_build_preview("taxiway", connector_position, 0)
	if not bool(connector_preview.get("valid", false)):
		_fail("Connector taxiway test placement should be valid.")
		return

	grid.confirm_build_preview()
	var connected := grid.get_airside_status()
	if int(connected.get("stands_connected", 0)) != 2:
		_fail("Both stands should connect after extending the taxiway.")
		return

	print("Airside connectivity test passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
