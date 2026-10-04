extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.is_empty():
		_fail("Starter airport should expose a runway route.")
		return

	var runway_uid := int(
		routes[0].get("runway_uid", -1)
	)
	var dispatcher := RunwayDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	# Establish a useful session sample before running movements.
	dispatcher._process(12.5)

	var planes: Array[AircraftPrototype] = []
	for index in range(3):
		var plane := AircraftPrototype.new()
		root.add_child(plane)
		plane.configure_aircraft_type("pico_p8")
		plane.set_departure_route(
			routes[0]["route"],
			"S",
			int(routes[0].get("stand_uid", -1)),
			runway_uid
		)
		plane.assign_flight_plan({
			"destination_id": "analytics-%d" % index,
			"city": "Analytics",
			"duration_seconds": 1.0
		})
		plane.mark_service_complete()
		planes.append(plane)

	dispatcher.request_departure(
		planes[0],
		"ANA-A"
	)
	planes[0].hold_short_reached.emit()
	if dispatcher.get_active_count() != 1:
		_fail("First analytics movement should receive runway clearance.")
		return

	dispatcher._process(2.0)
	planes[0].runway_cleared.emit()

	dispatcher.request_departure(
		planes[1],
		"ANA-B"
	)
	planes[1].hold_short_reached.emit()
	if dispatcher.get_waiting_count() != 1:
		_fail("Second analytics movement should wait for separation.")
		return

	dispatcher._process(2.0)
	var mid_stats := dispatcher.get_runway_analytics(
		runway_uid
	)
	if float(
		mid_stats.get("queue_wait_seconds", 0.0)
	) < 1.9:
		_fail("Analytics should accumulate queued-aircraft wait time.")
		return
	if float(
		mid_stats.get("separation_wait_seconds", 0.0)
	) < 1.9:
		_fail("Analytics should isolate separation-caused wait.")
		return

	dispatcher._process(0.6)
	if planes[1].state != "CLEARED":
		_fail("Second movement should clear after separation.")
		return
	dispatcher._process(1.5)
	planes[1].runway_cleared.emit()

	dispatcher.request_departure(
		planes[2],
		"ANA-C"
	)
	planes[2].hold_short_reached.emit()
	dispatcher._process(2.0)
	dispatcher._process(0.6)
	dispatcher._process(1.5)
	planes[2].runway_cleared.emit()

	var stats := dispatcher.get_runway_analytics(
		runway_uid
	)
	if int(stats.get("movements", 0)) != 3:
		_fail("Runway analytics should count completed movements.")
		return
	if int(stats.get("departures", 0)) != 3:
		_fail("Runway analytics should count completed departures.")
		return
	if float(
		stats.get("utilization_pct", 0.0)
	) <= 10.0:
		_fail("Active runway time should produce non-trivial utilization.")
		return
	if float(
		stats.get("average_wait_seconds", 0.0)
	) <= 1.0:
		_fail("Queued separation should produce measurable average wait.")
		return
	if float(
		stats.get("separation_delay_pct", 0.0)
	) < 80.0:
		_fail("This controlled sample should identify separation as main delay.")
		return

	var summary := dispatcher.get_runway_analytics_snapshot()
	var recommendation: Dictionary = summary.get(
		"recommendation",
		{}
	)
	if String(
		recommendation.get("id", "")
	) != "upgrade_atc":
		_fail("Separation-heavy sample should recommend upgrading ATC first.")
		return

	# Assignment overrides are recorded only when a real live assignment
	# decision is explicitly committed.
	dispatcher.runway_strategy_by_uid[91] = (
		RunwayStrategyRules.ARRIVALS
	)
	dispatcher.runway_strategy_by_uid[92] = (
		RunwayStrategyRules.DEPARTURES
	)
	dispatcher.record_assignment_decision(
		[
			{"runway_uid": 91},
			{"runway_uid": 92}
		],
		{"runway_uid": 92},
		"arrival"
	)
	var override_summary := dispatcher.get_runway_analytics_snapshot()
	if int(
		override_summary.get(
			"strategy_overrides",
			0
		)
	) != 1:
		_fail("Live non-preferred assignment should count as a strategy override.")
		return

	var add_runway := RunwayAnalyticsRules.recommendation({
		"runway_count": 1,
		"tracked_seconds": 60.0,
		"movements": 12,
		"average_utilization_pct": 79.0,
		"max_utilization_pct": 79.0,
		"min_utilization_pct": 79.0,
		"average_wait_seconds": 3.8,
		"separation_delay_pct": 18.0,
		"strategy_override_pct": 0.0,
		"separation_multiplier": 0.68
	})
	if String(add_runway.get("id", "")) != "add_runway":
		_fail("Occupancy-heavy max-ATC sample should recommend another runway.")
		return

	var rebalance := RunwayAnalyticsRules.recommendation({
		"runway_count": 2,
		"tracked_seconds": 60.0,
		"movements": 12,
		"average_utilization_pct": 51.0,
		"max_utilization_pct": 72.0,
		"min_utilization_pct": 34.0,
		"average_wait_seconds": 1.6,
		"separation_delay_pct": 20.0,
		"strategy_override_pct": 35.0,
		"separation_multiplier": 0.76
	})
	if String(
		rebalance.get("id", "")
	) != "rebalance_roles":
		_fail("High override / utilization-gap sample should recommend rebalancing roles.")
		return

	var runway := grid.get_runway_buildings()[0]
	var panel := RunwayStrategyPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open_runway(
		runway,
		RunwayStrategyRules.AUTO,
		1,
		stats,
		recommendation
	)
	if not panel.analytics_label.text.contains("Utilization"):
		_fail("Runway Strategy panel should expose utilization analytics.")
		return
	if not panel.analytics_label.text.contains("Avg wait"):
		_fail("Runway Strategy panel should expose average runway wait.")
		return
	if not panel.recommendation_label.text.contains("Upgrade ATC first"):
		_fail("Runway panel should expose actionable capacity advice.")
		return

	var hud_script = load("res://src/ui/HUD.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	hud.set_atc_state(
		dispatcher.get_atc_snapshot()
	)
	var atc_detail: Dictionary = hud.status_details.get(
		"atc",
		{}
	)
	var atc_body := String(
		atc_detail.get("body", "")
	)
	if not atc_body.contains("avg wait"):
		_fail("ATC detail should include runway analytics.")
		return
	if not atc_body.contains("Advice:"):
		_fail("ATC detail should include capacity recommendation.")
		return

	print(
		"Runway analytics passed: utilization, queue/separation delay, movements, "
		+ "strategy overrides, investment advice, runway panel and ATC HUD."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
