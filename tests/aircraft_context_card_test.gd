extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.name = "SO-001"
	plane.configure_aircraft_type("pico_p8")
	plane.position = Vector2(220, 180)
	await process_frame

	var brussels := DestinationCatalog.get_destination("brussels")
	var plan := FlightRules.create_flight_plan(
		plane.get_aircraft_profile(),
		brussels
	)
	if plan.is_empty():
		_fail("Aircraft context test should create Brussels plan.")
		return
	plane.assign_flight_plan(plan)

	if not plane.contains_world_point(Vector2(230, 185)):
		_fail("Tap near aircraft should hit its interaction radius.")
		return
	if plane.contains_world_point(Vector2(320, 280)):
		_fail("Far world tap should not select aircraft.")
		return

	var card := AircraftContextCard.new()
	root.add_child(card)
	await process_frame

	card.show_aircraft(
		plane,
		{"pico_p8": 10.0},
		3,
		40
	)

	if not card.is_open():
		_fail("Aircraft context card should open for selected plane.")
		return
	if card.aircraft_image.texture == null:
		_fail("Aircraft context card should load pixel aircraft sprite.")
		return
	if not card.title_label.text.contains("Pico P8"):
		_fail("Context card should show aircraft model.")
		return
	if not card.route_label.text.contains("Brussels"):
		_fail("Context card should show assigned route.")
		return
	if not card.passenger_label.text.contains("5 needed"):
		_fail("Context card should show Mastery-adjusted passenger need.")
		return
	if not card.passenger_label.text.contains("3/40"):
		_fail("Context card should show live airport passenger stock.")
		return
	if not card.mastery_label.text.contains("★☆☆☆☆"):
		_fail("Context card should show aircraft Mastery stars.")
		return
	if not card.primary_button.text.contains("CHOOSE ROUTE"):
		_fail("Ground aircraft should offer Choose Route action.")
		return

	plane.state = "EN_ROUTE"
	plane.flight_remaining = 300.0
	card.refresh_card()

	if not card.primary_button.text.contains("VIEW IN FLEET"):
		_fail("Busy airborne aircraft should offer Fleet inspection.")
		return
	if not card.route_label.text.contains("remaining"):
		_fail("En-route context card should show remaining flight time.")
		return

	card.set_passenger_stock(12, 55)
	if not card.passenger_label.text.contains("12/55"):
		_fail("Context card passenger stock should refresh live.")
		return

	card.close_card()
	if card.is_open():
		_fail("Aircraft context card should close cleanly.")
		return

	print(
		"Aircraft context passed: world hit-test, sprite, route, passengers, "
		+ "Mastery, live refresh and contextual actions."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
