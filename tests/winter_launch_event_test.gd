extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var autumn := EventCatalog.get_event("autumn_airbridge_2026")
	if autumn.is_empty():
		_fail("Autumn archive event should remain in the catalog.")
		return
	if bool(autumn.get("enabled", true)):
		_fail("Autumn should be disabled before public release.")
		return

	var event := EventCatalog.get_event(
		"christmas_new_year_airbridge_2026"
	)
	if event.is_empty():
		_fail("Winter launch event should exist.")
		return
	if bool(event.get("enabled", true)):
		_fail("Winter launch event must stay disabled until release timing is firm.")
		return
	if String(event.get("theme", "")) != "winter":
		_fail("Launch event should use the broader Winter theme.")
		return
	if String(event.get("currency_name", "")) != "Festive Vouchers":
		_fail("Winter launch event should use Festive Vouchers.")
		return
	if int(event.get("start_unix", 0)) != 1797552000:
		_fail("Provisional Winter event start should be December 18, 2026 UTC.")
		return
	if int(event.get("featured_route_currency", -1)) != 0:
		_fail("Winter featured routes should not provide repeatable voucher farming.")
		return
	if String(event.get("featured_marker_text", "")) != "WINTER":
		_fail("Winter featured flights should use the WINTER marker.")
		return

	var personal_currency := 0
	var week_counts := {1: 0, 2: 0, 3: 0}
	for quest_variant in event.get("quests", []):
		var quest: Dictionary = quest_variant
		var week := int(quest.get("week", 0))
		if not week_counts.has(week):
			_fail("Winter quests must use weeks 1-3.")
			return
		week_counts[week] = int(week_counts[week]) + 1
		personal_currency += int(quest.get("currency_reward", 0))

	if personal_currency != 620:
		_fail("Winter personal quest currency should total 620.")
		return
	for week in [1, 2, 3]:
		if int(week_counts[week]) != 4:
			_fail("Each Winter event week should contain exactly four quests.")
			return

	var passenger_total := 0
	var coin_total := 0
	var resource_choice_total := 0
	var cosmetic_count := 0
	var shop_cost := 0
	for item_variant in event.get("shop", []):
		var item: Dictionary = item_variant
		var limit := int(item.get("purchase_limit", 1))
		shop_cost += int(item.get("price", 0)) * limit
		match String(item.get("type", "")):
			"passengers":
				passenger_total += (
					int(item.get("passengers", 0)) * limit
				)
			"coins":
				coin_total += int(item.get("coins", 0)) * limit
			"resource_choice":
				resource_choice_total += (
					int(item.get("resource_amount", 1)) * limit
				)
			"cosmetic":
				cosmetic_count += 1

	if passenger_total != 250:
		_fail("Expanded Winter shop should cap event passengers at 250.")
		return
	if coin_total != 11000:
		_fail("Winter gold bundles should cap at 11,000 coins.")
		return
	if resource_choice_total != 3:
		_fail("Winter Supply Crates should grant at most three chosen resources.")
		return
	if cosmetic_count != 5:
		_fail("Winter shop should retain five personal cosmetics.")
		return
	if shop_cost != 1310:
		_fail("Expanded Winter shop stock should total 1,310 vouchers.")
		return

	var plus_50 := EventCatalog.shop_item_by_id(
		event,
		"winter_passengers_50"
	)
	if int(plus_50.get("purchase_limit", 0)) != 2:
		_fail("+50 passenger bundle should be purchasable exactly twice.")
		return

	var crate := EventCatalog.shop_item_by_id(
		event,
		"winter_supply_crate"
	)
	var allowed_codes: Array = crate.get("resource_country_codes", [])
	for required_code in ["NL", "BE", "DE", "GB", "FR", "DK"]:
		if not allowed_codes.has(required_code):
			_fail("Winter Supply Crate should include %s resources." % required_code)
			return
		if CountryResourceCatalog.resources_for_country(
			required_code
		).size() != 3:
			_fail("%s should expose three selectable resources." % required_code)
			return

	if not _route_accessible("brussels", "pico_p8", 1):
		_fail("Week 1 Brussels should be reachable by Pico P8.")
		return
	if not _route_accessible("london", "swift_s14", 2):
		_fail("Week 2 London should be reachable by Swift S14.")
		return
	if not _route_accessible("berlin", "comet_c22", 4):
		_fail("Week 3 Berlin should be reachable by Comet C22.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Winter Test",
		"WNT",
		"NL"
	)
	if profile.is_empty():
		_fail("Winter event test profile should be created.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 0.0)
	# The starter Travel Office stores 40, so provision a realistic upgraded
	# event-test capacity before validating the +50 passenger bundle.
	economy.capacity = 120
	economy.set_passengers(0)

	var live_copy := event.duplicate(true)
	live_copy["enabled"] = true
	var start := int(live_copy.get("start_unix", 0))

	var manager := EventManager.new()
	root.add_child(manager)
	manager.set_now_override(start + EventCatalog.SECONDS_PER_DAY)
	manager.configure(economy, live_copy)

	manager.state["currency"] = 500
	ProfileStore.save_event_state(
		"christmas_new_year_airbridge_2026",
		manager.state
	)

	var coin_rewards: Array[int] = []
	var resource_rewards: Array[Dictionary] = []
	manager.coins_granted.connect(
		func(amount: int) -> void:
			coin_rewards.append(amount)
	)
	manager.resource_granted.connect(
		func(resource_id: String, amount: int) -> void:
			resource_rewards.append({
				"id": resource_id,
				"amount": amount
			})
	)

	var coin_purchase := manager.purchase_shop_item(
		"winter_coins_2500"
	)
	if not bool(coin_purchase.get("success", false)):
		_fail("Winter Coin Pouch purchase should succeed.")
		return
	if coin_rewards != [2500]:
		_fail("Winter Coin Pouch should emit exactly +2,500 coins.")
		return

	var passenger_purchase := manager.purchase_shop_item(
		"winter_passengers_50"
	)
	if not bool(passenger_purchase.get("success", false)):
		_fail("First +50 passenger purchase should succeed.")
		return
	if economy.get_passengers() != 50:
		_fail("+50 passenger bundle should add exactly 50 passengers.")
		return

	var generic_crate := manager.purchase_shop_item(
		"winter_supply_crate"
	)
	if bool(generic_crate.get("success", false)):
		_fail("Supply crate must require a resource choice before spending vouchers.")
		return

	var before_choice := manager.get_currency()
	var invalid_choice := manager.purchase_resource_choice(
		"winter_supply_crate",
		"us_flight_computers"
	)
	if bool(invalid_choice.get("success", false)):
		_fail("Winter crate should reject resources outside allowed Winter countries.")
		return
	if manager.get_currency() != before_choice:
		_fail("Invalid resource choices must not spend vouchers.")
		return

	for chosen_resource in [
		"be_chocolate",
		"de_industrial_tools",
		"gb_specialty_goods"
	]:
		var purchase := manager.purchase_resource_choice(
			"winter_supply_crate",
			chosen_resource
		)
		if not bool(purchase.get("success", false)):
			_fail("Valid Winter resource choice should succeed: %s" % chosen_resource)
			return

	if resource_rewards.size() != 3:
		_fail("Three Winter crates should emit exactly three resource rewards.")
		return

	var fourth_crate := manager.purchase_resource_choice(
		"winter_supply_crate",
		"fr_cosmetics"
	)
	if bool(fourth_crate.get("success", false)):
		_fail("Fourth Winter Supply Crate purchase should be blocked.")
		return

	var stored := ProfileStore.get_event_state(
		"christmas_new_year_airbridge_2026"
	)
	var purchases: Dictionary = stored.get("shop_purchases", {})
	if int(purchases.get("winter_supply_crate", 0)) != 3:
		_fail("Winter crate purchase count should persist at three.")
		return

	var screen := EventScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_event(manager.get_snapshot())
	if not screen.featured_routes_label.text.contains(
		"FEATURED WINTER QUEST ROUTES"
	):
		_fail("Winter featured destinations should be presented as quest routes.")
		return
	if screen.featured_routes_label.text.contains("+0"):
		_fail("Winter UI should never advertise a +0 voucher route reward.")
		return

	screen._open_resource_choice(crate)
	if not screen.resource_choice_overlay.visible:
		_fail("Winter Supply Crate should open a resource-choice overlay.")
		return
	if screen.resource_choice_list.get_child_count() < 12:
		_fail("Resource selector should expose the configured country resources.")
		return

	_cleanup_profile()
	print(
		"Winter launch shop passed: 11k coins, 250 passengers, "
		+ "3 chosen resources, capped purchases and resource-choice UI."
	)
	quit(0)


func _route_accessible(
	destination_id: String,
	aircraft_id: String,
	max_level: int
) -> bool:
	var destination := DestinationCatalog.get_destination(destination_id)
	var aircraft := AircraftCatalog.get_profile(aircraft_id)
	if destination.is_empty() or aircraft.is_empty():
		return false
	if int(destination.get("unlock_level", 999)) > max_level:
		return false
	if int(aircraft.get("unlock_level", 999)) > max_level:
		return false
	return float(destination.get("distance_km", 999999.0)) <= float(
		aircraft.get("range_km", 0.0)
	)


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
