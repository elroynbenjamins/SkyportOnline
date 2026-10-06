extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var travel_office: Dictionary = {}
	var terminal: Dictionary = {}
	var fuel: Dictionary = {}
	var stands: Array[Dictionary] = []
	for building in grid.placed_buildings:
		var id := String(building.get("definition_id", ""))
		match id:
			"travel_office":
				travel_office = building
			"small_terminal":
				terminal = building
			"basic_fuel":
				fuel = building
		if id.contains("stand"):
			stands.append(building)

	if travel_office.is_empty() or terminal.is_empty():
		_fail("Starter airport should include passenger synergy buildings.")
		return
	if fuel.is_empty() or stands.size() < 2:
		_fail("Starter airport should include fuel and two stands.")
		return

	var passenger_synergy := grid.get_passenger_synergy(
		int(travel_office.get("uid", -1))
	)
	if not bool(passenger_synergy.get("active", false)):
		_fail("Starter Travel Office should be inside terminal synergy range.")
		return
	if int(passenger_synergy.get("bonus_pct", 0)) != 10:
		_fail("Travel Office terminal synergy should provide +10% production.")
		return
	if int(passenger_synergy.get("target_uid", -1)) != int(
		terminal.get("uid", -1)
	):
		_fail("Passenger synergy should identify the Small Terminal provider.")
		return

	var terminal_summary := grid.get_building_synergy_summary(
		int(terminal.get("uid", -1))
	)
	if int(terminal_summary.get("covered_count", 0)) != 1:
		_fail("Starter Small Terminal should cover exactly the Travel Office.")
		return
	if not String(
		terminal_summary.get("preview_text", "")
	).contains("Boosts 1 passenger"):
		_fail("Terminal synergy summary should explain its coverage.")
		return

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 20.0)
	if absf(economy.get_base_production_per_minute() - 1.5) > 0.001:
		_fail("Synergy must not mutate the Travel Office base rate.")
		return
	if absf(economy.get_production_per_minute() - 1.65) > 0.001:
		_fail("Passenger economy should apply the +10% terminal boost.")
		return

	var far_passenger := grid.get_preview_synergy_summary(
		"travel_office",
		Vector2i(14, 2),
		0,
		int(travel_office.get("uid", -1))
	)
	if bool(far_passenger.get("active", true)):
		_fail("Travel Office preview outside terminal range should lose synergy.")
		return
	if not String(
		far_passenger.get("preview_text", "")
	).contains("Outside terminal"):
		_fail("Out-of-range passenger preview should explain the lost bonus.")
		return

	var fuel_uid := int(fuel.get("uid", -1))
	var fuel_coverage := grid.get_service_coverage_summary(fuel_uid)
	if int(fuel_coverage.get("covered_count", -1)) != 0:
		_fail(
			"Spaced starter Fuel Station should not grant a free proximity bonus."
		)
		return
	if int(fuel_coverage.get("bonus_pct", 0)) != 8:
		_fail("Basic Fuel Station local-zone bonus should remain +8%.")
		return

	var first_stand_uid := int(stands[0].get("uid", -1))
	var fuel_synergy := grid.get_service_synergy(
		fuel_uid,
		first_stand_uid,
		"fuel"
	)
	if bool(fuel_synergy.get("active", true)):
		_fail(
			"Starter stand should rely on its service-road route, not proximity synergy."
		)
		return
	if absf(
		float(fuel_synergy.get("multiplier", 1.0)) - 1.0
	) > 0.001:
		_fail("Out-of-range starter stand should use the normal x1.0 fuel speed.")
		return

	var nearby_fuel_preview := grid.get_preview_synergy_summary(
		"basic_fuel",
		Vector2i(8, 6),
		0,
		fuel_uid
	)
	if not bool(nearby_fuel_preview.get("active", false)):
		_fail("Moving a fuel station beside stands should activate local synergy.")
		return
	if int(nearby_fuel_preview.get("covered_count", 0)) != 2:
		_fail("Nearby fuel preview should cover both starter stands.")
		return

	var dispatcher := GroundServiceDispatcher.new()
	root.add_child(dispatcher)
	dispatcher.configure(grid)
	var candidates := grid.get_compatible_service_buildings(
		"fuel",
		"S"
	)
	var station := dispatcher._first_available_station(
		candidates,
		first_stand_uid,
		"fuel"
	)
	if not station.is_empty():
		_fail(
			"Fuel station should not dispatch before the player builds a service road."
		)
		return

	var service_cells: Array[Vector2i] = [
		Vector2i(12, 11),
		Vector2i(12, 10),
		Vector2i(12, 9),
		Vector2i(12, 8),
		Vector2i(12, 7),
		Vector2i(11, 8),
		Vector2i(10, 8),
		Vector2i(9, 8),
		Vector2i(8, 8),
		Vector2i(7, 8)
	]
	for service_cell in service_cells:
		grid._place_building_internal(
			"service_road",
			service_cell,
			0
		)
	grid._rebuild_occupied_cells()
	dispatcher.refresh_after_layout_change()

	candidates = grid.get_compatible_service_buildings(
		"fuel",
		"S"
	)
	station = dispatcher._first_available_station(
		candidates,
		first_stand_uid,
		"fuel"
	)
	if station.is_empty():
		_fail("Player-built service road should unlock fuel dispatch.")
		return
	if absf(
		float(
			station.get(
				"effective_service_speed",
				0.0
			)
		) - 1.0
	) > 0.001:
		_fail(
			"Spaced starter fuel station should use normal service speed."
		)
		return
	if int(station.get("synergy_bonus_pct", -1)) != 0:
		_fail("Dispatcher should report no proximity bonus at starter spacing.")
		return

	var far_service := grid.get_preview_synergy_summary(
		"basic_fuel",
		Vector2i(14, 1),
		0,
		fuel_uid
	)
	if bool(far_service.get("active", true)):
		_fail("Far fuel-station preview should have no covered starter stands.")
		return
	if int(far_service.get("covered_count", -1)) != 0:
		_fail("Far service preview should report zero covered stands.")
		return

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	var fuel_definition := BuildingCatalog.get_definition(
		"basic_fuel"
	)
	hud.show_move_preview(
		fuel_definition,
		{
			"valid": true,
			"footprint": Vector2i(2, 2),
			"synergy": nearby_fuel_preview
		}
	)
	if not hud.build_status.text.contains("✦"):
		_fail("Active move preview should visibly mark synergy.")
		return
	if not hud.build_status.text.contains("service speed"):
		_fail("Move preview should explain the local service-speed bonus.")
		return

	for building_id in [
		"travel_office",
		"shuttle_station",
		"ground_ops_depot",
		"cleaning_center",
		"passenger_service_hub",
		"baggage_depot",
		"catering_kitchen",
		"tow_operations"
	]:
		var definition := BuildingCatalog.get_definition(building_id)
		var icon_path := String(definition.get("icon_path", ""))
		if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
			_fail("%s should have a real synergy-pass icon." % building_id)
			return

	print(
		"Building synergy passed: passenger hub boost, local service zones, "
		+ "effective dispatch speed, move-preview feedback and facility icons."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
