extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var routes := grid.get_departure_routes("S")
	if routes.size() < 2:
		_fail("Starter airport should expose two S-class stands.")
		return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)

	var plane_a := AircraftPrototype.new()
	var plane_b := AircraftPrototype.new()
	root.add_child(plane_a)
	root.add_child(plane_b)
	plane_a.configure_aircraft_type("pico_p8")
	plane_b.configure_aircraft_type("pico_p8")
	plane_a.set_departure_route(
		routes[0]["route"],
		"S",
		int(routes[0].get("stand_uid", -1)),
		int(routes[0].get("runway_uid", -1))
	)
	plane_b.set_departure_route(
		routes[1]["route"],
		"S",
		int(routes[1].get("stand_uid", -1)),
		int(routes[1].get("runway_uid", -1))
	)

	dispatcher.request_fuel(plane_a, "OPS-A")
	dispatcher.request_fuel(plane_b, "OPS-B")

	if dispatcher.get_waiting_count() != 1:
		_fail("Second starter fuel request should queue behind the first.")
		return

	dispatcher._process(2.0)
	var service_snapshot := dispatcher.get_service_analytics_snapshot()
	var fuel: Dictionary = service_snapshot.get("fuel", {})
	if int(fuel.get("requests", 0)) != 2:
		_fail("Fuel analytics should count both requests.")
		return
	if int(fuel.get("current_waiting", 0)) != 1:
		_fail("Fuel analytics should expose current queue depth.")
		return
	if int(fuel.get("current_active", 0)) != 1:
		_fail("Fuel analytics should expose active fuel vehicle count.")
		return
	if int(fuel.get("capacity", 0)) < 1:
		_fail("Fuel analytics should expose installed fleet capacity.")
		return
	if float(fuel.get("utilization_pct", 0.0)) < 95.0:
		_fail("Saturated starter fuel station should show near-100% utilization.")
		return
	if float(fuel.get("average_wait_seconds", 0.0)) < 0.9:
		_fail("Queued fuel request should produce measurable average wait.")
		return
	if int(fuel.get("peak_waiting", 0)) != 1:
		_fail("Fuel analytics should record peak queue depth.")
		return

	var fuel_bottleneck := OperationsAnalyticsRules.analyze({
		"runway": {
			"average_utilization_pct": 20.0,
			"max_utilization_pct": 20.0,
			"average_wait_seconds": 0.2,
			"separation_delay_pct": 0.0,
			"recommendation": {
				"title": "Capacity healthy",
				"tone": "success"
			}
		},
		"services": {
			"fuel": {
				"utilization_pct": 96.0,
				"average_wait_seconds": 4.0,
				"current_waiting": 2,
				"peak_waiting": 3
			},
			"cleaning": {
				"utilization_pct": 22.0,
				"average_wait_seconds": 0.0,
				"current_waiting": 0,
				"peak_waiting": 0
			}
		},
		"passengers": {
			"stock": 70,
			"capacity": 80,
			"production_per_minute": 4.0,
			"waiting_aircraft": 0
		},
		"stands": {
			"total": 4,
			"occupied": 2,
			"pending_arrivals": 0
		}
	})
	var fuel_rec: Dictionary = fuel_bottleneck.get(
		"recommendation",
		{}
	)
	if String(fuel_rec.get("id", "")) != "fuel":
		_fail("Fuel pressure should rank as the primary airport bottleneck.")
		return
	if not String(
		fuel_rec.get("title", "")
	).contains("fuel"):
		_fail("Fuel bottleneck should recommend fuel capacity/speed.")
		return

	var passenger_bottleneck := OperationsAnalyticsRules.analyze({
		"runway": {
			"average_utilization_pct": 10.0,
			"max_utilization_pct": 10.0,
			"average_wait_seconds": 0.0,
			"separation_delay_pct": 0.0,
			"recommendation": {
				"title": "Capacity healthy",
				"tone": "success"
			}
		},
		"services": {},
		"passengers": {
			"stock": 4,
			"capacity": 80,
			"production_per_minute": 2.0,
			"waiting_aircraft": 2
		},
		"stands": {
			"total": 4,
			"occupied": 2,
			"pending_arrivals": 0
		}
	})
	if String(
		(passenger_bottleneck.get(
			"recommendation",
			{}
		) as Dictionary).get("id", "")
	) != "passenger_stock":
		_fail("Low passenger stock with waiting aircraft should be the primary bottleneck.")
		return

	var stand_bottleneck := OperationsAnalyticsRules.analyze({
		"runway": {
			"average_utilization_pct": 15.0,
			"max_utilization_pct": 15.0,
			"average_wait_seconds": 0.0,
			"separation_delay_pct": 0.0,
			"recommendation": {
				"title": "Capacity healthy",
				"tone": "success"
			}
		},
		"services": {},
		"passengers": {
			"stock": 70,
			"capacity": 80,
			"production_per_minute": 4.0,
			"waiting_aircraft": 0
		},
		"stands": {
			"total": 2,
			"occupied": 2,
			"pending_arrivals": 2
		}
	})
	if String(
		(stand_bottleneck.get(
			"recommendation",
			{}
		) as Dictionary).get("id", "")
	) != "stands":
		_fail("Full stands with holding arrivals should recommend another stand.")
		return

	var runway_bottleneck := OperationsAnalyticsRules.analyze({
		"runway": {
			"average_utilization_pct": 78.0,
			"max_utilization_pct": 84.0,
			"average_wait_seconds": 4.0,
			"separation_delay_pct": 20.0,
			"recommendation": {
				"title": "Add runway capacity",
				"tone": "warning"
			}
		},
		"services": {},
		"passengers": {
			"stock": 70,
			"capacity": 80,
			"production_per_minute": 4.0,
			"waiting_aircraft": 0
		},
		"stands": {
			"total": 4,
			"occupied": 2,
			"pending_arrivals": 0
		}
	})
	if String(
		(runway_bottleneck.get(
			"recommendation",
			{}
		) as Dictionary).get("id", "")
	) != "runway":
		_fail("Heavy runway pressure should rank runway/ATC as the bottleneck.")
		return

	var hud_script = load("res://src/ui/HUD.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	hud.set_operation_status(
		"Fueling aircraft",
		"normal"
	)
	hud.set_operations_analytics({
		"analysis": fuel_bottleneck
	})
	var operations_detail: Dictionary = hud.status_details.get(
		"operations",
		{}
	)
	var body := String(
		operations_detail.get("body", "")
	)
	if not body.contains("BOTTLENECK"):
		_fail("Ground Ops detail should include bottleneck recommendation.")
		return
	if not body.contains("TOP PRESSURE"):
		_fail("Ground Ops detail should include ranked pressure systems.")
		return
	if not body.contains("Fuel"):
		_fail("Ground Ops detail should expose the top fuel bottleneck.")
		return

	print(
		"Airport operations analytics passed: service utilization/queue tracking, "
		+ "fuel/passenger/stand/runway ranking and Ground Ops bottleneck view."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
