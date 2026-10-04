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

	var normal_time := _find_condition_time("brussels", "normal")
	if normal_time < 0:
		_fail("Test should find a Normal Brussels demand slot.")
		return
	screen.set_demand_time_override(normal_time)

	var planes: Array[AircraftPrototype] = [plane]
	screen.open_map(
		planes,
		4,
		{"pico_p8": 10.0},
		3,
		40,
		{
			"brussels": {
				"flights_completed": 2,
				"passengers_boarded": 11,
				"coins_earned": 840,
				"xp_earned": 64,
				"resources_earned": 3
			}
		}
	)

	if not screen.root.visible:
		_fail("World Map should open for demand preview.")
		return

	if not screen.route_card_label.text.contains("Feeder • 65% load"):
		_fail("Route card should show Brussels Feeder demand at 65%.")
		return

	if not screen.route_card_label.text.contains("6 → 5 pax"):
		_fail(
			"Route card should show route demand → Mastery demand."
		)
		return

	if not screen.reward_card_label.text.contains("Stock 3/40"):
		_fail("Reward card should show live passenger stock.")
		return
	if not screen.details_body.text.contains("Condition: Normal"):
		_fail("Fixed Normal test slot should render on World Map.")
		return
	if not screen.details_body.text.contains("2 flights • 5.5 avg pax"):
		_fail("World Map should render per-route performance history.")
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


func _find_condition_time(
	destination_id: String,
	condition_id: String
) -> int:
	for slot in range(DynamicDemandRules.CONDITION_ORDER.size()):
		var timestamp := slot * DynamicDemandRules.SLOT_SECONDS
		var condition := DynamicDemandRules.condition_for(
			destination_id,
			timestamp
		)
		if String(condition.get("id", "")) == condition_id:
			return timestamp
	return -1
