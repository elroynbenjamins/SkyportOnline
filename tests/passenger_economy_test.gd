extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure_from_airport(grid)

	var snapshot := economy.get_snapshot()
	if int(snapshot.get("capacity", 0)) != 120:
		_fail("Starter terminal should store 120 passengers.")
		return
	if int(snapshot.get("producer_count", 0)) != 2:
		_fail("Starter airport should include bus stop and hotel producers.")
		return
	if int(snapshot.get("passengers", 0)) != PassengerEconomy.STARTING_PASSENGERS:
		_fail("Passenger economy should start with the configured balance.")
		return

	if not economy.try_spend_passengers(18):
		_fail("Starter passengers should fund an Aerolet 100 departure.")
		return
	if economy.passengers != PassengerEconomy.STARTING_PASSENGERS - 18:
		_fail("Departure should deduct the aircraft passenger requirement.")
		return

	economy.advance_time(240.0)
	snapshot = economy.get_snapshot()
	if int(snapshot.get("stored_waiting", 0)) < 8:
		_fail("Bus stop should produce eight passengers after four minutes.")
		return

	var collected := economy.collect_all()
	if collected < 8:
		_fail("Ready passengers should transfer into terminal storage.")
		return

	var ad_total := 0
	for _index in range(PassengerEconomy.AD_DAILY_LIMIT):
		ad_total += economy.claim_rewarded_ad()
	if ad_total <= 0:
		_fail("Rewarded passenger boosts should grant passengers.")
		return
	if economy.claim_rewarded_ad() != 0:
		_fail("Rewarded passenger boosts should stop at the daily limit.")
		return

	economy.try_spend_passengers(50)
	var friend_total := 0
	for index in range(20):
		friend_total += economy.claim_friend_gift("friend_%02d" % index)
	if friend_total > PassengerEconomy.FRIEND_RECEIVE_DAILY_CAP:
		_fail("Friend gifts should never exceed the daily receive cap.")
		return
	if economy.received_friend_passengers_today > PassengerEconomy.FRIEND_RECEIVE_DAILY_CAP:
		_fail("Friend receive tracking should remain capped.")
		return

	var bus_uid := -1
	for building in grid.get_placed_buildings():
		if String(building.get("definition_id", "")) == "bus_stop":
			bus_uid = int(building.get("uid", -1))
			break
	if bus_uid < 0:
		_fail("Starter bus stop should exist on the airport grid.")
		return

	economy.grant_country_resource("be_logistics_tags", 2)
	economy.grant_country_resource("gb_service_parts", 2)
	var quote := economy.get_upgrade_quote(bus_uid)
	if not bool(quote.get("can_afford", false)):
		_fail("Belgian and British route resources should unlock bus upgrade 2.")
		return
	if not economy.try_upgrade_building(bus_uid):
		_fail("Passenger building upgrade should consume country resources.")
		return
	var bus_state := economy.get_building_state(bus_uid)
	if int(bus_state.get("upgrade_level", 0)) != 2:
		_fail("Passenger building should reach upgrade level 2.")
		return
	if float(bus_state.get("rate_multiplier", 1.0)) <= 1.0:
		_fail("Passenger upgrade should improve production rate.")
		return

	for destination_id in ["brussels", "london", "frankfurt", "paris", "copenhagen"]:
		var resources := DestinationCatalog.resources_for_destination(destination_id)
		if resources.size() != 3:
			_fail("%s should expose exactly three country resources." % destination_id)
			return
		for resource in resources:
			if absf(float(resource.get("drop_chance", 0.0)) - 0.40) > 0.001:
				_fail("Each country resource should use a 40 percent drop chance.")
				return

	print("PASS: passenger economy")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)
