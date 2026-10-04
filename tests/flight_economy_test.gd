extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var aircraft := AircraftCatalog.all()
	if aircraft.size() != 9:
		_fail("V1 catalog should contain exactly 9 S/M aircraft.")
		return

	for definition in aircraft:
		var size_class := String(definition.get("size_class", ""))
		if size_class not in ["S", "M"]:
			_fail("V1 aircraft catalog must only expose S and M classes.")
			return

	var routes := RouteCatalog.all()
	if routes.size() != 9:
		_fail("Pass 7 should expose nine prototype route tiers.")
		return

	var pico := AircraftCatalog.get_definition("pico_p8")
	var swift := AircraftCatalog.get_definition("swift_s14")
	var nimbus := AircraftCatalog.get_definition("nimbus_n40")
	var horizon := AircraftCatalog.get_definition("horizon_h88")

	var local_route := RouteCatalog.get_definition("northsea_shuttle")
	if not FlightEconomy.is_route_compatible(pico, local_route, 1):
		_fail("Pico P8 should be able to fly the starter local route.")
		return
	if FlightEconomy.is_route_compatible(nimbus, local_route, 20):
		_fail("M aircraft should be blocked from S-only local routes.")
		return

	var channel_route := RouteCatalog.get_definition("channel_hop")
	if FlightEconomy.is_route_compatible(pico, channel_route, 4):
		_fail("Pico P8 should fail routes beyond its 320 km range.")
		return
	if not FlightEconomy.is_route_compatible(swift, channel_route, 4):
		_fail("Swift S14 should exactly reach the 430 km Channel Hop.")
		return

	var regional_route := RouteCatalog.get_definition("nordic_connector")
	var nimbus_manifest := FlightEconomy.calculate_manifest(
		nimbus,
		regional_route,
		17
	)
	var horizon_manifest := FlightEconomy.calculate_manifest(
		horizon,
		regional_route,
		17
	)
	if nimbus_manifest.is_empty() or horizon_manifest.is_empty():
		_fail("Both M aircraft should be technically compatible with Nordic Connector.")
		return
	if int(nimbus_manifest.get("net_profit", 0)) <= int(
		horizon_manifest.get("net_profit", 0)
	):
		_fail("Oversized Horizon should earn less than Nimbus on lower-demand regional routes.")
		return

	var long_route := RouteCatalog.get_definition("mediterranean_reach")
	if not FlightEconomy.is_route_compatible(horizon, long_route, 17):
		_fail("Horizon H88 should unlock the longest V1 regional route.")
		return
	if FlightEconomy.is_route_compatible(nimbus, long_route, 17):
		_fail("Nimbus N40 should not have enough range for the longest V1 route.")
		return

	var long_manifest := FlightEconomy.calculate_manifest(horizon, long_route, 17)
	if int(long_manifest.get("passengers", 0)) != 88:
		_fail("Passenger load should never exceed aircraft capacity.")
		return
	if int(long_manifest.get("net_profit", 0)) <= 0:
		_fail("A correctly matched flagship route should remain profitable.")
		return
	if float(long_manifest.get("resource_drop_chance", 0.0)) != 0.40:
		_fail("Country-resource bridge should retain the accepted 40% roll chance.")
		return

	var progression := LevelProgression.add_xp(4, 350, 20)
	if int(progression.get("level", 0)) != 5:
		_fail("XP overflow should advance airport level.")
		return
	if int(progression.get("xp", -1)) != 10:
		_fail("XP overflow should carry into the next airport level.")
		return
	if int(progression.get("xp_to_next", 0)) != 500:
		_fail("Level 5 should expose its next XP threshold.")
		return

	print("Flight economy, S/M catalog, and level progression tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
