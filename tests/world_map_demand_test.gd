extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.name = "SO-001"
	plane.configure_aircraft_type("pico_p8")

	var screen := WorldMapScreen.new()
	root.add_child(screen)
	await process_frame

	var planes: Array[AircraftPrototype] = [plane]
	screen.open_map(
		planes,
		4,
		{"pico_p8": 10.0},
		3,
		40
	)

	if not screen.root.visible:
		_fail("World Map should open for demand preview.")
		return

	if not screen.details_body.text.contains(
		"Passenger demand: Feeder • 65% load"
	):
		_fail("World Map should show Brussels Feeder demand at 65%.")
		return

	if not screen.details_body.text.contains(
		"Seats 8 → route 6 → Mastery 5"
	):
		_fail(
			"World Map should show seat → route → Mastery demand."
		)
		return

	if not screen.details_body.text.contains("Airport stock: 3 / 40"):
		_fail("World Map should show live passenger stock.")
		return

	if not screen.assign_button.text.contains("WAIT FOR 5 PAX"):
		_fail(
			"Low passenger stock should be clear before route assignment."
		)
		return

	screen.set_passenger_stock(12, 40)
	if not screen.assign_button.text.contains("5 PAX"):
		_fail("Sufficient stock should still show required passenger count.")
		return
	if screen.assign_button.text.contains("WAIT FOR"):
		_fail("Sufficient passenger stock should remove wait warning.")
		return

	print(
		"World Map demand passed: load tier, Mastery demand, "
		+ "live stock, and pre-dispatch wait warning."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
