extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var fuel_inventory := {
		"be_chemicals": 2,
		"de_industrial_tools": 2
	}
	var fuel_snapshot := {
		"runway": {
			"average_wait_seconds": 0.0,
			"max_utilization_pct": 20.0,
			"separation_delay_pct": 0.0,
			"separation_multiplier": 1.0
		},
		"services": {
			"fuel": {
				"average_wait_seconds": 5.0,
				"current_waiting": 2,
				"utilization_pct": 100.0
			}
		},
		"passengers": {
			"stock": 40,
			"capacity": 80,
			"production_per_minute": 4.0,
			"waiting_aircraft": 0,
			"waiting_shortfall": 0
		},
		"stands": {
			"pending_arrivals": 0,
			"max_current_hold_seconds": 0.0
		}
	}

	var fuel_payoff := OperationsPayoffEstimator.estimate(
		fuel_snapshot,
		grid,
		fuel_inventory,
		4,
		100000
	)
	var fuel_candidates: Array = fuel_payoff.get(
		"ranked",
		[]
	)
	if fuel_candidates.is_empty():
		_fail("Fuel pressure should produce at least one upgrade payoff candidate.")
		return

	var fuel_candidate: Dictionary = {}
	for candidate_variant in fuel_candidates:
		var candidate: Dictionary = candidate_variant
		if String(
			candidate.get("building_id", "")
		) == "basic_fuel":
			fuel_candidate = candidate
			break

	if fuel_candidate.is_empty():
		_fail("Starter Basic Fuel Station should produce a fuel upgrade candidate.")
		return
	if float(
		fuel_candidate.get(
			"estimated_delay_saved_seconds",
			0.0
		)
	) <= 0.0:
		_fail("Fuel upgrade candidate should estimate positive delay reduction.")
		return
	if float(
		fuel_candidate.get(
			"delay_saved_per_10k",
			0.0
		)
	) <= 0.0:
		_fail("Fuel upgrade should expose seconds saved per 10k coins.")
		return
	if not bool(
		fuel_candidate.get(
			"affordable_now",
			false
		)
	):
		_fail("Funded Basic Fuel upgrade should be marked affordable now.")
		return

	var blocked_fuel := OperationsPayoffEstimator.estimate(
		fuel_snapshot,
		grid,
		{},
		4,
		100000
	)
	var blocked_candidate: Dictionary = {}
	for candidate_variant in blocked_fuel.get("ranked", []):
		var candidate: Dictionary = candidate_variant
		if String(
			candidate.get("building_id", "")
		) == "basic_fuel":
			blocked_candidate = candidate
			break
	if blocked_candidate.is_empty():
		_fail("Blocked fuel upgrade should still remain visible in payoff ranking.")
		return
	if int(
		blocked_candidate.get(
			"resource_missing_total",
			0
		)
	) <= 0:
		_fail("Missing regional resources should be exposed on the candidate.")
		return
	if bool(
		blocked_candidate.get(
			"affordable_now",
			true
		)
	):
		_fail("Resource-blocked upgrade should not be marked affordable now.")
		return

	var passenger_buildings := grid.get_passenger_generator_buildings()
	if passenger_buildings.is_empty():
		_fail("Starter airport should expose passenger production building.")
		return
	var passenger_building: Dictionary = passenger_buildings[0]
	var passenger_id := String(
		passenger_building.get(
			"definition_id",
			""
		)
	)
	var passenger_level := int(
		passenger_building.get(
			"upgrade_level",
			1
		)
	)
	var passenger_next := PassengerUpgradeCatalog.get_next_level(
		passenger_id,
		passenger_level
	)
	if passenger_next.is_empty():
		_fail("Starter passenger building should have an upgrade.")
		return

	var passenger_inventory: Dictionary = {}
	var passenger_resource_cost: Dictionary = passenger_next.get(
		"resource_cost",
		{}
	)
	for resource_id in passenger_resource_cost.keys():
		passenger_inventory[resource_id] = int(
			passenger_resource_cost[resource_id]
		)

	var passenger_snapshot := fuel_snapshot.duplicate(true)
	passenger_snapshot["services"] = {}
	passenger_snapshot["passengers"] = {
		"stock": 2,
		"capacity": 80,
		"production_per_minute": 2.0,
		"waiting_aircraft": 1,
		"waiting_required_total": 22,
		"waiting_shortfall": 20
	}
	var passenger_payoff := OperationsPayoffEstimator.estimate(
		passenger_snapshot,
		grid,
		passenger_inventory,
		4,
		100000
	)
	var saw_passenger_upgrade := false
	for candidate_variant in passenger_payoff.get("ranked", []):
		var candidate: Dictionary = candidate_variant
		if String(
			candidate.get("kind", "")
		) == "passenger_upgrade":
			saw_passenger_upgrade = true
			if float(
				candidate.get(
					"estimated_delay_saved_seconds",
					0.0
				)
			) <= 0.0:
				_fail("Passenger upgrade should estimate positive recovery-time savings.")
				return
			break
	if not saw_passenger_upgrade:
		_fail("Passenger shortfall should produce a passenger upgrade candidate.")
		return

	var atc_snapshot := fuel_snapshot.duplicate(true)
	atc_snapshot["services"] = {}
	atc_snapshot["runway"] = {
		"average_wait_seconds": 5.0,
		"max_utilization_pct": 55.0,
		"separation_delay_pct": 80.0,
		"separation_multiplier": 1.0
	}
	var atc_payoff := OperationsPayoffEstimator.estimate(
		atc_snapshot,
		grid,
		{},
		9,
		100000
	)
	var saw_atc := false
	for candidate_variant in atc_payoff.get("ranked", []):
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("kind", "")) == "atc":
			saw_atc = true
			if int(candidate.get("coin_cost", 0)) != 55000:
				_fail("Building ATC Tower should use its catalog coin cost.")
				return
			if float(
				candidate.get(
					"estimated_delay_saved_seconds",
					0.0
				)
			) <= 0.0:
				_fail("ATC candidate should estimate positive separation savings.")
				return
			break
	if not saw_atc:
		_fail("Separation-heavy airport at Lv9 should produce ATC Tower candidate.")
		return

	var expansion_snapshot := fuel_snapshot.duplicate(true)
	expansion_snapshot["services"] = {}
	expansion_snapshot["runway"] = {
		"average_wait_seconds": 4.0,
		"max_utilization_pct": 90.0,
		"separation_delay_pct": 15.0,
		"separation_multiplier": 0.68
	}
	expansion_snapshot["stands"] = {
		"pending_arrivals": 2,
		"max_current_hold_seconds": 30.0
	}
	var expansion_payoff := OperationsPayoffEstimator.estimate(
		expansion_snapshot,
		grid,
		{},
		12,
		200000
	)
	var saw_stand := false
	var saw_regional_runway := false
	for candidate_variant in expansion_payoff.get("ranked", []):
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("kind", "")) == "stand":
			saw_stand = true
		elif String(
			candidate.get("building_id", "")
		) == "regional_runway":
			saw_regional_runway = true
	if not saw_stand:
		_fail("Holding arrivals should produce a stand expansion payoff candidate.")
		return
	if not saw_regional_runway:
		_fail("High runway pressure at Lv12 should produce Regional Runway candidate.")
		return

	var hud_script = load("res://src/ui/HUD.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	hud.set_operation_status(
		"Monitoring airport",
		"normal"
	)
	hud.set_operations_analytics({
		"analysis": OperationsAnalyticsRules.analyze(
			fuel_snapshot
		),
		"payoff": fuel_payoff
	})
	var detail: Dictionary = hud.status_details.get(
		"operations",
		{}
	)
	var body := String(detail.get("body", ""))
	if not body.contains("BEST PAYOFF"):
		_fail("Ground Ops detail should show best-value investment.")
		return
	if not body.contains("/ 10k coins"):
		_fail("Ground Ops payoff should show efficiency per 10k coins.")
		return
	if not body.contains("READY NOW"):
		_fail("Affordable payoff should be clearly marked ready now.")
		return

	var manual_payoff := {
		"best_value": blocked_candidate,
		"best_affordable": fuel_candidate
	}
	hud.set_operations_analytics({
		"analysis": OperationsAnalyticsRules.analyze(
			fuel_snapshot
		),
		"payoff": manual_payoff
	})
	detail = hud.status_details.get("operations", {})
	body = String(detail.get("body", ""))
	if not body.contains("BEST BUY NOW"):
		_fail("HUD should distinguish best affordable investment from blocked best value.")
		return

	print(
		"Operations payoff passed: service/passenger/ATC/stand/runway estimates, "
		+ "resource readiness, affordability and Ground Ops payoff UI."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
