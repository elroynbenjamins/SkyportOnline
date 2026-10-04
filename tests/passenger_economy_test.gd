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
		_fail("Starter airport should have bus stop and hotel passenger producers.")
		return
	if int(snapshot.get("passengers", 0)) != PassengerEconomy.STARTING_PASSENGERS:
		_fail("Passenger economy should use the configured starting balance.")
		return

	if not economy.try_spend_passengers(12):
		_fail("Starter balance should fund an S-class departure.")
		return
	if economy.passengers != PassengerEconomy.STARTING_PASSENGERS - 12:
		_fail("Departure should deduct passengers.")
		return

	economy.advance_time(240.0)
	snapshot = economy.get_snapshot()
	if int(snapshot.get("stored_waiting", 0)) < 8:
		_fail("Bus stop should produce an 8-passenger batch after four minutes.")
		return

	var collected := economy.collect_all()
	if collected < 8:
		_fail("Ready passenger batches should transfer into the terminal.")
		return

	var ad_total := 0
	for _index in range(PassengerEconomy.AD_DAILY_LIMIT):
		ad_total += economy.claim_rewarded_ad()
	if ad_total <= 0:
		_fail("Rewarded passenger boosts should grant passengers.")
		return
	if economy.claim_rewarded_ad() != 0:
		_fail("Rewarded passenger boosts should respect the daily limit.")
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
		_fail("Starter bus stop should be registered on the airport grid.")
		return

	economy.grant_country_resource("it_ceramic_tiles", 2)
	economy.grant_country_resource("ca_construction_lumber", 2)
	var quote := economy.get_upgrade_quote(bus_uid)
	if not bool(quote.get("can_afford", false)):
		_fail("Country resources should unlock passenger building upgrades.")
		return
	if not economy.try_upgrade_building(bus_uid):
		_fail("Passenger building upgrade should consume country resources.")
		return
	if int(economy.get_building_state(bus_uid).get("upgrade_level", 0)) != 2:
		_fail("Passenger building should reach upgrade level 2.")
		return

	print("PASS: passenger economy")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)
