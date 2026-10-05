extends SceneTree

var errors: Array[String] = []
var action_reward := ""
var action_unavailable := ""

const OCT_05 := 1791201600.0
const OCT_12 := 1791806400.0
const NOV_01 := 1793534400.0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _run() -> void:
	var state := AirportProgressionRules.new_state("mission-pass-test", 1)
	check(int(state.get("aero_tokens", -1)) == 0, "New airports should start with zero Aero Tokens.")
	check(MissionPassRules.ensure_state(state, OCT_05, 1), "First mission setup should initialize state.")
	var pass_state: Dictionary = state.get("mission_pass", {})
	check((pass_state.get("daily", []) as Array).size() == 4, "Exactly four daily missions should be active.")
	check((pass_state.get("weekly", []) as Array).size() == 5, "Exactly five weekly missions should be created for the current week.")
	check(int(pass_state.get("points", -1)) == 0, "Fresh monthly pass should start at zero points.")


	check(MissionPassRules.seconds_until_daily_reset(OCT_05) == 43200, "Daily mission reset should be the next UTC midnight.")
	check(MissionPassRules.seconds_until_next_week_set(OCT_05) == 216000, "October 5 should receive the next weekly set at October 8 UTC.")
	check(MissionPassRules.seconds_until_month_reset(OCT_05) == 2289600, "October pass should end at November 1 UTC.")
	check(MissionPassRules.format_remaining(216000) == "2d 12h", "Countdown formatting should stay compact for landscape UI.")

	var daily: Array = pass_state.get("daily", [])
	var original_first := String((daily[0] as Dictionary).get("template_id", ""))
	var first_id := String((daily[0] as Dictionary).get("id", ""))
	check(MissionPassRules.reroll_daily(state, first_id, false, OCT_05, 1), "One free daily reroll should succeed.")
	pass_state = state.get("mission_pass", {})
	daily = pass_state.get("daily", [])
	check(bool(pass_state.get("free_reroll_used", false)), "Free reroll should be marked used.")
	check(String((daily[0] as Dictionary).get("template_id", "")) != original_first, "Free reroll should replace the selected mission.")
	check(not MissionPassRules.reroll_daily(state, String((daily[0] as Dictionary).get("id", "")), false, OCT_05, 1), "A second free reroll should be blocked.")

	var second_id := String((daily[1] as Dictionary).get("id", ""))
	check(MissionPassRules.reroll_daily(state, second_id, true, OCT_05, 1), "One rewarded-ad reroll should succeed.")
	pass_state = state.get("mission_pass", {})
	check(bool(pass_state.get("ad_reroll_used", false)), "Ad reroll should be marked used.")
	check(not MissionPassRules.reroll_daily(state, String(((pass_state.get("daily", []) as Array)[1] as Dictionary).get("id", "")), true, OCT_05, 1), "A second ad reroll should be blocked.")

	for index in range(30):
		MissionPassRules.record_event(state, "flight", {
			"passengers": 1000,
			"coins": 10000,
			"xp": 1000,
			"flight_minutes": 1000,
			"distance_km": 10000,
			"mastery_minutes": 1000,
			"resources": 10,
			"country": "C%02d" % index
		}, OCT_05, 1)
	MissionPassRules.record_event(state, "passive_passengers", {"amount": 1000}, OCT_05, 1)
	MissionPassRules.record_event(state, "npc_service", {"coins": 1000, "xp": 1000}, OCT_05, 1)
	pass_state = state.get("mission_pass", {})
	check(MissionPassRules.completed_daily_count(state) == 4, "All four daily missions should complete from matching gameplay events.")
	check(int(pass_state.get("points", 0)) >= 570, "A completed daily set and weekly set should award at least 570 pass points.")
	check(bool(pass_state.get("daily_bonus_awarded", false)), "Daily completion bonus should award automatically.")
	var weekly_bonus: Dictionary = pass_state.get("weekly_bonus_awarded", {})
	check(weekly_bonus.values().has(true), "Weekly completion bonus should award automatically.")


	var variety_state := AirportProgressionRules.new_state("mission-variety-test", 2)
	MissionPassRules.ensure_state(variety_state, OCT_05, 2)
	var variety_pass: Dictionary = variety_state.get("mission_pass", {})
	variety_pass["daily"] = [
		{"id": "variety-airtime", "metric": "flight_minutes", "target": 12, "progress": 0, "completed": false, "awarded": false},
		{"id": "variety-distance", "metric": "flight_distance", "target": 800, "progress": 0, "completed": false, "awarded": false},
		{"id": "variety-mastery", "metric": "mastery_minutes", "target": 120, "progress": 0, "completed": false, "awarded": false},
		{"id": "variety-resources", "metric": "resources", "target": 2, "progress": 0, "completed": false, "awarded": false}
	]
	variety_pass["daily_bonus_awarded"] = false
	variety_state["mission_pass"] = variety_pass
	MissionPassRules.record_event(variety_state, "flight", {
		"flight_minutes": 15,
		"distance_km": 900,
		"mastery_minutes": 150,
		"resources": 2,
		"country": "BE"
	}, OCT_05, 2)
	check(MissionPassRules.completed_daily_count(variety_state) == 4, "Flight telemetry should advance airtime, distance, mastery and resource missions.")
	check(bool((variety_state.get("mission_pass", {}) as Dictionary).get("daily_bonus_awarded", false)), "Variety missions should still trigger the daily completion bonus.")
	check(MissionPassCatalog.daily_templates().size() >= 10, "Daily mission catalog should include the expanded variety set.")
	check(MissionPassCatalog.weekly_templates().size() >= 11, "Weekly mission catalog should include the expanded variety set.")

	var claimed_free := MissionPassRules.claim_pass_reward(state, 1, "free")
	check(not claimed_free.is_empty(), "Unlocked free tier should be claimable.")
	check(int(claimed_free.get("pending_passengers", 0)) == int(state.get("pending_passengers", 0)) + 25, "Tier 1 free reward should reserve 25 passengers.")
	check(MissionPassRules.claim_pass_reward(claimed_free, 1, "free").is_empty(), "The same free tier must not be claimable twice.")

	var premium_state := MissionPassRules.grant_verified_product(claimed_free, "airport_pass")
	check(bool((premium_state.get("mission_pass", {}) as Dictionary).get("premium", false)), "Verified Airport Pass purchase should activate premium for the month.")
	var claimed_premium := MissionPassRules.claim_pass_reward(premium_state, 1, "premium")
	check(int(claimed_premium.get("pending_passengers", 0)) == int(premium_state.get("pending_passengers", 0)) + 50, "Tier 1 premium reward should reserve 50 passengers.")

	var token_state := MissionPassRules.grant_verified_product(claimed_premium, "aero_large")
	check(int(token_state.get("aero_tokens", 0)) == int(claimed_premium.get("aero_tokens", 0)) + 800, "Largest verified pack should grant 800 Aero Tokens.")
	check(int(token_state.get("gems", -1)) == int(token_state.get("aero_tokens", 0)), "Legacy gems field should mirror Aero Tokens for compatibility.")
	var max_price := 0.0
	for product in MissionPassCatalog.product_catalog():
		max_price = maxf(max_price, float(product.get("price_eur", 0.0)))
	check(is_equal_approx(max_price, 9.99), "Store catalog must cap purchases at €9.99.")
	check(String(MissionPassCatalog.product("airport_pass").get("price_label", "")) == "€4.99", "Monthly Airport Pass should cost €4.99.")

	MissionPassRules.ensure_state(token_state, OCT_12, 1)
	pass_state = token_state.get("mission_pass", {})
	check((pass_state.get("weekly", []) as Array).size() == 10, "A new week in the same month should append five missions instead of deleting unfinished catch-up missions.")

	var pending_before_rollover := int(token_state.get("pending_passengers", 0))
	MissionPassRules.ensure_state(token_state, NOV_01, 1)
	pass_state = token_state.get("mission_pass", {})
	check(int(token_state.get("pending_passengers", 0)) > pending_before_rollover, "Earned but unclaimed pass rewards should auto-claim before the month resets.")
	check(int(pass_state.get("points", -1)) == 0, "New calendar month should start a fresh pass point total.")
	check(not bool(pass_state.get("premium", true)), "Premium entitlement should reset for the new monthly pass.")
	check((pass_state.get("weekly", []) as Array).size() == 5, "New month should start with only the current weekly set.")
	check((pass_state.get("daily", []) as Array).size() == 4, "New month should still create four daily missions.")

	check(MissionPassRules.aero_tokens_for_level_range(1, 5) == 6, "Levels 2-5 should grant four normal Aero tokens plus the +2 level-5 bonus.")
	check(MissionPassRules.aero_tokens_for_level_range(4, 5) == 3, "Every fifth level should grant 1 normal + 2 bonus Aero Tokens.")
	check(MissionPassRules.aero_tokens_for_level_range(5, 5) == 0, "No level gain should grant no Aero Tokens.")


	var crate_state := AirportProgressionRules.new_state("crate-rules-test", 2)
	crate_state["resource_choice_crates"] = 2
	MissionPassRules.ensure_state(crate_state, OCT_05, 2)
	var reserved := MissionPassRules.reserve_resource_choice(crate_state, "be_chocolate", 1)
	check(not reserved.is_empty(), "An owned Country Resource Crate should reserve a valid resource choice.")
	check(int(reserved.get("resource_choice_crates", -1)) == 1, "Reserving a resource should consume exactly one crate.")
	check((reserved.get("pending_resource_grants", []) as Array).size() == 1, "Reserved crate reward should stay pending until profile delivery is confirmed.")
	check(MissionPassRules.reserve_resource_choice(crate_state, "missing_resource", 1).is_empty(), "Unknown resources must not consume a crate.")
	var grant_id := String(((reserved.get("pending_resource_grants", []) as Array)[0] as Dictionary).get("id", ""))
	var completed_grant := MissionPassRules.complete_resource_grant(reserved, grant_id)
	check(not completed_grant.is_empty() and (completed_grant.get("pending_resource_grants", []) as Array).is_empty(), "Confirmed resource reward should clear its pending grant.")

	_cleanup_profile()
	var crate_profile := ProfileStore.create_guest_airport("Crate Test", "CRT", "NL")
	check(not crate_profile.is_empty(), "Resource receipt test profile should be created.")
	var first_receipt := ProfileStore.apply_resource_reward_receipt("receipt-1", "be_chocolate", 1)
	check(int((first_receipt.get("resource_inventory", {}) as Dictionary).get("be_chocolate", 0)) == 1, "First resource receipt should add the selected country resource.")
	var repeated_receipt := ProfileStore.apply_resource_reward_receipt("receipt-1", "be_chocolate", 1)
	check(int((repeated_receipt.get("resource_inventory", {}) as Dictionary).get("be_chocolate", 0)) == 1, "Replaying the same resource receipt must not duplicate the reward.")
	check(ProfileStore.apply_resource_reward_receipt("receipt-invalid", "missing_resource", 1).is_empty(), "Invalid resources must not create reward receipts.")
	_cleanup_profile()

	var booster_state := AirportProgressionRules.new_state("booster-test", 1)
	booster_state["booster_inventory"] = {"booster_tailwind": 2, "booster_gold": 1}
	check(MissionBoosterRules.activate(booster_state, "booster_tailwind", OCT_05), "Owned Tailwind booster should activate.")
	check(int((booster_state.get("booster_inventory", {}) as Dictionary).get("booster_tailwind", -1)) == 1, "Activating a booster should consume exactly one copy.")
	check(MissionBoosterRules.remaining_seconds(booster_state, "booster_tailwind", OCT_05) == 7200, "First booster copy should grant exactly two hours.")
	check(MissionBoosterRules.activate(booster_state, "booster_tailwind", OCT_05 + 60.0), "Second Tailwind copy should extend the active timer.")
	check(MissionBoosterRules.remaining_seconds(booster_state, "booster_tailwind", OCT_05 + 60.0) == 14340, "Using another active booster should add two hours to remaining duration.")
	var active_boosts := MissionBoosterRules.active_profile(booster_state, OCT_05 + 60.0)
	check(is_equal_approx(float(active_boosts.get("flight_duration", 1.0)), 0.90), "Tailwind should apply a 10% travel-time reduction.")
	check(is_equal_approx(float(active_boosts.get("flight_gold", 1.0)), 1.0), "Unactivated Gold booster should not affect flight rewards.")
	active_boosts = MissionBoosterRules.active_profile(booster_state, OCT_05 + 15000.0)
	check(is_equal_approx(float(active_boosts.get("flight_duration", 0.0)), 1.0), "Expired boosters should automatically stop affecting gameplay.")

	var bridge := RewardedPassengerAdBridge.new()
	root.add_child(bridge)
	bridge.action_reward_granted.connect(_on_action_reward)
	bridge.action_unavailable.connect(_on_action_unavailable)
	bridge.request_ad_for("mission_reroll")
	check(action_unavailable == "mission_reroll", "Mission reroll should report unavailable when no rewarded-ad provider is connected.")
	bridge.set_provider_connected(true)
	bridge.request_ad_for("mission_reroll")
	check(action_reward.is_empty(), "Requesting a rewarded ad must not grant the reroll before provider completion.")
	bridge.complete_reward_from_provider()
	check(action_reward == "mission_reroll", "Provider completion should return the mission reroll action id.")

	var screen := MissionPassScreen.new()
	root.add_child(screen)
	token_state["resource_choice_crates"] = 1
	screen.open_screen({
		"state": token_state,
		"level": 1,
		"week_key": String((((pass_state.get("weekly", []) as Array)[0] as Dictionary).get("period_key", ""))),
		"rewarded_ad_connected": true,
		"resource_inventory": {"be_chocolate": 2},
		"resource_choice_country_codes": ["BE"]
	})
	await process_frame
	check(screen.is_open(), "Mission/pass screen should open with a valid snapshot.")
	for tab in ["Daily", "Weekly", "Airport Pass", "Aero Tokens"]:
		screen.open_tab(tab)
		await process_frame
		check(screen.body.get_child_count() > 0, "Mission/pass tab should render content: " + tab)
	screen.open_tab("Airport Pass")
	screen._open_resource_choice()
	await process_frame
	check(screen.resource_choice_overlay.visible, "Owned pass crate should open the resource selector overlay.")
	check(screen.resource_choice_list.get_child_count() >= 4, "Unlocked country should show its heading and three selectable resources.")
	screen._close_resource_choice()

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("MISSION_PASS_TEST_OK: daily, weekly catch-up, varied flight telemetry, monthly pass, Aero wallet, rerolls, products and UI")
	quit(0)

func _cleanup_profile() -> void:
	if FileAccess.file_exists(ProfileStore.SAVE_PATH):
		DirAccess.remove_absolute(ProfileStore.SAVE_PATH)

func _on_action_reward(action_id: String) -> void:
	action_reward = action_id

func _on_action_unavailable(action_id: String) -> void:
	action_unavailable = action_id
