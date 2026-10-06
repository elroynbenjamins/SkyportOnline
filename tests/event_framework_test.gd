extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Event Test",
		"EVT",
		"NL"
	)
	if profile.is_empty():
		_fail("Event test profile should be created.")
		return

	var template := EventCatalog.get_event(
		"sky_lantern_festival_2026"
	)
	if template.is_empty():
		_fail("Reusable sample event should exist.")
		return
	if bool(template.get("enabled", true)):
		_fail("Sample event should ship disabled by default.")
		return

	var start := 1000000
	template["enabled"] = true
	template["start_unix"] = start

	if not EventCatalog.is_active(
		template,
		start + EventCatalog.SECONDS_PER_DAY
	):
		_fail("Enabled event should be active during its 21-day window.")
		return
	if EventCatalog.is_active(
		template,
		start
		+ EventCatalog.EVENT_DURATION_DAYS
		* EventCatalog.SECONDS_PER_DAY
	):
		_fail("Event should end exactly after 21 days.")
		return
	if EventCatalog.current_week(
		template,
		start + EventCatalog.SECONDS_PER_DAY
	) != 1:
		_fail("Days 1-7 should be event week 1.")
		return
	if EventCatalog.current_week(
		template,
		start + 8 * EventCatalog.SECONDS_PER_DAY
	) != 2:
		_fail("Days 8-14 should be event week 2.")
		return
	if EventCatalog.current_week(
		template,
		start + 15 * EventCatalog.SECONDS_PER_DAY
	) != 3:
		_fail("Days 15-21 should be event week 3.")
		return

	var winter := EventCatalog.get_event(
		"christmas_new_year_airbridge_2026"
	)
	var winter_phase_1 := EventCatalog.phase_for_week(winter, 1)
	var winter_phase_2 := EventCatalog.phase_for_week(winter, 2)
	var winter_phase_3 := EventCatalog.phase_for_week(winter, 3)
	if String(winter_phase_1.get("name", "")) != "Christmas Rush":
		_fail("Winter event week 1 should use the Christmas Rush phase.")
		return
	if String(winter_phase_2.get("name", "")) != "Holiday Network":
		_fail("Winter event week 2 should use the Holiday Network phase.")
		return
	if String(winter_phase_3.get("name", "")) != "New Year Finale":
		_fail("Winter event week 3 should use the New Year Finale phase.")
		return
	if (
		(winter_phase_1.get("featured_destinations", []) as Array)
		!= ["brussels"]
		or (winter_phase_2.get("featured_destinations", []) as Array)
		!= ["london"]
		or (winter_phase_3.get("featured_destinations", []) as Array)
		!= ["berlin"]
	):
		_fail("Each Winter phase should focus its own featured route.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 0.0)
	if economy.get_capacity() < 25:
		_fail("Starter passenger storage should support event passenger packs.")
		return

	var manager := EventManager.new()
	root.add_child(manager)
	manager.set_now_override(
		start + EventCatalog.SECONDS_PER_DAY
	)
	manager.configure(economy, template)

	var snapshot := manager.get_snapshot()
	if not bool(snapshot.get("active", false)):
		_fail("Overridden enabled event should be active.")
		return
	if int(snapshot.get("week", 0)) != 1:
		_fail("Event manager should expose current event week.")
		return
	if String(snapshot.get("phase_name", "")) != "Lantern Opening":
		_fail("Week 1 should expose the themed opening phase.")
		return
	if int(snapshot.get("phase_quest_total", 0)) != 4:
		_fail("Opening phase should expose four current quests.")
		return
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		var quest_week := int(quest.get("week", 0))
		var phase_state := String(quest.get("phase_state", ""))
		if quest_week == 1 and phase_state != "current":
			_fail("Week 1 quests should be marked as current phase.")
			return
		if quest_week > 1 and phase_state != "upcoming":
			_fail("Future event quests should be marked upcoming.")
			return

	_complete_current_week(manager, 1)
	if manager.get_currency() != 160:
		_fail("Week 1 should award 160 event currency.")
		return

	snapshot = manager.get_snapshot()
	if int(snapshot.get("alliance_personal", 0)) != 40:
		_fail("Week 1 quest claims should contribute 40 alliance points.")
		return

	manager.set_now_override(
		start + 8 * EventCatalog.SECONDS_PER_DAY
	)
	snapshot = manager.get_snapshot()
	if String(snapshot.get("phase_name", "")) != "Festival Network":
		_fail("Week 2 should change the active phase to Festival Network.")
		return
	if String(snapshot.get("next_phase_name", "")) != "Lantern Finale":
		_fail("Week 2 should preview the Finale phase.")
		return
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		var quest_week := int(quest.get("week", 0))
		var phase_state := String(quest.get("phase_state", ""))
		if quest_week == 1 and phase_state != "archive":
			_fail("Earlier event quests should move into the phase archive.")
			return
		if quest_week == 2 and phase_state != "current":
			_fail("Week 2 quests should become the current phase.")
			return
	_complete_current_week(manager, 2)
	if manager.get_currency() != 360:
		_fail("Weeks 1-2 should award 360 event currency.")
		return

	manager.set_now_override(
		start + 15 * EventCatalog.SECONDS_PER_DAY
	)
	snapshot = manager.get_snapshot()
	if String(snapshot.get("phase_name", "")) != "Lantern Finale":
		_fail("Week 3 should expose the Lantern Finale phase.")
		return
	if not String(snapshot.get("next_phase_name", "")).is_empty():
		_fail("Final event phase should not advertise a fourth phase.")
		return
	_complete_current_week(manager, 3)
	if manager.get_currency() != 600:
		_fail("All 12 personal quests should award 600 event currency.")
		return

	snapshot = manager.get_snapshot()
	if int(snapshot.get("alliance_personal", 0)) != 180:
		_fail("Full personal event should contribute 180 alliance points.")
		return
	if int(snapshot.get("phase_quest_complete", 0)) != 4:
		_fail("Final phase should report all four finale quests complete.")
		return

	var screen := EventScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_event(snapshot)
	if not screen.is_open():
		_fail("Event screen should open with the phased snapshot.")
		return
	if not screen.phase_label.text.contains("LANTERN FINALE"):
		_fail("Event screen should prominently show the current phase.")
		return
	if not screen.phase_progress_label.text.contains("4 / 4"):
		_fail("Event screen should show current phase quest completion.")
		return
	screen.close_event()

	# Featured route bonuses follow the active phase instead of all three
	# event destinations paying the bonus for the full 21-day event.
	var route_event := winter.duplicate(true)
	route_event["id"] = "phase-route-bonus-test"
	route_event["enabled"] = true
	route_event["start_unix"] = start
	route_event["featured_route_currency"] = 5
	var route_manager := EventManager.new()
	root.add_child(route_manager)
	route_manager.set_now_override(
		start + EventCatalog.SECONDS_PER_DAY
	)
	route_manager.configure(economy, route_event)
	route_manager.record_destination_flight("london")
	if route_manager.get_currency() != 0:
		_fail("Week 1 should not award the featured-route bonus for the Week 2 route.")
		return
	route_manager.record_destination_flight("brussels")
	if route_manager.get_currency() != 5:
		_fail("Week 1 should award the featured-route bonus for Brussels.")
		return
	route_manager.set_now_override(
		start + 8 * EventCatalog.SECONDS_PER_DAY
	)
	route_manager.record_destination_flight("brussels")
	if route_manager.get_currency() != 5:
		_fail("Brussels should stop paying the featured-route bonus after Phase 1.")
		return
	route_manager.record_destination_flight("london")
	if route_manager.get_currency() != 10:
		_fail("London should become the featured bonus route in Phase 2.")
		return

	economy.set_passengers(0)
	var passenger_purchase := manager.purchase_shop_item(
		"passengers_25"
	)
	if not bool(passenger_purchase.get("success", false)):
		_fail("First +25 passenger event purchase should succeed.")
		return
	if economy.get_passengers() != 25:
		_fail("Event passenger pack should add exactly 25 passengers.")
		return
	if manager.get_currency() != 575:
		_fail("+25 passenger pack should cost 25 event currency.")
		return

	var blocked_purchase := manager.purchase_shop_item(
		"passengers_25"
	)
	if bool(blocked_purchase.get("success", false)):
		_fail("Passenger purchase should block when storage lacks 25 free spaces.")
		return

	var cosmetic_purchase := manager.purchase_shop_item(
		"lantern_airport_border"
	)
	if not bool(cosmetic_purchase.get("success", false)):
		_fail("Event cosmetic purchase should succeed.")
		return
	if not ProfileStore.owns_cosmetic(
		"event_lantern_airport_border"
	):
		_fail("Purchased event cosmetic should persist on the profile.")
		return

	manager.set_alliance_total_from_server(1400)
	var alliance_reward := manager.claim_alliance_milestone(
		"alliance_150"
	)
	if not bool(alliance_reward.get("success", false)):
		_fail("Reached alliance milestone should be claimable.")
		return
	if manager.get_currency() != 475:
		_fail(
			"After 25 pax + 150 cosmetic + 50 alliance reward, currency should be 475."
		)
		return

	var stored_state := ProfileStore.get_event_state(
		"sky_lantern_festival_2026"
	)
	if int(stored_state.get("currency", -1)) != 475:
		_fail("Event currency should persist in the profile.")
		return
	if int(stored_state.get("alliance_total", 0)) != 1400:
		_fail("Cached alliance event total should persist.")
		return

	_cleanup_profile()
	print(
		"Event framework passed: three phases, quest archive, currency, "
		+ "limited passengers, cosmetics, alliance milestones and persistence."
	)
	quit(0)


func _complete_current_week(
	manager: EventManager,
	week: int
) -> void:
	var snapshot := manager.get_snapshot()
	var quests: Array = snapshot.get("quests", [])
	for quest_variant in quests:
		var quest: Dictionary = quest_variant
		if int(quest.get("week", 0)) != week:
			continue
		var metric := String(quest.get("metric", ""))
		var target := int(quest.get("target", 0))
		manager.record_metric(metric, target)

	snapshot = manager.get_snapshot()
	quests = snapshot.get("quests", [])
	for quest_variant in quests:
		var quest: Dictionary = quest_variant
		if int(quest.get("week", 0)) != week:
			continue
		if not bool(quest.get("complete", false)):
			continue
		manager.claim_quest(String(quest.get("id", "")))


func _cleanup_profile() -> void:
	var path := ProjectSettings.globalize_path(ProfileStore.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_cleanup_profile()
	push_error(message)
	quit(1)
