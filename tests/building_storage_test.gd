extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var fuel := _find_building(grid, "basic_fuel")
	var runway := _find_building(grid, "short_runway")
	if fuel.is_empty() or runway.is_empty():
		_fail("Starter airport should contain fuel and runway buildings.")
		return

	var fuel_uid := int(fuel.get("uid", -1))
	var runway_uid := int(runway.get("uid", -1))
	if not bool(
		grid.get_storage_eligibility(fuel_uid).get("storable", false)
	):
		_fail("Basic Fuel Station should be storable.")
		return
	if bool(
		grid.get_storage_eligibility(runway_uid).get("storable", true)
	):
		_fail("Runway infrastructure must not be storable.")
		return

	grid.set_building_upgrade_level(fuel_uid, 3)
	var original := grid.get_building(fuel_uid)
	var store_result := grid.store_building(fuel_uid)
	if not bool(store_result.get("valid", false)):
		_fail("Movable building should enter storage.")
		return
	if not grid.get_building(fuel_uid).is_empty():
		_fail("Stored building should be removed from the live airport.")
		return

	var stored := grid.get_stored_building(fuel_uid)
	if stored.is_empty():
		_fail("Stored building should remain owned in airport storage.")
		return
	if int(stored.get("upgrade_level", 1)) != 3:
		_fail("Storage must preserve building upgrade level.")
		return

	var begin := grid.begin_stored_building_preview(fuel_uid)
	if not bool(begin.get("valid", false)):
		_fail("Stored building should be selectable for placement.")
		return

	var blocked := grid.set_stored_building_preview(
		grid.tile_to_world(Vector2(8, 8)),
		0
	)
	if bool(blocked.get("valid", false)):
		_fail("Stored placement should still reject occupied runway tiles.")
		return

	grid.clear_build_preview()
	if grid.get_stored_building(fuel_uid).is_empty():
		_fail("Cancelling placement should leave the building in storage.")
		return

	grid.select_parcel("north")
	grid.purchase_selected()
	begin = grid.begin_stored_building_preview(fuel_uid)
	if not bool(begin.get("valid", false)):
		_fail("Stored building should re-enter placement after cancel.")
		return

	var target := Vector2i(13, 0)
	var status := grid.set_stored_building_preview(
		grid.tile_to_world(Vector2(target.x, target.y)),
		0
	)
	if not bool(status.get("valid", false)):
		_fail(
			"Stored building should place on clear owned land: %s"
			% String(status.get("reason", "unknown"))
		)
		return

	var restored := grid.confirm_stored_building_preview()
	if restored.is_empty():
		_fail("Confirm should place the stored building.")
		return
	if not grid.get_stored_building(fuel_uid).is_empty():
		_fail("Placed building should leave airport storage.")
		return

	var placed := grid.get_building(fuel_uid)
	if placed.get("origin", Vector2i.ZERO) != target:
		_fail("Placed stored building should use the chosen grid origin.")
		return
	if int(placed.get("upgrade_level", 1)) != 3:
		_fail("Placing from storage must preserve upgrades.")
		return

	store_result = grid.store_building(fuel_uid)
	if not bool(store_result.get("valid", false)):
		_fail("Placed building should be storable again.")
		return

	var saved_layout := grid.export_airport_layout()
	var saved_storage := grid.export_airport_storage()
	var saved_parcels := grid.export_owned_parcels()
	if saved_storage.size() != 1:
		_fail("Storage export should contain the stored building.")
		return

	var restored_grid := AirportGrid.new()
	root.add_child(restored_grid)
	await process_frame
	# The visual-QA starter composition spans multiple districts after the
	# scale pass. Give that showcase its full parcel envelope while this test
	# verifies storage state and upgrade persistence.
	var restore_parcels: Array[String] = []
	for parcel_id_variant in grid.parcels.keys():
		restore_parcels.append(String(parcel_id_variant))
	if not restored_grid.apply_saved_airport_layout(
		saved_layout,
		restore_parcels,
		saved_storage
	):
		_fail("Airport layout and storage should restore together.")
		return

	var restored_storage := restored_grid.get_stored_building(
		fuel_uid
	)
	if restored_storage.is_empty():
		_fail("Stored building should survive save/restore.")
		return
	if int(restored_storage.get("upgrade_level", 1)) != 3:
		_fail("Restored storage should preserve upgrades.")
		return
	if not restored_grid.get_building(fuel_uid).is_empty():
		_fail("Restored stored building must remain off the live airport.")
		return

	if String(
		original.get("definition_id", "")
	) != String(
		restored_storage.get("definition_id", "")
	):
		_fail("Stored building identity should stay stable.")
		return

	var effect_grid := AirportGrid.new()
	root.add_child(effect_grid)
	await process_frame
	var travel_office := _find_building(
		effect_grid,
		"travel_office"
	)
	if travel_office.is_empty():
		_fail("Starter airport should contain a Travel Office.")
		return

	var passenger_economy := PassengerEconomy.new()
	root.add_child(passenger_economy)
	passenger_economy.configure(effect_grid, 0.0)
	var capacity_before := passenger_economy.get_capacity()
	var production_before := (
		passenger_economy.get_production_per_minute()
	)
	if capacity_before <= 0 or production_before <= 0.0:
		_fail("Travel Office should contribute passenger capacity and production.")
		return

	var travel_uid := int(travel_office.get("uid", -1))
	var travel_store := effect_grid.store_building(travel_uid)
	if not bool(travel_store.get("valid", false)):
		_fail("Travel Office should be storable for pause-effect testing.")
		return
	passenger_economy.refresh_building_stats()
	if passenger_economy.get_capacity() >= capacity_before:
		_fail("Stored passenger building should stop contributing capacity.")
		return
	if (
		passenger_economy.get_production_per_minute()
		>= production_before
	):
		_fail("Stored passenger building should stop producing passengers.")
		return

	print(
		"Building storage passed: eligibility, store, cancel, place, "
		+ "upgrade preservation and save/restore."
	)
	quit(0)


func _find_building(
	grid: AirportGrid,
	definition_id: String
) -> Dictionary:
	for uid in range(1, 100):
		var building := grid.get_building(uid)
		if String(
			building.get("definition_id", "")
		) == definition_id:
			return building
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
