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
	_complete_current_week(manager, 2)
	if manager.get_currency() != 360:
		_fail("Weeks 1-2 should award 360 event currency.")
		return

	manager.set_now_override(
		start + 15 * EventCatalog.SECONDS_PER_DAY
	)
	_complete_current_week(manager, 3)
	if manager.get_currency() != 600:
		_fail("All 12 personal quests should award 600 event currency.")
		return

	snapshot = manager.get_snapshot()
	if int(snapshot.get("alliance_personal", 0)) != 180:
		_fail("Full personal event should contribute 180 alliance points.")
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
		"Event framework passed: 21-day weeks, quests, currency, "
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
