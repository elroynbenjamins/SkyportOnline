extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var autumn := EventCatalog.get_event("autumn_airbridge_2026")
	if autumn.is_empty():
		_fail("Autumn test event should remain in the catalog.")
		return
	if bool(autumn.get("enabled", true)):
		_fail("Autumn should be disabled for an unreleased game.")
		return

	var event := EventCatalog.get_event(
		"christmas_new_year_airbridge_2026"
	)
	if event.is_empty():
		_fail("Christmas/New Year launch event should exist.")
		return
	if bool(event.get("enabled", true)):
		_fail("Christmas/New Year event should stay disabled until launch date is firm.")
		return
	if String(event.get("currency_name", "")) != "Festive Vouchers":
		_fail("Launch event should use Festive Vouchers.")
		return
	if int(event.get("start_unix", 0)) != 1797552000:
		_fail("Provisional Christmas event start should be December 18, 2026 UTC.")
		return
	if int(event.get("featured_route_currency", -1)) != 0:
		_fail("Launch event currency should come from quests/alliance, not unlimited route farming.")
		return

	var quests: Array = event.get("quests", [])
	if quests.size() != 12:
		_fail("Christmas/New Year event should contain 12 quests.")
		return

	var week_counts := {1: 0, 2: 0, 3: 0}
	var personal_currency := 0
	for quest_variant in quests:
		var quest: Dictionary = quest_variant
		var week := int(quest.get("week", 0))
		if not week_counts.has(week):
			_fail("Every Christmas quest should use week 1, 2 or 3.")
			return
		week_counts[week] = int(week_counts[week]) + 1
		personal_currency += int(quest.get("currency_reward", 0))

	for week in [1, 2, 3]:
		if int(week_counts[week]) != 4:
			_fail("Each Christmas event week should contain exactly four quests.")
			return

	if personal_currency != 620:
		_fail("Christmas/New Year personal quest currency should total 620.")
		return

	var passenger_total := 0
	var cosmetic_count := 0
	for item_variant in event.get("shop", []):
		var item: Dictionary = item_variant
		match String(item.get("type", "")):
			"passengers":
				passenger_total += (
					int(item.get("passengers", 0))
					* int(item.get("purchase_limit", 1))
				)
			"cosmetic":
				cosmetic_count += 1

	if passenger_total != 150:
		_fail("Christmas event should cap shop passengers at 150.")
		return
	if cosmetic_count != 4:
		_fail("Christmas event should offer four personal cosmetics.")
		return

	var alliance: Dictionary = event.get("alliance", {})
	var milestones: Array = alliance.get("milestones", [])
	if milestones.size() != 4:
		_fail("Christmas Alliance event should have four milestones.")
		return

	var alliance_currency := 0
	var alliance_cosmetics := 0
	for milestone_variant in milestones:
		var milestone: Dictionary = milestone_variant
		if String(milestone.get("reward_type", "")) == "currency":
			alliance_currency += int(milestone.get("currency_reward", 0))
		elif String(milestone.get("reward_type", "")) == "cosmetic":
			alliance_cosmetics += 1

	if alliance_currency != 300:
		_fail("Christmas Alliance milestones should award 300 event currency.")
		return
	if alliance_cosmetics != 1:
		_fail("Christmas Alliance milestones should include one exclusive cosmetic.")
		return

	_check_route_access(
		"brussels",
		"pico_p8",
		1,
		"Week 1 Brussels"
	)
	_check_route_access(
		"london",
		"swift_s14",
		2,
		"Week 2 London"
	)
	_check_route_access(
		"berlin",
		"comet_c22",
		4,
		"Week 3 Berlin"
	)

	var start := int(event.get("start_unix", 0))
	var live_copy := event.duplicate(true)
	live_copy["enabled"] = true

	if not EventCatalog.is_active(
		live_copy,
		start + EventCatalog.SECONDS_PER_DAY
	):
		_fail("Christmas event should be active during its provisional launch window.")
		return
	if EventCatalog.current_week(
		live_copy,
		start + 8 * EventCatalog.SECONDS_PER_DAY
	) != 2:
		_fail("Day 9 should be Christmas event week 2.")
		return
	if EventCatalog.current_week(
		live_copy,
		start + 15 * EventCatalog.SECONDS_PER_DAY
	) != 3:
		_fail("Day 16 should be Christmas event week 3.")
		return
	if EventCatalog.is_active(
		live_copy,
		start + 21 * EventCatalog.SECONDS_PER_DAY
	):
		_fail("Christmas event should end after exactly 21 days.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Christmas Test",
		"XMS",
		"NL"
	)
	if profile.is_empty():
		_fail("Christmas event test profile should be created.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 0.0)

	var manager := EventManager.new()
	root.add_child(manager)
	manager.set_now_override(start + EventCatalog.SECONDS_PER_DAY)
	manager.configure(economy, live_copy)

	var snapshot := manager.get_snapshot()
	if not bool(snapshot.get("active", false)):
		_fail("Christmas event should configure successfully when explicitly enabled for testing.")
		return
	if String(snapshot.get("name", "")) != "Christmas & New Year Airbridge":
		_fail("Christmas event screen data should use the correct event name.")
		return
	if int(snapshot.get("featured_route_currency", -1)) != 0:
		_fail("Christmas featured routes should not grant repeatable currency.")
		return

	manager.record_destination_flight("brussels")
	if manager.get_currency() != 0:
		_fail("Featured Christmas routes should not create unlimited event currency.")
		return

	var screen := EventScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_event(manager.get_snapshot())
	if not screen.featured_routes_label.text.contains(
		"FEATURED QUEST ROUTES"
	):
		_fail("Christmas featured destinations should be presented as quest routes.")
		return
	if screen.featured_routes_label.text.contains("+0"):
		_fail("Event UI should never advertise a +0 currency route reward.")
		return

	_cleanup_profile()
	print(
		"Christmas/New Year launch event passed: disabled until release, "
		+ "21 days, new-player routes, 620 quest currency, 150 pax cap."
	)
	quit(0)


func _check_route_access(
	destination_id: String,
	aircraft_id: String,
	max_airport_level: int,
	label: String
) -> void:
	var destination := DestinationCatalog.get_destination(destination_id)
	var aircraft := AircraftCatalog.get_profile(aircraft_id)
	if destination.is_empty() or aircraft.is_empty():
		_fail("%s content is missing." % label)
		return
	if int(destination.get("unlock_level", 99)) > max_airport_level:
		_fail("%s destination unlock is too late." % label)
		return
	if int(aircraft.get("unlock_level", 99)) > max_airport_level:
		_fail("%s aircraft unlock is too late." % label)
		return
	if float(destination.get("distance_km", 999999.0)) > float(
		aircraft.get("range_km", 0.0)
	):
		_fail("%s is outside the intended aircraft range." % label)
		return


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
