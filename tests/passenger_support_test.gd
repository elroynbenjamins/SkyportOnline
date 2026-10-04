extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 30.0)

	if economy.get_capacity() != 40:
		_fail("Starter passenger capacity should be 40.")
		return

	var added := PassengerSupportRules.grant_rewarded_ad_passengers(
		economy
	)
	if added != 10:
		_fail(
			"Rewarded +25 boost should respect storage and add only 10."
		)
		return
	if economy.get_passengers() != 40:
		_fail("Rewarded boost should fill passenger storage to capacity.")
		return

	var shuttle := BuildingCatalog.get_definition("shuttle_station")
	if shuttle.is_empty():
		_fail("Shuttle Station should exist as a second passenger family.")
		return
	if not bool(shuttle.get("passenger_generator", false)):
		_fail("Shuttle Station should generate passengers.")
		return
	if Vector2i(shuttle.get("footprint", Vector2i.ZERO)) != Vector2i(3, 2):
		_fail("Shuttle Station should use a distinct 3x2 footprint.")
		return

	var shuttle_stats := PassengerUpgradeCatalog.passenger_stats(
		"shuttle_station",
		1
	)
	if absf(
		float(shuttle_stats.get("passengers_per_minute", 0.0)) - 2.8
	) > 0.001:
		_fail("Shuttle Station Lv1 should produce 2.8 passengers/min.")
		return
	if int(shuttle_stats.get("storage", 0)) != 30:
		_fail("Shuttle Station Lv1 should provide 30 storage.")
		return

	var unavailable_called := false
	var reward_called := false
	var bridge := RewardedPassengerAdBridge.new()
	root.add_child(bridge)
	bridge.unavailable.connect(
		func() -> void:
			unavailable_called = true
	)
	bridge.reward_granted.connect(
		func() -> void:
			reward_called = true
	)

	bridge.request_ad()
	if not unavailable_called:
		_fail("Missing ad provider should emit unavailable.")
		return
	if reward_called:
		_fail("Missing ad provider must never auto-grant passengers.")
		return

	unavailable_called = false
	bridge.set_provider_connected(true)
	bridge.request_ad()
	if reward_called:
		_fail("Requesting an ad must not grant reward before provider callback.")
		return

	bridge.complete_reward_from_provider()
	if not reward_called:
		_fail("Provider completion callback should grant the reward signal.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Gift Test",
		"GFT",
		"NL"
	)
	if profile.is_empty():
		_fail("Gift test profile should be created.")
		return

	var day_one := "2026-10-04"
	var status := ProfileStore.get_passenger_gift_status(day_one)
	if int(status.get("received", -1)) != 0:
		_fail("Fresh day should start with zero received gifts.")
		return
	if int(status.get("cap", 0)) != 3:
		_fail("Incoming friend gift cap should be three per day.")
		return

	for expected in range(1, 4):
		profile = ProfileStore.record_friend_passenger_gift(day_one)
		if profile.is_empty():
			_fail("First three daily friend gifts should be accepted.")
			return
		if int(
			profile.get("passenger_gifts_received_today", 0)
		) != expected:
			_fail("Friend gift ledger should increment once per gift.")
			return

	if not ProfileStore.record_friend_passenger_gift(day_one).is_empty():
		_fail("Fourth incoming friend gift on same day should be blocked.")
		return

	var next_day := ProfileStore.get_passenger_gift_status("2026-10-05")
	if int(next_day.get("received", -1)) != 0:
		_fail("Friend gift counter should reset on a new day.")
		return
	if not bool(next_day.get("can_receive", false)):
		_fail("New day should allow passenger gifts again.")
		return

	if PassengerSupportRules.friend_gift_amount() != 10:
		_fail("Friend passenger gift should currently be +10.")
		return
	if PassengerSupportRules.rewarded_ad_amount() != 25:
		_fail("Rewarded passenger ad should currently be +25.")
		return

	_cleanup_profile()
	print(
		"Passenger support passed: +25 capped boost, safe ad callback, "
		+ "Shuttle Station, and 3 daily +10 friend gifts."
	)
	quit(0)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
