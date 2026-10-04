extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var aircraft := AircraftCatalog.all()
	if aircraft.size() != 9:
		_fail("Reconciled V1 catalog should contain exactly nine S/M aircraft.")
		return

	var expected_ids := [
		"pico_p8",
		"swift_s14",
		"comet_c22",
		"voyager_v32",
		"nimbus_n40",
		"arrow_a52",
		"atlas_a64",
		"falcon_f72",
		"horizon_h88"
	]
	for aircraft_id in expected_ids:
		var profile := AircraftCatalog.get_profile(aircraft_id)
		if profile.is_empty():
			_fail("Missing reconciled aircraft profile: %s" % aircraft_id)
			return
		if int(profile.get("purchase_price", 0)) <= 0:
			_fail("%s should retain a real purchase price." % aircraft_id)
			return
		if int(profile.get("hangar_space", 0)) != 1:
			_fail("%s should currently use one S/M hangar slot." % aircraft_id)
			return

	var pico := AircraftCatalog.get_profile("pico_p8")
	var brussels := DestinationCatalog.get_destination("brussels")
	var bremen := DestinationCatalog.get_destination("bremen")
	var london := DestinationCatalog.get_destination("london")

	if not FlightRules.can_fly(pico, brussels):
		_fail("Pico P8 should reach Brussels.")
		return
	if not FlightRules.can_fly(pico, bremen):
		_fail("Pico P8 should reach Bremen for early German resources.")
		return
	if FlightRules.can_fly(pico, london):
		_fail("Pico P8 should preserve its 320 km range and not reach London.")
		return

	var upgrade := PassengerUpgradeCatalog.get_next_level(
		"travel_office",
		1
	)
	var resource_cost: Dictionary = upgrade.get("resource_cost", {})
	if int(resource_cost.get("be_chocolate", 0)) != 2:
		_fail("Travel Office Lv2 should still need two Belgium Chocolate.")
		return
	if int(resource_cost.get("de_industrial_tools", 0)) != 1:
		_fail("Travel Office Lv2 should use a Pico-reachable Germany resource.")
		return
	if resource_cost.has("gb_specialty_goods"):
		_fail("Travel Office Lv2 should no longer require out-of-range UK resources.")
		return

	var small_hangar := BuildingCatalog.get_definition("small_hangar")
	if int(small_hangar.get("hangar_capacity", 0)) != 3:
		_fail("Small Hangar should expose three aircraft-capacity slots.")
		return
	if String(small_hangar.get("max_aircraft_size", "")) != "S":
		_fail("Small Hangar should remain S-only.")
		return

	var regional_hangar := BuildingCatalog.get_definition("regional_hangar")
	if regional_hangar.is_empty():
		_fail("Regional Hangar should exist in the reconciled catalog.")
		return
	if int(regional_hangar.get("level", 0)) != 8:
		_fail("Regional Hangar should unlock at airport Lv8.")
		return
	if int(regional_hangar.get("cost", 0)) != 105000:
		_fail("Regional Hangar should cost 105,000 coins.")
		return
	if int(regional_hangar.get("hangar_capacity", 0)) != 5:
		_fail("Regional Hangar should provide five capacity slots.")
		return

	var medium_stand := BuildingCatalog.get_definition("medium_stand")
	var regional_fuel := BuildingCatalog.get_definition("regional_fuel")
	var regional_runway := BuildingCatalog.get_definition("regional_runway")
	if int(medium_stand.get("cost", 0)) != 45000:
		_fail("Medium Stand should cost 45,000 coins.")
		return
	if int(regional_fuel.get("cost", 0)) != 60000:
		_fail("Regional Fuel Depot should cost 60,000 coins.")
		return
	if int(regional_runway.get("cost", 0)) != 150000:
		_fail("Regional Runway should cost 150,000 coins.")
		return
	if int(regional_runway.get("level", 0)) != 8:
		_fail("Regional Runway should be part of the Lv8 regional project.")
		return

	var level_eight_project := (
		int(medium_stand.get("cost", 0))
		+ int(regional_fuel.get("cost", 0))
		+ int(regional_hangar.get("cost", 0))
		+ int(regional_runway.get("cost", 0))
		+ int(AircraftCatalog.get_profile("nimbus_n40").get("purchase_price", 0))
	)
	if level_eight_project != 545000:
		_fail("First M-aircraft project should total 545,000 coins.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	var plan := FlightRules.create_flight_plan(pico, brussels)
	plane.assign_flight_plan(plan)
	plane.clear_flight_plan()
	if plane.has_flight_plan():
		_fail("Completed aircraft should be able to clear its previous route.")
		return

	print("Reconciled V1 aircraft, passenger access, and S-to-M bottleneck passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
