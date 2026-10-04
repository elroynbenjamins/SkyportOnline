extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pico_a := AircraftPrototype.new()
	var pico_b := AircraftPrototype.new()
	root.add_child(pico_a)
	root.add_child(pico_b)

	pico_a.name = "SO-001"
	pico_b.name = "SO-002"
	pico_a.configure_aircraft_type("pico_p8")
	pico_b.configure_aircraft_type("pico_p8")

	var brussels := DestinationCatalog.get_destination("brussels")
	var plan := FlightRules.create_flight_plan(
		pico_a.get_aircraft_profile(),
		brussels
	)
	if plan.is_empty():
		_fail("Fleet test should create a Pico P8 Brussels plan.")
		return

	pico_a.assign_flight_plan(plan)
	pico_b.assign_flight_plan(plan)

	var screen := FleetScreen.new()
	root.add_child(screen)
	await process_frame

	var aircraft_nodes: Array[AircraftPrototype] = [pico_a, pico_b]
	screen.open_fleet(
		aircraft_nodes,
		4,
		{"pico_p8": 50.0}
	)

	if not screen.root.visible:
		_fail("Fleet screen should be visible after opening.")
		return

	if screen.aircraft_buttons.size() != 2:
		_fail("Fleet screen should show both owned aircraft.")
		return

	if not screen.fleet_summary_label.text.contains("2 owned"):
		_fail("Fleet summary should show two owned aircraft.")
		return

	if not screen.mastery_label.text.contains("★★☆☆☆"):
		_fail("50 hours should display two Pico P8 Mastery stars.")
		return

	if not screen.details_body.text.contains("Seats: 8  →  7"):
		_fail(
			"Fleet details should show Mastery-adjusted Pico passenger demand."
		)
		return

	if not screen.details_body.text.contains("+5%"):
		_fail("Fleet details should show active Mastery reward bonuses.")
		return

	if screen.catalog_list.get_child_count() != AircraftCatalog.all().size():
		_fail("Fleet catalog should list the full approved V1 roster.")
		return

	var found_horizon_lock := false
	for card in screen.catalog_list.get_children():
		var label := card.get_child(0) as Label
		if label == null:
			continue
		if (
			label.text.contains("Horizon H88")
			and label.text.contains("LV 17")
		):
			found_horizon_lock = true
			break

	if not found_horizon_lock:
		_fail("Lv4 Fleet screen should show Horizon H88 as Lv17 locked.")
		return

	screen.set_mastery_hours({"pico_p8": 400.0})
	if not screen.mastery_label.text.contains("★★★★☆"):
		_fail("Live Mastery refresh should update Fleet stars immediately.")
		return

	if not screen.details_body.text.contains("Seats: 8  →  6"):
		_fail("Star 4 Fleet details should show Pico demand reduced to 6.")
		return

	print(
		"Fleet screen passed: owned aircraft, V1 catalog, locks, "
		+ "live Mastery, and adjusted passenger demand."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
