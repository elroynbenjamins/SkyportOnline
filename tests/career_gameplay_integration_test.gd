extends SceneTree

var airport_id := ""
var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _place_for_career(
	main,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview: Dictionary = main.airport_grid.set_build_preview(
		building_id,
		main.airport_grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		return false
	return not main.airport_grid.confirm_build_preview().is_empty()


func _build_required_starter_airside(main) -> bool:
	# This test covers post-onboarding career gameplay. Build the same minimal
	# operational airport that the guided tutorial leaves behind, while the
	# dedicated starter tests validate the forced tutorial itself.
	if not _place_for_career(main, "short_runway", Vector2i(0, 0)):
		return false
	if not _place_for_career(main, "small_hangar", Vector2i(0, 6)):
		return false
	if not _place_for_career(main, "small_stand", Vector2i(4, 6)):
		return false

	for y in range(2, 8):
		if not _place_for_career(
			main,
			"taxiway",
			Vector2i(3, y)
		):
			return false

	if not _place_for_career(main, "basic_fuel", Vector2i(8, 6)):
		return false
	if not _place_for_career(main, "ground_ops_depot", Vector2i(8, 8)):
		return false

	for cell in [
		Vector2i(6, 7),
		Vector2i(7, 7),
		Vector2i(7, 8)
	]:
		if not _place_for_career(
			main,
			"service_road",
			cell
		):
			return false

	if not _place_for_career(main, "small_terminal", Vector2i(10, 10)):
		return false
	return true


func _run() -> void:
	_cleanup()
	var scene = load("res://src/main/Main.tscn")
	if scene == null:
		push_error("Main scene could not load.")
		quit(1)
		return
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	if not main.has_method("_claim_career_reward"):
		push_error("Main scene did not load the progression script.")
		quit(1)
		return
	var profile := ProfileStore.create_guest_airport("Career Test", "CAR", "NL")
	# This integration test is intentionally post-onboarding. New-player
	# construction is covered separately by starter_airport_tutorial_test.gd.
	profile = ProfileStore.set_starter_tutorial_complete(true)
	airport_id = String(profile.get("airport_id", ""))
	print("Starting actual airport gameplay integration")
	main._on_airport_created(profile)
	main.airport_setup.close()
	await process_frame
	check(main.gameplay_started and main.progression_ready, "Guest creation must start the real game.")
	check(main.player_level == 1, "A new airport starts career progression at level one.")
	check(
		_build_required_starter_airside(main),
		"Fresh career test should be able to construct the required starter airside network."
	)
	main._persist_airport_layout()
	main._refresh_layout_dependent_systems()
	await process_frame
	check(
		main.aircraft_demos.size() == 1,
		"One connected starter stand should deploy one Pico; the second waits for another stand."
	)
	check(
		(main.progression.get("owned_aircraft", []) as Array).size() == 2,
		"Both starter Picos should remain owned even when only one is deployed."
	)
	check(main.career_pin != null, "A live career action must replace the static HUD objective.")
	check(main.career_screen != null, "Career screen must be installed in the actual scene.")
	main.npc_director.remaining = 0.0
	main.npc_director.rng.seed = 42
	main.checkpoint_elapsed = 0.0

	# Deterministic foreground simulation: real aircraft and real vehicles, no forged service callbacks.
	# Disable automatic process on our manually stepped nodes so the two clocks cannot double count.
	main.set_process(false)
	main.passenger_economy.set_process(false)
	main.ground_services.set_process(false)
	main.runway_dispatcher.set_process(false)
	main.taxi_traffic.set_process(false)
	var finished := false
	for step in range(8000):
		main._process(0.10)
		main.passenger_economy._process(0.10)
		main.ground_services._process(0.10)
		main.runway_dispatcher._process(0.10)
		if main.taxi_traffic.has_method("_process"):
			main.taxi_traffic._process(0.10)
		var aircraft: Array = main.aircraft_demos.duplicate()
		aircraft.append_array(main.social_visitor_aircraft.values())
		for plane in aircraft:
			if is_instance_valid(plane) and not plane.is_queued_for_deletion():
				plane.set_process(false)
				# The production game is tactile by default. Simulate an
				# attentive player immediately pressing each surfaced action
				# so this integration test still exercises the full real loop.
				var handling_action: String = String(
					plane.get_handling_action()
				)
				if (
					not handling_action.is_empty()
					and not plane.is_social_visitor()
				):
					main._on_aircraft_handling_action_requested(
						plane,
						handling_action
					)
				if (
					plane.state == "READY_FOR_DESTINATION"
					and not plane.has_flight_plan()
					and not plane.is_social_visitor()
				):
					main._on_world_map_flight_assignment_requested(
						plane,
						"brussels"
					)
				plane._process(0.10)
		for vehicle in main.ground_services.get_children():
			if is_instance_valid(vehicle) and not vehicle.is_queued_for_deletion() and vehicle.has_method("_process"):
				vehicle.set_process(false)
				vehicle._process(0.10)
		if step % 30 == 0:
			await process_frame
		var first_progress := int((main.progression.get("progress", {}) as Dictionary).get("first_circuit", 0))
		if first_progress >= 1 and int(main.progression.get("npc_serviced", 0)) >= 1:
			finished = true
			break
	if not finished:
		var states: Array[String] = []
		for plane in main.aircraft_demos:
			states.append(String(plane.name) + ":" + plane.state + ":" + plane.get_taxi_hold_reason())
		for plane in main.social_visitor_aircraft.values():
			if is_instance_valid(plane):
				states.append(String(plane.name) + ":" + plane.state)
		errors.append("Real flight/NPC cycle stalled: " + "; ".join(states))
	check(finished, "Real owned flight return and NPC departure should both complete.")
	var social_state := ProfileStore.get_social_state()
	check((social_state.get("reward_receipt_outbox", []) as Array).is_empty(), "NPC must not write a remote-owner reward receipt.")
	check((main.progression.get("friendships", {}) as Dictionary).is_empty(), "NPC must not create friendship credit.")

	# Force full passenger storage at claim time; the earned reward must stay available in reserve.
	main.passenger_economy.set_passengers(main.passenger_economy.get_capacity())
	var xp_before: int = main.player_xp
	var coins_before: int = main.coins
	main._claim_career_reward("first_circuit")
	check(main.player_xp == xp_before + 80, "First career claim should award exactly 80 XP.")
	check(main.coins == coins_before, "Career claim must not award coins.")
	check(int(main.progression.get("pending_passengers", 0)) == 8, "Full storage should retain all eight quest passengers.")
	main._claim_career_reward("first_circuit")
	check(main.player_xp == xp_before + 80, "Repeat UI claim must not duplicate XP.")
	main.passenger_economy.spend_passengers(3)
	main._drain_passenger_rewards()
	check(int(main.progression.get("pending_passengers", 0)) == 5, "Only newly available capacity should release reserved passengers.")
	check(main.passenger_economy.get_passengers() == main.passenger_economy.get_capacity(), "Reward release should fill, but never exceed, capacity.")

	main._purchase_career_aircraft("swift_s14")
	check((main.progression.get("owned_aircraft", []) as Array).size() == 3, "Aircraft Orders must add the Swift to real ownership.")
	check(main.coins == coins_before - 3500, "Aircraft Orders must spend the defined price once.")
	main._open_career()
	await process_frame
	check(main.career_screen.is_open(), "Career pin must open the usable screen.")
	for tab in ["Career", "Aircraft Orders", "NPC Visitors", "Friendship"]:
		main.career_screen.open_tab(tab)
		await process_frame
		check(main.career_screen.body.get_child_count() > 0, "Career tab should contain controls: " + tab)
	main._save_checkpoint()
	var saved_coins: int = main.coins
	var saved_xp: int = main.player_xp
	main.queue_free()
	await process_frame
	await process_frame
	var saved := AirportProgressionStore.load_state(airport_id)
	check(int(saved.get("coins", -1)) == saved_coins, "Wallet must survive checkpoint reload.")
	check(bool((saved.get("claimed", {}) as Dictionary).get("first_circuit", false)), "Claimed quest must survive reload.")
	check((saved.get("owned_aircraft", []) as Array).size() == 3, "Owned Swift must survive reload.")
	check(int(saved.get("pending_passengers", -1)) == 5, "Reserved passenger reward must survive reload.")
	var restored = scene.instantiate()
	root.add_child(restored)
	await process_frame
	check(restored.gameplay_started and restored.progression_ready, "Saved airport must start again.")
	check(restored.coins == saved_coins and restored.player_xp == saved_xp, "Reload must not reset the progression wallet.")
	check((restored.progression.get("owned_aircraft", []) as Array).size() == 3, "Reload must not replace purchased aircraft with demo-only fleet.")
	restored.queue_free()
	await process_frame
	await process_frame
	_cleanup()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("PROGRESSION_TEST_OK: real main scene, vehicles, return, NPC, claim, passenger reserve, aircraft order and reload")
	quit(0)

func _cleanup() -> void:
	if FileAccess.file_exists(ProfileStore.SAVE_PATH):
		DirAccess.remove_absolute(ProfileStore.SAVE_PATH)
	if not airport_id.is_empty():
		var path := AirportProgressionStore.save_path(airport_id)
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
