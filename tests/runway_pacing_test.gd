extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if absf(
		RunwayPacingRules.separation_seconds(
			"departure",
			"departure"
		) - 2.5
	) > 0.001:
		_fail("DEP→DEP separation should be 2.5 seconds.")
		return
	if absf(
		RunwayPacingRules.separation_seconds(
			"departure",
			"arrival"
		) - 3.5
	) > 0.001:
		_fail("DEP→ARR separation should be 3.5 seconds.")
		return
	if absf(
		RunwayPacingRules.separation_seconds(
			"arrival",
			"departure"
		) - 3.0
	) > 0.001:
		_fail("ARR→DEP separation should be 3.0 seconds.")
		return
	if absf(
		RunwayPacingRules.separation_seconds(
			"arrival",
			"arrival"
		) - 4.5
	) > 0.001:
		_fail("ARR→ARR separation should be 4.5 seconds.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		_fail("Starter airport should expose two departure routes.")
		return

	var runway_uid := int(
		routes[0].get("runway_uid", -1)
	)
	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)

	var first := AircraftPrototype.new()
	var second := AircraftPrototype.new()
	root.add_child(first)
	root.add_child(second)

	for index in range(2):
		var plane: AircraftPrototype = first if index == 0 else second
		plane.configure_aircraft_type("pico_p8")
		plane.set_departure_route(
			routes[index]["route"],
			"S",
			int(routes[index].get("stand_uid", -1)),
			runway_uid
		)
		plane.assign_flight_plan({
			"destination_id": "pacing-%d" % index,
			"city": "Pacing",
			"duration_seconds": 1.0
		})
		plane.mark_service_complete()

	dispatcher.request_departure(first, "DEP-A")
	dispatcher.request_departure(second, "DEP-B")
	first.hold_short_reached.emit()
	second.hold_short_reached.emit()

	if dispatcher.get_active_count() != 1:
		_fail("First departure should receive initial runway clearance.")
		return
	if dispatcher.get_waiting_departure_count() != 1:
		_fail("Second departure should wait behind active departure.")
		return

	first.runway_cleared.emit()

	var initial_spacing := dispatcher.get_separation_remaining(
		runway_uid
	)
	if absf(
		initial_spacing
		- RunwayPacingRules.DEPARTURE_TO_DEPARTURE
	) > 0.01:
		_fail("DEP→DEP separation countdown should start at 2.5 seconds.")
		return
	if dispatcher.get_active_count() != 0:
		_fail("Runway should be idle while separation timer runs.")
		return

	var snapshot := dispatcher.get_atc_snapshot()
	var primary_value = snapshot.get("primary_runway", {})
	if not (primary_value is Dictionary):
		_fail("ATC snapshot should expose primary runway data.")
		return
	var primary: Dictionary = primary_value
	if not String(
		primary.get("sequence_text", "")
	).contains("SEP 3s"):
		_fail("ATC queue should display rounded separation countdown.")
		return
	if not String(
		primary.get("sequence_text", "")
	).contains("DEP DEP-B"):
		_fail("ATC queue should show the next departure.")
		return

	var hud_script = load("res://src/ui/HUD.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	hud.set_atc_state(snapshot)
	if not hud.atc_status_label.text.contains("RUNWAY CONTROL"):
		_fail("HUD should expose the runway control panel.")
		return
	if not hud.atc_status_label.text.contains("DEP DEP-B"):
		_fail("HUD runway control panel should show next aircraft.")
		return
	if not hud.atc_status_label.text.contains("SEP 3s"):
		_fail("HUD runway control panel should show separation countdown.")
		return

	dispatcher._process(2.0)
	if dispatcher.get_active_count() != 0:
		_fail("Second departure should not clear before full spacing.")
		return
	var remaining := dispatcher.get_separation_remaining(
		runway_uid
	)
	if remaining >= 0.6 or remaining <= 0.3:
		_fail("Separation countdown should decrease with dispatcher time.")
		return

	dispatcher._process(0.6)
	if dispatcher.get_active_count() != 1:
		_fail("Second departure should clear once spacing expires.")
		return
	if second.state != "CLEARED":
		_fail("Second aircraft should enter CLEARED after pacing delay.")
		return

	second.runway_cleared.emit()
	await process_frame

	# If the runway stays idle for part of the spacing window, a later
	# request should only wait for the remaining portion, not restart it.
	dispatcher._process(1.5)

	var third := AircraftPrototype.new()
	root.add_child(third)
	third.configure_aircraft_type("pico_p8")
	third.set_departure_route(
		routes[0]["route"],
		"S",
		int(routes[0].get("stand_uid", -1)),
		runway_uid
	)
	third.assign_flight_plan({
		"destination_id": "pacing-late",
		"city": "Pacing Late",
		"duration_seconds": 1.0
	})
	third.mark_service_complete()
	dispatcher.request_departure(third, "DEP-C")
	third.hold_short_reached.emit()

	var late_remaining := dispatcher.get_separation_remaining(
		runway_uid
	)
	if late_remaining >= 1.1 or late_remaining <= 0.8:
		_fail("Late request should inherit elapsed runway separation time.")
		return

	dispatcher._process(1.1)
	if third.state != "CLEARED":
		_fail("Late departure should clear after only remaining separation.")
		return

	var final_snapshot := dispatcher.get_atc_snapshot()
	if int(final_snapshot.get("active", 0)) != 1:
		_fail("ATC snapshot should report the active runway movement.")
		return

	print(
		"Runway pacing passed: separation table, countdown, delayed release, "
		+ "ATC sequence, and elapsed idle-time carryover."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
