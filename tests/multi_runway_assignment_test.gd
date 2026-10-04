extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	grid.select_parcel("east")
	grid.purchase_selected()
	grid.select_parcel("south_east")
	grid.purchase_selected()

	var runway_preview := grid.set_build_preview(
		"regional_runway",
		grid.tile_to_world(Vector2(20, 8)),
		1
	)
	if not bool(runway_preview.get("valid", false)):
		_fail("Regional Runway should fit across east and south-east parcels.")
		return
	var regional := grid.confirm_build_preview()
	if regional.is_empty():
		_fail("Regional Runway placement should succeed.")
		return

	for x in range(14, 20):
		var taxi_preview := grid.set_build_preview(
			"taxiway",
			grid.tile_to_world(Vector2(x, 10)),
			0
		)
		if not bool(taxi_preview.get("valid", false)):
			_fail("Second runway taxiway should be placeable at x=%d." % x)
			return
		if grid.confirm_build_preview().is_empty():
			_fail("Second runway taxiway placement should succeed.")
			return

	var runways := grid.get_runway_buildings()
	if runways.size() != 2:
		_fail("Expanded airport should expose two operational runways.")
		return

	var default_routes := grid.get_departure_routes("S")
	if default_routes.size() != 2:
		_fail("Backward-compatible departure API should still return one route per stand.")
		return

	var stand_a := int(default_routes[0].get("stand_uid", -1))
	var stand_b := int(default_routes[1].get("stand_uid", -1))
	var options_a := grid.get_departure_route_options_for_stand(
		stand_a,
		"S"
	)
	var options_b := grid.get_departure_route_options_for_stand(
		stand_b,
		"S"
	)
	if options_a.size() != 2 or options_b.size() != 2:
		_fail("Each starter stand should expose routes to both connected S-compatible runways.")
		return

	var option_runways: Dictionary = {}
	var has_regional := false
	for option in options_a:
		option_runways[int(option.get("runway_uid", -1))] = true
		if String(option.get("runway_definition_id", "")) == "regional_runway":
			has_regional = true
		if float(option.get("taxi_distance", 0.0)) <= 0.0:
			_fail("Runway options should expose positive taxi distance.")
			return
	if option_runways.size() != 2:
		_fail("Runway route options should identify two distinct runway UIDs.")
		return
	if not has_regional:
		_fail("Route options should include the Regional Runway.")
		return

	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var planned := AircraftPrototype.new()
	root.add_child(planned)
	planned.configure_aircraft_type("pico_p8")

	var choice_a := dispatcher.select_best_runway_option(
		options_a,
		"departure"
	)
	if choice_a.is_empty():
		_fail("Dispatcher should select an initial departure runway.")
		return
	var runway_a := int(choice_a.get("runway_uid", -1))
	dispatcher.reserve_departure_assignment(
		planned,
		runway_a
	)

	var choice_b := dispatcher.select_best_runway_option(
		options_b,
		"departure"
	)
	if choice_b.is_empty():
		_fail("Dispatcher should select a second departure runway.")
		return
	var runway_b := int(choice_b.get("runway_uid", -1))
	if runway_b == runway_a:
		_fail("Planned departure load should spread simultaneous pushbacks across runways.")
		return

	dispatcher.release_departure_assignment(planned)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)

	var choices: Array[Dictionary] = [choice_a, choice_b]
	var planes: Array[AircraftPrototype] = [plane_a, plane_b]
	for index in range(2):
		var plane := planes[index]
		var choice: Dictionary = choices[index]
		plane.configure_aircraft_type("pico_p8")
		plane.set_departure_route(
			choice["route"],
			"S",
			int(choice.get("stand_uid", -1)),
			int(choice.get("runway_uid", -1))
		)
		plane.assign_flight_plan({
			"destination_id": "multi-runway-%d" % index,
			"city": "Multi Runway",
			"duration_seconds": 1.0
		})
		plane.mark_service_complete()
		dispatcher.request_departure(
			plane,
			"DEP-%d" % (index + 1)
		)
		plane.hold_short_reached.emit()

	if dispatcher.get_active_count() != 2:
		_fail("Two different runways should support two simultaneous runway movements.")
		return
	if String(
		dispatcher.get_runway_visual_state(runway_a).get(
			"active_operation",
			""
		)
	) != "departure":
		_fail("First runway should show active departure.")
		return
	if String(
		dispatcher.get_runway_visual_state(runway_b).get(
			"active_operation",
			""
		)
	) != "departure":
		_fail("Second runway should show active departure.")
		return

	var snapshot := dispatcher.get_atc_snapshot()
	var atc_runways: Array = snapshot.get("runways", [])
	if atc_runways.size() != 2:
		_fail("ATC snapshot should track both built runways.")
		return

	plane_a.runway_cleared.emit()
	plane_b.runway_cleared.emit()

	var arrival_options := grid.get_arrival_route_options("S")
	if arrival_options.size() != 4:
		_fail("Two stands × two runways should expose four S arrival options.")
		return

	var occupied_option: Dictionary = {}
	for option in arrival_options:
		if int(option.get("runway_uid", -1)) == runway_a:
			occupied_option = option
			break
	if occupied_option.is_empty():
		_fail("Arrival options should include the first runway.")
		return

	var arrival_a := AircraftPrototype.new()
	root.add_child(arrival_a)
	arrival_a.configure_aircraft_type("pico_p8")
	arrival_a.set_arrival_route(
		occupied_option["route"],
		int(occupied_option.get("stand_uid", -1)),
		runway_a
	)
	dispatcher.request_arrival(arrival_a, "ARR-A")
	if dispatcher.get_active_count() != 1:
		_fail("First inbound aircraft should occupy its selected runway.")
		return

	var arrival_choice := dispatcher.select_best_runway_option(
		arrival_options,
		"arrival"
	)
	if int(arrival_choice.get("runway_uid", -1)) == runway_a:
		_fail("Second inbound assignment should avoid the already occupied runway.")
		return
	if int(arrival_choice.get("runway_uid", -1)) != runway_b:
		_fail("Second inbound assignment should select the alternate runway.")
		return

	var regional_definition := BuildingCatalog.get_definition(
		"regional_runway"
	)
	var regional_sizes: PackedStringArray = regional_definition.get(
		"sizes",
		PackedStringArray()
	)
	if not regional_sizes.has("M"):
		_fail("Regional Runway should remain the runway path for M aircraft.")
		return

	print(
		"Multi-runway assignment passed: route alternatives, planned-departure "
		+ "balancing, parallel runway use, ATC tracking, and inbound diversion."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
