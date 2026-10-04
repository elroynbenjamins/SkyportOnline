extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)

	var grid := AirportGrid.new()
	grid.name = "AirportGrid"
	scene_root.add_child(grid)

	var camera := CameraController.new()
	camera.name = "Camera"
	camera.position = Vector2(0, 360)
	camera.zoom = Vector2(0.82, 0.82)
	scene_root.add_child(camera)

	var controller := AirportGameFeelController.new()
	controller.name = "GameFeel"
	scene_root.add_child(controller)

	await process_frame
	await process_frame

	if controller.airport_grid != grid:
		_fail("GameFeel should auto-connect to AirportGrid.")
		return
	if controller.camera_controller != camera:
		_fail("GameFeel should auto-connect to CameraController.")
		return

	var aircraft := AircraftPrototype.new()
	aircraft.name = "GF-Test"
	aircraft.configure_aircraft_type("pico_p8")
	scene_root.add_child(aircraft)

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a departure route.")
		return

	var route_info: Dictionary = routes[0]
	var route: PackedVector2Array = route_info.get(
		"route",
		PackedVector2Array()
	)
	if route.size() < 5:
		_fail("Game-feel test requires a complete departure route.")
		return

	aircraft.set_departure_route(
		route,
		"S",
		int(route_info.get("stand_uid", -1)),
		int(route_info.get("runway_uid", -1))
	)
	controller._discover_dynamic_nodes()

	if controller.get_connected_aircraft_count() != 1:
		_fail("GameFeel should discover dynamically spawned aircraft.")
		return

	var original_camera_position := camera.position
	var original_zoom := camera.zoom

	aircraft._set_state("TAKEOFF_ROLL")
	if not camera.is_emphasis_active():
		_fail("Takeoff roll should start subtle camera emphasis.")
		return

	var takeoff_request := camera.get_last_emphasis_request()
	if String(takeoff_request.get("kind", "")) != "takeoff":
		_fail("Takeoff camera emphasis should report takeoff kind.")
		return
	var takeoff_target: Vector2 = takeoff_request.get(
		"target",
		Vector2.ZERO
	)
	if takeoff_target.distance_to(aircraft.global_position) > 0.01:
		_fail("Camera emphasis should record the aircraft world target.")
		return
	if float(
		takeoff_request.get("zoom_multiplier", 1.0)
	) <= 1.0:
		_fail("Takeoff emphasis should use a small zoom-in.")
		return

	camera.cancel_emphasis()
	if camera.is_emphasis_active():
		_fail("Camera emphasis should be interruptible.")
		return
	if camera.position != original_camera_position:
		_fail("Cancelling emphasis should restore camera position.")
		return
	if camera.zoom != original_zoom:
		_fail("Cancelling emphasis should restore camera zoom.")
		return

	aircraft._set_state("LANDING_ROLL")
	var landing_request := camera.get_last_emphasis_request()
	if String(landing_request.get("kind", "")) != "landing":
		_fail("Landing roll should request landing camera emphasis.")
		return
	camera.cancel_emphasis()

	var pulse_before_tap := controller.get_active_pulse_count()
	camera.world_tapped.emit(aircraft.global_position)
	if controller.get_active_pulse_count() <= pulse_before_tap:
		_fail("Tapping an aircraft should create a selection pulse.")
		return

	var stand_uid := int(route_info.get("stand_uid", -1))
	var stand := grid.get_building(stand_uid)
	if stand.is_empty():
		_fail("Starter departure route should reference a stand building.")
		return

	var pulse_before_building := controller.get_active_pulse_count()
	grid.building_selected_world.emit(stand)
	if controller.get_active_pulse_count() <= pulse_before_building:
		_fail("Selecting a building should create a gold selection pulse.")
		return

	var pulse_before_place := controller.get_active_pulse_count()
	grid.building_placed.emit(stand)
	if controller.get_active_pulse_count() <= pulse_before_place:
		_fail("Placed building should create a green confirmation pulse.")
		return

	var summary := FlightReturnSummary.new()
	scene_root.add_child(summary)
	await process_frame
	controller._discover_dynamic_nodes()

	var feedback_before := controller.feedback_root.get_child_count()
	summary.show_reward(
		"GF-001",
		{
			"city": "Brussels",
			"coins": 125,
			"xp": 42,
			"resource_chance": 0.4,
			"resource_rolls": [],
			"resources_won": []
		},
		{}
	)
	await process_frame

	if controller.feedback_root.get_child_count() <= feedback_before:
		_fail("Displayed flight reward should create compact reward feedback.")
		return

	var scene_path := "res://src/main/Main.tscn"
	if not ResourceLoader.exists(scene_path):
		_fail("Main scene should remain loadable.")
		return

	var packed = load(scene_path)
	if not (packed is PackedScene):
		_fail("Main scene should load as PackedScene.")
		return

	var instance := (packed as PackedScene).instantiate()
	var game_feel_node := instance.get_node_or_null("GameFeel")
	if not (game_feel_node is AirportGameFeelController):
		_fail("Main scene should mount AirportGameFeelController.")
		return
	instance.queue_free()

	print(
		"Camera/game-feel passed: takeoff/landing emphasis, selection pulses, "
		+ "placement feedback, reward feedback and scene mounting."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
