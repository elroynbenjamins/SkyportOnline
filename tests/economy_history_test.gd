extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var profile := ProfileStore.create_guest_airport(
		"Economy Test",
		"ECO",
		"NL"
	)
	if profile.is_empty():
		_fail("Economy history profile should be created.")
		return

	profile = ProfileStore.add_economy_stats({
		"passengers_generated": 25,
		"passengers_boarded": 14,
		"flights_completed": 1,
		"flight_coins": 420,
		"flight_xp": 32,
		"resources_earned": 2
	})
	if profile.is_empty():
		_fail("Economy stats should persist.")
		return

	profile = ProfileStore.add_economy_stats({
		"passengers_generated": 5,
		"passengers_boarded": 6,
		"flights_completed": 1,
		"flight_coins": 760,
		"flight_xp": 48,
		"resources_earned": 1,
		"ignored_negative": -50
	})

	var stats: Dictionary = profile.get("economy_stats", {})
	if int(stats.get("passengers_generated", 0)) != 30:
		_fail("Passenger generation history should accumulate.")
		return
	if int(stats.get("passengers_boarded", 0)) != 20:
		_fail("Passenger boarding history should accumulate.")
		return
	if int(stats.get("flights_completed", 0)) != 2:
		_fail("Completed flight history should accumulate.")
		return
	if int(stats.get("flight_coins", 0)) != 1180:
		_fail("Flight coin history should accumulate.")
		return
	if int(stats.get("flight_xp", 0)) != 80:
		_fail("Flight XP history should accumulate.")
		return
	if int(stats.get("resources_earned", 0)) != 3:
		_fail("Resource earnings history should accumulate.")
		return
	if stats.has("ignored_negative"):
		_fail("Lifetime economy history should ignore negative deltas.")
		return

	var reloaded := ProfileStore.load_profile()
	var reloaded_stats: Dictionary = reloaded.get("economy_stats", {})
	if int(reloaded_stats.get("flights_completed", 0)) != 2:
		_fail("Economy history should survive profile reload.")
		return

	var screen := ResourceInventoryScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_inventory(
		{},
		18,
		40,
		1.5,
		false,
		reloaded_stats
	)

	if not screen.economy_history_label.text.contains("Generated 30 pax"):
		_fail("MORE screen should render generated passenger history.")
		return
	if not screen.economy_history_label.text.contains("Boarded 20 pax"):
		_fail("MORE screen should render boarded passenger history.")
		return
	if not screen.economy_history_label.text.contains("Flights 2"):
		_fail("MORE screen should render completed flight history.")
		return
	if not screen.economy_history_label.text.contains("Flight coins 1180"):
		_fail("MORE screen should render flight coin history.")
		return
	if not screen.economy_history_label.text.contains("Resources 3"):
		_fail("MORE screen should render resource earnings history.")
		return

	_cleanup_profile()
	print(
		"Economy history passed: passenger flow, flight returns, "
		+ "resources, persistence, and MORE-screen rendering."
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
