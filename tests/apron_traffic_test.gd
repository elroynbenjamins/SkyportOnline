extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(50, 0),
		Vector2(100, 50),
		Vector2(140, 70)
	])
	var fuel_route := ApronTrafficRules.offset_route(
		base_route,
		"fuel"
	)
	var cargo_route := ApronTrafficRules.offset_route(
		base_route,
		"cargo"
	)

	if fuel_route[0] != base_route[0]:
		_fail("Apron lane offsets must preserve station endpoint.")
		return
	if fuel_route[
		fuel_route.size() - 1
	] != base_route[base_route.size() - 1]:
		_fail("Apron lane offsets must preserve aircraft docking endpoint.")
		return
	if fuel_route[1].distance_to(cargo_route[1]) < 2.0:
		_fail("Different ground services should use visibly separate lanes.")
		return

	if absf(ApronTrafficRules.stagger_delay(0) - 0.0) > 0.001:
		_fail("First stand approach should launch immediately.")
		return
	if absf(ApronTrafficRules.stagger_delay(1) - 0.45) > 0.001:
		_fail("Second stand approach should stagger by 0.45 seconds.")
		return
	if absf(ApronTrafficRules.stagger_delay(2) - 0.90) > 0.001:
		_fail("Third stand approach should stagger by 0.90 seconds.")
		return
	if ApronTrafficRules.stagger_delay(20) > 1.801:
		_fail("Stand approach staggering should be capped.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a departure route.")
		return

	var route_info: Dictionary = routes[0]
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	plane.set_departure_route(
		route_info["route"],
		"S",
		int(route_info["stand_uid"]),
		int(route_info["runway_uid"])
	)
	plane.assign_flight_plan({
		"destination_id": "apron-test",
		"city": "Apron Test",
		"country_code": "BE",
		"duration_seconds": 1.0
	})

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	dispatcher.request_turnaround(
		plane,
		"Apron Test",
		false
	)

	var stand_uid := plane.stand_uid
	if dispatcher.get_stand_approach_count(stand_uid) != 3:
		_fail(
			"Fuel, cleaning, and catering should reserve three staggered stand approaches."
		)
		return

	var fuel_truck: FuelTruckPrototype = null
	var cleaning_van: GroundServiceVehiclePrototype = null
	var catering_truck: GroundServiceVehiclePrototype = null

	for child in dispatcher.get_children():
		if child is FuelTruckPrototype:
			fuel_truck = child as FuelTruckPrototype
		elif child is GroundServiceVehiclePrototype:
			var vehicle := child as GroundServiceVehiclePrototype
			if vehicle.service_type == "cleaning":
				cleaning_van = vehicle
			elif vehicle.service_type == "catering":
				catering_truck = vehicle

	if fuel_truck == null or cleaning_van == null or catering_truck == null:
		_fail("Starter service stage should dispatch fuel, cleaning, and catering vehicles.")
		return

	if fuel_truck.phase != "OUTBOUND":
		_fail("First stand service should begin driving immediately.")
		return
	if cleaning_van.phase != "WAITING_LAUNCH":
		_fail("Second stand service should wait for staggered launch.")
		return
	if catering_truck.phase != "WAITING_LAUNCH":
		_fail("Third stand service should wait for staggered launch.")
		return
	if absf(cleaning_van.launch_delay_remaining - 0.45) > 0.01:
		_fail("Cleaning van should use the second 0.45 second launch slot.")
		return
	if absf(catering_truck.launch_delay_remaining - 0.90) > 0.01:
		_fail("Catering truck should use the third 0.90 second launch slot.")
		return

	cleaning_van._process(0.46)
	if cleaning_van.phase != "OUTBOUND":
		_fail("Cleaning van should launch after its stagger expires.")
		return
	catering_truck._process(0.46)
	if catering_truck.phase != "WAITING_LAUNCH":
		_fail("Catering truck should remain staged until its later slot.")
		return
	catering_truck._process(0.46)
	if catering_truck.phase != "OUTBOUND":
		_fail("Catering truck should launch after the full stagger.")
		return

	var base_service_route := grid.get_service_route(
		int(
			grid.get_best_service_building(
				"cleaning",
				"S"
			).get("uid", -1)
		),
		stand_uid
	)
	var cleaning_route := dispatcher._route_to_aircraft_service_anchor(
		base_service_route,
		plane,
		"cleaning",
		"cleaning"
	)
	var dock := plane.get_service_docking_position(
		"cleaning",
		"cleaning"
	)
	if cleaning_route.size() < base_service_route.size() + 1:
		_fail("Aircraft service route should include an outer approach staging point.")
		return
	if cleaning_route[
		cleaning_route.size() - 1
	].distance_to(dock) > 0.01:
		_fail("Final service-route point should remain the exact docking anchor.")
		return
	if cleaning_route[
		cleaning_route.size() - 2
	].distance_to(dock) < 12.0:
		_fail("Approach staging point should sit outside the final docking position.")
		return

	print(
		"Apron traffic passed: lane separation, approach staging, "
		+ "and staggered service launches."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
