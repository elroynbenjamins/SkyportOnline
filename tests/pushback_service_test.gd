extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		_fail("Starter airport should expose two S-class stands.")
		return

	var pushback_station := grid.get_best_service_building(
		"pushback",
		"S"
	)
	if pushback_station.is_empty():
		_fail("Starter Ground Operations Depot should provide a tug.")
		return
	if String(
		pushback_station.get("definition_id", "")
	) != "ground_ops_depot":
		_fail("Starter tug should come from Ground Operations Depot.")
		return
	if int(
		pushback_station.get("vehicle_capacity", 0)
	) != 1:
		_fail("Starter airport should begin with one pushback tug.")
		return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)
	plane_a.configure_aircraft_type("pico_p8")
	plane_b.configure_aircraft_type("pico_p8")

	var planes: Array[AircraftPrototype] = [plane_a, plane_b]
	for index in range(2):
		var plane := planes[index]
		var route_info: Dictionary = routes[index]
		plane.set_departure_route(
			route_info["route"],
			"S",
			int(route_info["stand_uid"]),
			int(route_info["runway_uid"])
		)
		plane.assign_flight_plan({
			"destination_id": "pushback-test",
			"city": "Pushback Test",
			"country_code": "BE",
			"duration_seconds": 1.0
		})
		dispatcher.request_turnaround(
			plane,
			"Tow %d" % (index + 1),
			false
		)

	dispatcher._begin_pushback(
		plane_a.get_instance_id()
	)
	dispatcher._begin_pushback(
		plane_b.get_instance_id()
	)

	var snapshot_a := dispatcher.get_turnaround_snapshot(
		plane_a
	)
	var snapshot_b := dispatcher.get_turnaround_snapshot(
		plane_b
	)
	var status_a: Dictionary = snapshot_a.get(
		"service_status",
		{}
	)
	var status_b: Dictionary = snapshot_b.get(
		"service_status",
		{}
	)

	if String(
		(status_a.get("pushback", {}) as Dictionary).get(
			"state",
			""
		)
	) != "en_route":
		_fail("First aircraft should receive the starter tug.")
		return
	if String(
		(status_b.get("pushback", {}) as Dictionary).get(
			"state",
			""
		)
	) != "queued":
		_fail("Second aircraft should wait for the occupied tug.")
		return

	var waiting := dispatcher.get_waiting_by_service()
	if int(waiting.get("pushback", 0)) != 1:
		_fail("Exactly one aircraft should be queued for pushback.")
		return

	if not plane_b.turnaround_label.text.contains("Tow WAIT"):
		_fail("Queued pushback should be visible on the aircraft card.")
		return

	var tug: GroundServiceVehiclePrototype = null
	for child in dispatcher.get_children():
		if child is GroundServiceVehiclePrototype:
			var candidate := child as GroundServiceVehiclePrototype
			if candidate.service_type == "pushback":
				tug = candidate
				break

	if tug == null:
		_fail("Pushback dispatch should create a tow tug vehicle.")
		return
	if tug.tow_aircraft != plane_a:
		_fail("Tow tug should be attached to the first aircraft.")
		return

	var start_position := plane_a.global_position
	var target_position := plane_a.get_pushback_target_position()
	if start_position.distance_to(target_position) < 20.0:
		_fail("Pushback target should move the aircraft toward taxiway.")
		return

	for _step in range(160):
		tug._process(0.1)
		if tug.phase == "SERVICING":
			break

	if tug.phase != "SERVICING":
		_fail("Tow tug should reach the aircraft nose.")
		return

	var pushback_duration := float(
		AircraftCatalog.get_profile("pico_p8").get(
			"pushback_seconds",
			0.0
		)
	)
	tug._process(pushback_duration * 0.5)

	if plane_a.global_position.distance_to(
		start_position
	) < 2.0:
		_fail("Aircraft should physically move while tug is pushing back.")
		return
	if plane_a.global_position.distance_to(
		target_position
	) < 1.0:
		_fail("Half-duration pushback should not already be complete.")
		return

	tug._process(pushback_duration + 0.5)

	if plane_a.global_position.distance_to(
		target_position
	) > 0.1:
		_fail("Completed pushback should reach the planned taxiway offset.")
		return
	if plane_a.state != "READY_FOR_DEPARTURE":
		_fail("Completed tow service should make aircraft departure-ready.")
		return

	for _step in range(200):
		if not is_instance_valid(tug):
			break
		if tug.phase == "RETURNING":
			tug._process(0.1)
		elif tug.phase == "DONE":
			break
		else:
			tug._process(0.1)

	snapshot_b = dispatcher.get_turnaround_snapshot(plane_b)
	status_b = snapshot_b.get("service_status", {})
	if String(
		(status_b.get("pushback", {}) as Dictionary).get(
			"state",
			""
		)
	) != "en_route":
		_fail("Second aircraft should receive tug after first tug returns.")
		return

	waiting = dispatcher.get_waiting_by_service()
	if int(waiting.get("pushback", 0)) != 0:
		_fail("Pushback queue should clear after tug returns.")
		return

	var tow_ops := BuildingCatalog.get_definition(
		"tow_operations"
	)
	if tow_ops.is_empty():
		_fail("Tow Operations building should exist.")
		return
	if float(tow_ops.get("service_speed", 0.0)) <= 1.0:
		_fail("Tow Operations should provide faster pushback.")
		return
	if int(tow_ops.get("vehicle_capacity", 0)) != 2:
		_fail("Tow Operations should provide two tugs.")
		return

	print(
		"Pushback service passed: tug queue, physical tow movement, "
		+ "release, and specialized Tow Operations capacity."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
