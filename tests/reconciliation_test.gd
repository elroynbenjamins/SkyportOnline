extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := AircraftCatalog.all()
	if catalog.size() != 9:
		_fail("V1 should expose exactly nine S/M aircraft.")
		return

	var expected_prices := {
		"pico_p8": 12000,
		"swift_s14": 22000,
		"comet_c22": 45000,
		"voyager_v32": 82000,
		"nimbus_n40": 185000,
		"arrow_a52": 270000,
		"atlas_a64": 390000,
		"falcon_f72": 575000,
		"horizon_h88": 850000
	}
	for aircraft_id in expected_prices.keys():
		var profile := AircraftCatalog.get_profile(String(aircraft_id))
		if profile.is_empty():
			_fail("Missing aircraft profile %s." % String(aircraft_id))
			return
		if int(profile.get("purchase_price", 0)) != int(
			expected_prices[aircraft_id]
		):
			_fail("%s purchase price drifted." % String(aircraft_id))
			return
		if int(profile.get("hangar_space", 0)) != 1:
			_fail("%s should currently use one S/M hangar slot." % String(aircraft_id))
			return

	var pico := AircraftCatalog.get_profile("pico_p8")
	var brussels := DestinationCatalog.get_destination("brussels")
	var bremen := DestinationCatalog.get_destination("bremen")
	var london := DestinationCatalog.get_destination("london")
	if not FlightRules.can_fly(pico, brussels):
		_fail("Pico P8 should reach Brussels.")
		return
	if not FlightRules.can_fly(pico, bremen):
		_fail("Pico P8 should reach Bremen for early Germany resources.")
		return
	if FlightRules.can_fly(pico, london):
		_fail("Pico P8 should not reach London with its 320 km range.")
		return

	var travel_lv2 := PassengerUpgradeCatalog.get_next_level(
		"travel_office",
		1
	)
	var travel_cost: Dictionary = travel_lv2.get("resource_cost", {})
	if int(travel_cost.get("be_chocolate", 0)) != 2:
		_fail("Travel Office Lv2 should need 2 Belgium Chocolate.")
		return
	if int(travel_cost.get("de_industrial_tools", 0)) != 1:
		_fail("Travel Office Lv2 should need 1 Germany Industrial Tools.")
		return
	if travel_cost.has("gb_specialty_goods"):
		_fail("Travel Office Lv2 must not require an out-of-range UK drop.")
		return

	var small_hangar := BuildingCatalog.get_definition("small_hangar")
	if int(small_hangar.get("hangar_capacity", 0)) != 3:
		_fail("Small Hangar should expose 3 capacity slots.")
		return
	if String(small_hangar.get("max_aircraft_size", "")) != "S":
		_fail("Small Hangar should remain S-only.")
		return

	var regional_hangar := BuildingCatalog.get_definition("regional_hangar")
	var medium_stand := BuildingCatalog.get_definition("medium_stand")
	var regional_fuel := BuildingCatalog.get_definition("regional_fuel")
	var regional_runway := BuildingCatalog.get_definition("regional_runway")
	if regional_hangar.is_empty():
		_fail("Regional Hangar should exist.")
		return
	if int(regional_hangar.get("level", 0)) != 8:
		_fail("Regional Hangar should unlock at Lv8.")
		return
	if int(regional_hangar.get("cost", 0)) != 105000:
		_fail("Regional Hangar should cost 105,000.")
		return
	if int(regional_hangar.get("hangar_capacity", 0)) != 5:
		_fail("Regional Hangar should expose 5 capacity slots.")
		return
	if int(medium_stand.get("cost", 0)) != 45000:
		_fail("Medium Stand should cost 45,000.")
		return
	if int(regional_fuel.get("cost", 0)) != 60000:
		_fail("Regional Fuel Depot should cost 60,000.")
		return
	if int(regional_runway.get("cost", 0)) != 150000:
		_fail("Regional Runway should cost 150,000.")
		return
	if int(regional_runway.get("level", 0)) != 8:
		_fail("Regional Runway should be available for the Lv8 transition.")
		return

	var first_m_project := (
		int(medium_stand.get("cost", 0))
		+ int(regional_fuel.get("cost", 0))
		+ int(regional_hangar.get("cost", 0))
		+ int(regional_runway.get("cost", 0))
		+ int(AircraftCatalog.get_profile("nimbus_n40").get("purchase_price", 0))
	)
	if first_m_project != 545000:
		_fail("First M-aircraft project should total 545,000 coins.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("pico_p8")
	var plan := FlightRules.create_flight_plan(pico, brussels)
	plane.assign_flight_plan(plan)
	if not plane.has_flight_plan():
		_fail("Test plane should accept a flight plan.")
		return
	plane.clear_flight_plan()
	if plane.has_flight_plan():
		_fail("Completed aircraft should clear its previous route.")
		return

	print("Reconciled V1 foundation passed on top of passenger Pass 10.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
