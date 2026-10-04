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

	if economy.get_capacity() != 160:
		_fail("Starter terminal + Travel Office should provide 160 capacity.")
		return

	var added := PassengerSupportRules.grant_rewarded_ad_passengers(
		economy
	)
	if added != 25:
		_fail("Rewarded passenger boost should add 25 when storage allows it.")
		return
	if economy.get_passengers() != 55:
		_fail("Rewarded boost should increase passenger balance by 25.")
		return

	var shuttle := BuildingCatalog.get_definition("shuttle_station")
	if shuttle.is_empty():
		_fail("Shuttle Station should exist as a second passenger family.")
		return
	if not bool(shuttle.get("passenger_generator", false)):
		_fail("Shuttle Station should generate passengers.")
		return
	if String(shuttle.get("passenger_generator_mode", "")) != "passive":
		_fail("Shuttle Station should be marked as passive generation.")
		return

	var terminal := BuildingCatalog.get_definition("small_terminal")
	if not bool(terminal.get("passenger_capacity_provider", false)):
		_fail("Small Terminal should provide passenger storage capacity.")
		return
	if not bool(terminal.get("passenger_upgradable", false)):
		_fail("Small Terminal should support non-visual upgrades.")
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
		"Support Test",
		"SUP",
		"NL"
	)
	if profile.is_empty():
		_fail("Passenger support test profile should be created.")
		return

	if PassengerSupportRules.rewarded_ad_amount() != 25:
		_fail("Rewarded passenger ad should grant +25.")
		return
	if PassengerSupportRules.rewarded_ad_daily_cap() != 3:
		_fail("Rewarded passenger ads should be capped at three per day.")
		return
	if PassengerSupportRules.friend_gift_amount() != 5:
		_fail("Friend passenger gifts should grant +5.")
		return
	if PassengerSupportRules.friend_gift_daily_cap() != 10:
		_fail("Players should be able to receive ten friend gifts per day.")
		return
	if PassengerSupportRules.max_daily_friend_passengers() != 50:
		_fail("Friend gifts should contribute at most 50 passengers/day.")
		return

	var day_one := "2026-10-04"
	var ad_status := ProfileStore.get_passenger_ad_status(day_one)
	if int(ad_status.get("remaining", -1)) != 3:
		_fail("Fresh day should start with three rewarded passenger ads.")
		return

	for expected in range(1, 4):
		profile = ProfileStore.record_rewarded_passenger_ad(day_one)
		if profile.is_empty():
			_fail("First three rewarded passenger ads should be accepted.")
			return
		if int(profile.get("passenger_ads_claimed_today", 0)) != expected:
			_fail("Rewarded passenger ad ledger should increment once per ad.")
			return

	if not ProfileStore.record_rewarded_passenger_ad(day_one).is_empty():
		_fail("Fourth rewarded passenger ad on the same day should be blocked.")
		return

	ad_status = ProfileStore.get_passenger_ad_status(day_one)
	if bool(ad_status.get("can_claim", true)):
		_fail("Rewarded passenger ad status should show the daily cap reached.")
		return

	var gift_status := ProfileStore.get_passenger_gift_status(day_one)
	if int(gift_status.get("received", -1)) != 0:
		_fail("Fresh day should start with zero received friend gifts.")
		return
	if int(gift_status.get("cap", 0)) != 10:
		_fail("Incoming friend gift cap should be ten per day.")
		return

	for expected in range(1, 11):
		profile = ProfileStore.record_friend_passenger_gift(day_one)
		if profile.is_empty():
			_fail("First ten daily friend gifts should be accepted.")
			return
		if int(
			profile.get("passenger_gifts_received_today", 0)
		) != expected:
			_fail("Friend gift ledger should increment once per gift.")
			return

	if not ProfileStore.record_friend_passenger_gift(day_one).is_empty():
		_fail("Eleventh incoming friend gift on same day should be blocked.")
		return

	gift_status = ProfileStore.get_passenger_gift_status(day_one)
	if int(gift_status.get("passengers_received", -1)) != 50:
		_fail("Ten friend gifts should equal 50 received passengers.")
		return
	if int(gift_status.get("max_passengers", -1)) != 50:
		_fail("Gift status should expose the 50 passenger daily ceiling.")
		return

	var next_day_ad := ProfileStore.get_passenger_ad_status("2026-10-05")
	if int(next_day_ad.get("claimed", -1)) != 0:
		_fail("Rewarded passenger ad counter should reset on a new day.")
		return
	if not bool(next_day_ad.get("can_claim", false)):
		_fail("New day should allow rewarded passenger ads again.")
		return

	var next_day_gifts := ProfileStore.get_passenger_gift_status("2026-10-05")
	if int(next_day_gifts.get("received", -1)) != 0:
		_fail("Friend gift counter should reset on a new day.")
		return
	if not bool(next_day_gifts.get("can_receive", false)):
		_fail("New day should allow passenger gifts again.")
		return

	_cleanup_profile()
	print(
		"Passenger support passed: passive supply, +25 ads (3/day), "
		+ "and +5 friend gifts (10/day, 50 passengers)."
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
