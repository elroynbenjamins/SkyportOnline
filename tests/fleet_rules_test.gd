extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pico := AircraftCatalog.get_definition("pico_p8")
	var nimbus := AircraftCatalog.get_definition("nimbus_n40")
	if pico.is_empty() or nimbus.is_empty():
		_fail("Expected Pico P8 and Nimbus N40 catalog entries.")
		return

	var small_hangar: Array[Dictionary] = [{
		"capacity": 3,
		"max_aircraft_size": "S",
		"connected": true
	}]
	var two_picos: Array[Dictionary] = [pico, pico]
	var starter_status := FleetRules.capacity_status(
		small_hangar,
		two_picos
	)
	if int(starter_status.get("total_used", 0)) != 2:
		_fail("Two starter Picos should use two hangar slots.")
		return
	if int(starter_status.get("total_capacity", 0)) != 3:
		_fail("Starter small hangar should provide three slots.")
		return

	var third_pico := FleetRules.capacity_status(
		small_hangar,
		two_picos,
		pico
	)
	if not bool(third_pico.get("allowed", false)):
		_fail("The third S aircraft should fit the starter hangar.")
		return

	var three_picos: Array[Dictionary] = [pico, pico, pico]
	var fourth_pico := FleetRules.capacity_status(
		small_hangar,
		three_picos,
		pico
	)
	if bool(fourth_pico.get("allowed", true)):
		_fail("A fourth S aircraft should require more hangar capacity.")
		return

	var nimbus_on_small := FleetRules.capacity_status(
		small_hangar,
		two_picos,
		nimbus
	)
	if bool(nimbus_on_small.get("allowed", true)):
		_fail("M aircraft must not fit in an S-only hangar.")
		return
	if String(nimbus_on_small.get("blocking_size", "")) != "M":
		_fail("M aircraft should report the M-capacity bottleneck.")
		return

	var mixed_hangars: Array[Dictionary] = [
		{
			"capacity": 3,
			"max_aircraft_size": "S",
			"connected": true
		},
		{
			"capacity": 5,
			"max_aircraft_size": "M",
			"connected": true
		}
	]
	var mixed_status := FleetRules.capacity_status(
		mixed_hangars,
		two_picos,
		nimbus
	)
	if not bool(mixed_status.get("allowed", false)):
		_fail("A connected regional hangar should unlock M fleet capacity.")
		return

	var disconnected_regional: Array[Dictionary] = [
		{
			"capacity": 3,
			"max_aircraft_size": "S",
			"connected": true
		},
		{
			"capacity": 5,
			"max_aircraft_size": "M",
			"connected": false
		}
	]
	var disconnected_status := FleetRules.capacity_status(
		disconnected_regional,
		two_picos,
		nimbus
	)
	if bool(disconnected_status.get("allowed", true)):
		_fail("Disconnected hangars should not count toward fleet capacity.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var sources := grid.get_hangar_sources()
	if sources.size() != 1:
		_fail("Starter airport should include one physical hangar.")
		return
	if int(sources[0].get("capacity", 0)) != 3:
		_fail("Starter small hangar should expose three capacity slots.")
		return
	if not bool(sources[0].get("connected", false)):
		_fail("Starter small hangar should connect to the taxiway network.")
		return

	var s_infrastructure := grid.get_aircraft_infrastructure_status("S")
	if not bool(s_infrastructure.get("ready", false)):
		_fail("Starter airport should be operational for S aircraft.")
		return

	var m_infrastructure := grid.get_aircraft_infrastructure_status("M")
	if bool(m_infrastructure.get("ready", true)):
		_fail("Starter airport should not be ready for M aircraft.")
		return

	print("Fleet capacity and aircraft infrastructure tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
