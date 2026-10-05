extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.position = Vector2(500, 320)
	plane.rotation = 0.0
	plane.z_index = 80

	var services := [
		"passenger",
		"cargo",
		"cleaning",
		"catering",
		"fuel",
		"pushback"
	]
	for service_type_variant in services:
		var service_type := String(service_type_variant)
		var docking := plane.get_service_docking_local_offset(
			service_type,
			service_type
		)
		var connection := plane.get_service_connection_local_offset(
			service_type,
			service_type
		)
		if docking.length() <= 20.0:
			_fail("%s docking point should remain outside the aircraft body." % service_type)
			return
		if connection.length() <= 4.0:
			_fail("%s should use a visible aircraft attachment point." % service_type)
			return
		if connection.length() >= docking.length():
			_fail("%s attachment point should sit between the aircraft center and parked vehicle." % service_type)
			return

		var approach_distance := GroundServiceVehicleArt.approach_distance(
			service_type
		)
		var attachment_reach := GroundServiceVehicleArt.attachment_reach(
			service_type
		)
		var align_rate := GroundServiceVehicleArt.service_align_rate(
			service_type
		)
		if approach_distance < 20.0 or approach_distance > 36.0:
			_fail("%s should have a compact final service approach." % service_type)
			return
		if attachment_reach < 34.0 or attachment_reach > 50.0:
			_fail("%s attachment reach should stay within the approved visual range." % service_type)
			return
		if align_rate < 7.0 or align_rate > 15.0:
			_fail("%s service-pose alignment should remain smooth but quick." % service_type)
			return

	var passenger_connection := plane.get_service_connection_position(
		"passenger",
		"passenger_in"
	)
	var cargo_connection := plane.get_service_connection_position(
		"cargo",
		"cargo_in"
	)
	var fuel_connection := plane.get_service_connection_position(
		"fuel",
		"fuel"
	)
	var pushback_connection := plane.get_service_connection_position(
		"pushback",
		"pushback"
	)
	if passenger_connection.distance_to(plane.global_position) < 5.0:
		_fail("Passenger stairs should attach to the cabin door, not aircraft center.")
		return
	if cargo_connection.distance_to(plane.global_position) < 5.0:
		_fail("Baggage belt should attach to the hold, not aircraft center.")
		return
	if fuel_connection.distance_to(plane.global_position) < 5.0:
		_fail("Fuel hose should attach near the wing root, not aircraft center.")
		return
	if pushback_connection.distance_to(plane.global_position) < 15.0:
		_fail("Towbar should attach at the nose gear.")
		return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	var base_route := PackedVector2Array([
		Vector2(350, 400),
		Vector2(410, 380),
		Vector2(460, 350)
	])
	for service_type_variant in services:
		var service_type := String(service_type_variant)
		var lane_route := ApronTrafficRules.offset_route(
			base_route,
			service_type
		)
		var route := dispatcher._route_to_aircraft_service_anchor(
			lane_route,
			plane,
			service_type,
			service_type
		)
		if route.size() != base_route.size() + 1:
			_fail("%s service route should add a dedicated final docking leg." % service_type)
			return
		var docking := plane.get_service_docking_position(
			service_type,
			service_type
		)
		var staging := route[route.size() - 2]
		var final := route[route.size() - 1]
		if final.distance_to(docking) > 0.01:
			_fail("%s route should finish at the exact docking point." % service_type)
			return
		var final_heading := (final - staging).angle()
		var target_heading := plane.get_service_docking_rotation(
			service_type,
			service_type
		)
		var heading_error := absf(
			wrapf(
				final_heading - target_heading,
				-PI,
				PI
			)
		)
		if heading_error > 0.03:
			_fail("%s should make a straight final approach aligned to its service pose." % service_type)
			return

	var passenger_dock := plane.get_service_docking_position(
		"passenger",
		"passenger_in"
	)
	var cargo_dock := plane.get_service_docking_position(
		"cargo",
		"cargo_in"
	)
	if dispatcher._service_vehicle_z_index(
		plane,
		passenger_dock
	) >= plane.z_index:
		_fail("Far-side passenger vehicle should render behind the aircraft.")
		return
	if dispatcher._service_vehicle_z_index(
		plane,
		cargo_dock
	) <= plane.z_index:
		_fail("Near-side baggage vehicle should render in front of the aircraft.")
		return

	var cargo_vehicle := GroundServiceVehiclePrototype.new()
	root.add_child(cargo_vehicle)
	await process_frame
	cargo_vehicle.drive_speed = 100.0
	cargo_vehicle.set_service_pose_rotation(PI * 0.5)
	cargo_vehicle.set_service_connection_target(
		cargo_connection
	)
	cargo_vehicle.start_service(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(10, 0)
		]),
		4.0,
		"cargo"
	)
	cargo_vehicle._process(0.20)
	if cargo_vehicle.phase != "SERVICING":
		_fail("Cargo vehicle should reach its service point.")
		return
	if cargo_vehicle.service_pose_error <= 0.1:
		_fail("Cargo service pose should ease into alignment instead of snapping.")
		return
	var cargo_error_before := cargo_vehicle.service_pose_error
	var cargo_time_before := cargo_vehicle.service_remaining
	cargo_vehicle._process(0.05)
	if cargo_vehicle.service_pose_error >= cargo_error_before:
		_fail("Cargo service pose should continuously align toward its parked heading.")
		return
	if absf(
		(cargo_time_before - cargo_vehicle.service_remaining) - 0.05
	) > 0.002:
		_fail("Visual service alignment must not extend or pause turnaround timing.")
		return

	var fuel_vehicle := FuelTruckPrototype.new()
	root.add_child(fuel_vehicle)
	await process_frame
	fuel_vehicle.drive_speed = 100.0
	fuel_vehicle.set_service_pose_rotation(-PI * 0.5)
	fuel_vehicle.set_service_connection_target(
		fuel_connection
	)
	fuel_vehicle.start_service(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(10, 0)
		]),
		4.0
	)
	fuel_vehicle._process(0.20)
	if fuel_vehicle.phase != "SERVICING":
		_fail("Fuel truck should reach its service point.")
		return
	if fuel_vehicle.service_pose_error <= 0.1:
		_fail("Fuel truck should ease into its parked heading instead of snapping.")
		return
	var fuel_error_before := fuel_vehicle.service_pose_error
	fuel_vehicle._process(0.05)
	if fuel_vehicle.service_pose_error >= fuel_error_before:
		_fail("Fuel truck should visually settle toward its service pose.")
		return

	var tug_plane := AircraftPrototype.new()
	root.add_child(tug_plane)
	await process_frame
	tug_plane.configure_aircraft_type("pico_p8")
	tug_plane.position = Vector2(600, 360)
	tug_plane.rotation = 0.0
	tug_plane.departure_route = PackedVector2Array([
		tug_plane.position,
		tug_plane.position + Vector2(-70, 0)
	])

	var tug := GroundServiceVehiclePrototype.new()
	root.add_child(tug)
	await process_frame
	tug.drive_speed = 100.0
	tug.set_service_pose_rotation(PI)
	tug.set_service_connection_target(
		tug_plane.get_service_connection_position(
			"pushback",
			"pushback"
		)
	)
	tug.configure_tow(
		tug_plane,
		tug_plane.get_pushback_target_position()
	)
	tug.start_service(
		PackedVector2Array([
			Vector2(655, 360),
			tug_plane.get_service_docking_position(
				"pushback",
				"pushback"
			)
		]),
		4.0,
		"pushback"
	)
	for _step in range(20):
		tug._process(0.10)
		if tug.phase == "SERVICING":
			break
	if tug.phase != "SERVICING":
		_fail("Pushback tug should reach the nose-gear docking point.")
		return
	if tug.service_pose_error > 0.001:
		_fail("Pushback tug should lock immediately to the safe tow heading.")
		return
	var expected_nose := tug_plane.get_service_connection_position(
		"pushback",
		"pushback"
	)
	if tug.service_connection_target.distance_to(expected_nose) > 0.01:
		_fail("Towbar should begin attached to the nose gear.")
		return
	tug._process(0.50)
	expected_nose = tug_plane.get_service_connection_position(
		"pushback",
		"pushback"
	)
	if tug.service_connection_target.distance_to(expected_nose) > 0.01:
		_fail("Towbar should track the moving nose gear during pushback.")
		return

	print(
		"TURNAROUND_VISUAL_INTEGRATION_OK "
		+ "attachments=6 straight_approach=true depth_sort=true "
		+ "pose_easing=true timing_unchanged=true towbar_tracks_nose=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
