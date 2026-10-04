extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var now_unix := 1791072000
	var active := EventCatalog.active_event(now_unix)
	if active.is_empty():
		_fail("Autumn Airbridge should be active on October 4, 2026.")
		return
	if String(active.get("id", "")) != "autumn_airbridge_2026":
		_fail("October active event should be Autumn Airbridge.")
		return
	if EventCatalog.current_week(active, now_unix) != 1:
		_fail("October 4 should be Autumn Airbridge week 1.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Autumn Test",
		"AUT",
		"NL"
	)
	if profile.is_empty():
		_fail("Autumn event test profile should be created.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var economy := PassengerEconomy.new()
	root.add_child(economy)
	economy.configure(grid, 0.0)

	var manager := EventManager.new()
	root.add_child(manager)
	manager.set_now_override(now_unix)
	manager.configure(economy)

	var snapshot := manager.get_snapshot()
	if not bool(snapshot.get("active", false)):
		_fail("Live Autumn event should configure without an override.")
		return
	if String(snapshot.get("name", "")) != "Autumn Airbridge":
		_fail("Live event name should be Autumn Airbridge.")
		return
	if String(snapshot.get("currency_name", "")) != "Autumn Vouchers":
		_fail("Autumn event should use Autumn Vouchers.")
		return
	if int(snapshot.get("featured_route_currency", 0)) != 5:
		_fail("Featured routes should award 5 Autumn Vouchers.")
		return

	var featured: Array = snapshot.get("featured_destinations", [])
	for required in ["brussels", "london", "paris"]:
		if not featured.has(required):
			_fail("Autumn featured routes should include %s." % required)
			return

	manager.record_destination_flight("brussels")
	if manager.get_currency() != 5:
		_fail("Completed Brussels featured route should award +5 vouchers.")
		return

	snapshot = manager.get_snapshot()
	var brussels_progress := -1
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		if String(quest.get("id", "")) == "autumn_w1_brussels":
			brussels_progress = int(quest.get("progress", -1))
			break
	if brussels_progress != 1:
		_fail("Brussels featured return should advance its route quest.")
		return

	manager.record_destination_flight("frankfurt")
	if manager.get_currency() != 5:
		_fail("Non-featured Frankfurt should not award route vouchers.")
		return

	manager.record_destination_flight("brussels")
	manager.record_destination_flight("brussels")
	if manager.get_currency() != 15:
		_fail("Three Brussels featured returns should award 15 vouchers.")
		return

	snapshot = manager.get_snapshot()
	var brussels_complete := false
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		if String(quest.get("id", "")) != "autumn_w1_brussels":
			continue
		brussels_complete = bool(quest.get("complete", false))
		if int(quest.get("progress", 0)) != 3:
			_fail("Brussels route quest should stop at 3/3.")
			return
	if not brussels_complete:
		_fail("Three Brussels returns should complete route quest.")
		return

	var claim := manager.claim_quest("autumn_w1_brussels")
	if not bool(claim.get("success", false)):
		_fail("Completed Autumn route quest should be claimable.")
		return
	if manager.get_currency() != 60:
		_fail("3 route bonuses + 45 quest reward should total 60 vouchers.")
		return

	var stored := ProfileStore.get_event_state("autumn_airbridge_2026")
	if int(stored.get("currency", -1)) != 60:
		_fail("Autumn event currency should persist.")
		return
	var featured_counts: Dictionary = stored.get("featured_route_flights", {})
	if int(featured_counts.get("brussels", 0)) != 3:
		_fail("Featured-route return counts should persist.")
		return

	var screen := EventScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_event(manager.get_snapshot())

	if not screen.root.visible:
		_fail("Event screen should open for live Autumn event.")
		return
	if not screen.title_label.text.contains("AUTUMN AIRBRIDGE"):
		_fail("Event screen should show Autumn Airbridge title.")
		return
	if not screen.featured_routes_label.text.contains("Brussels"):
		_fail("Event screen should list Brussels as a featured route.")
		return
	if not screen.featured_routes_label.text.contains("+5 Autumn Vouchers"):
		_fail("Event screen should show featured-route voucher reward.")
		return

	_cleanup_profile()
	print(
		"Autumn Airbridge passed: live October event, featured routes, "
		+ "route quests, +5 vouchers, persistence, and event UI."
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
