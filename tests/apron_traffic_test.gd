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

	if absf(
		ApronTrafficRules.station_stagger_delay(1) - 0.30
	) > 0.001:
		_fail("Second vehicle from a multi-capacity depot should stagger by 0.30 seconds.")
		return
	if absf(
		ApronTrafficRules.station_stagger_delay(2) - 0.60
	) > 0.001:
		_fail("Third vehicle from a multi-capacity depot should stagger by 0.60 seconds.")
		return
	if ApronTrafficRules.station_stagger_delay(20) > 1.801:
		_fail("Depot-exit staggering should also be capped.")
		return

	if (
		ApronTrafficRules.right_of_way_priority("pushback")
		<= ApronTrafficRules.right_of_way_priority("passenger")
	):
		_fail("Pushback must have highest apron traffic priority.")
		return
	if (
		ApronTrafficRules.right_of_way_priority("passenger")
		<= ApronTrafficRules.right_of_way_priority("cleaning")
	):
		_fail("Large passenger vehicles should outrank compact cleaning vans.")
		return

	var follower_snapshot := {
		"instance_id": 10,
		"position": Vector2(0, 0),
		"heading": 0.0,
		"phase": "OUTBOUND",
		"service_type": "cargo",
		"traffic_sequence": 2,
	}
	var leader_snapshot := {
		"instance_id": 11,
		"position": Vector2(15, 0),
		"heading": 0.0,
		"phase": "OUTBOUND",
		"service_type": "cargo",
		"traffic_sequence": 1,
	}
	var following_decision := ApronTrafficRules.traffic_decision(
		follower_snapshot,
		[leader_snapshot]
	)
	if not bool(following_decision.get("yielding", false)):
		_fail("Following service vehicle should yield inside the safe road gap.")
		return
	if float(following_decision.get("factor", 1.0)) >= 1.0:
		_fail("Following vehicle should reduce visual route progress.")
		return
	if String(following_decision.get("reason", "")) != "vehicle ahead":
		_fail("Following traffic should report the vehicle-ahead reason.")
		return

	var cargo_oncoming := follower_snapshot.duplicate(true)
	cargo_oncoming["instance_id"] = 20
	cargo_oncoming["position"] = Vector2(0, 0)
	cargo_oncoming["heading"] = 0.0
	cargo_oncoming["service_type"] = "cargo"
	cargo_oncoming["traffic_sequence"] = 4
	var pushback_oncoming := {
		"instance_id": 21,
		"position": Vector2(22, 0),
		"heading": PI,
		"phase": "OUTBOUND",
		"service_type": "pushback",
		"traffic_sequence": 5,
	}
	var oncoming_decision := ApronTrafficRules.traffic_decision(
		cargo_oncoming,
		[pushback_oncoming]
	)
	if float(oncoming_decision.get("factor", 1.0)) > 0.001:
		_fail("Cargo vehicle should fully yield to an oncoming pushback tug.")
		return
	if String(oncoming_decision.get("reason", "")) != "oncoming vehicle":
		_fail("Oncoming conflict should expose a deterministic hold reason.")
		return

	var tie_late := {
		"instance_id": 31,
		"position": Vector2(0, 0),
		"heading": 0.0,
		"phase": "OUTBOUND",
		"service_type": "cargo",
		"traffic_sequence": 8,
	}
	var tie_early := {
		"instance_id": 30,
		"position": Vector2(15, 15),
		"heading": -PI * 0.5,
		"phase": "OUTBOUND",
		"service_type": "cargo",
		"traffic_sequence": 7,
	}
	var tie_decision := ApronTrafficRules.traffic_decision(
		tie_late,
		[tie_early]
	)
	if not bool(tie_decision.get("yielding", false)):
		_fail("Later equal-priority dispatch should yield at a crossing.")
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

	var fuel_traffic := fuel_truck.get_apron_traffic_snapshot()
	var cleaning_traffic := cleaning_van.get_apron_traffic_snapshot()
	var catering_traffic := catering_truck.get_apron_traffic_snapshot()
	if (
		int(fuel_traffic.get("stand_uid", -1)) != stand_uid
		or int(cleaning_traffic.get("stand_uid", -1)) != stand_uid
		or int(catering_traffic.get("stand_uid", -1)) != stand_uid
	):
		_fail("All dispatched service vehicles should carry their stand traffic identity.")
		return
	var sequences := [
		int(fuel_traffic.get("traffic_sequence", -1)),
		int(cleaning_traffic.get("traffic_sequence", -1)),
		int(catering_traffic.get("traffic_sequence", -1)),
	]
	if sequences[0] <= 0 or sequences[1] <= sequences[0] or sequences[2] <= sequences[1]:
		_fail("Service vehicle traffic sequence should be deterministic and increasing.")
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

	if cleaning_van.outbound_route.size() < 3 or catering_truck.outbound_route.size() < 3:
		_fail("Staggered service vehicles should retain full apron routes.")
		return
	if cleaning_van.outbound_route[1].distance_to(
		catering_truck.outbound_route[1]
	) < 2.0:
		_fail("Cleaning and catering vehicles should occupy different apron lanes.")
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
		"Apron traffic passed: lanes, staging, staggered launches, "
		+ "live yielding, priority, and deterministic traffic identity."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
