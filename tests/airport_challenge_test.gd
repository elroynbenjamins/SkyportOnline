extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if AirportChallengeRules.is_unlocked(7):
		_fail("Weekly Airport Challenge must remain locked before level 8.")
		return
	if not AirportChallengeRules.is_unlocked(8):
		_fail("Weekly Airport Challenge should unlock at level 8.")
		return

	var now := 604800.0 * 30.0 + 3600.0
	var state := {
		"airport_id": "challenge-test",
		"coins": 1000,
		"xp": 0,
		"aero_tokens": 0,
		"gems": 0
	}
	if not AirportChallengeRules.ensure_state(state, 8, now):
		_fail("First challenge access should initialize weekly state.")
		return
	var initial_snapshot := AirportChallengeRules.snapshot(state, 8, now)
	if String(initial_snapshot.get("theme_id", "")) != "balanced_ops":
		_fail("Week 30 should resolve to the deterministic Balanced Operations theme.")
		return

	var points := AirportChallengeRules.record_flight(
		state,
		8,
		{
			"passengers": 50,
			"distance_km": 1200,
			"resources": 1,
			"country": "NL"
		},
		now
	)
	if points != 12:
		_fail("Expected first representative flight to score 12 points.")
		return

	# Two more distinct-country flights should pass the first 25 point milestone.
	AirportChallengeRules.record_flight(
		state,
		8,
		{"passengers": 50, "distance_km": 1200, "resources": 1, "country": "BE"},
		now
	)
	AirportChallengeRules.record_flight(
		state,
		8,
		{"passengers": 25, "distance_km": 500, "resources": 0, "country": "DE"},
		now
	)
	var snapshot := AirportChallengeRules.snapshot(state, 8, now)
	if String(snapshot.get("theme_name", "")).is_empty() or String(snapshot.get("theme_scoring", "")).is_empty():
		_fail("Challenge snapshot should expose the active theme and its scoring explanation.")
		return
	if int(snapshot.get("score", 0)) < 25:
		_fail("Representative flights should reach the first weekly milestone.")
		return
	if int(snapshot.get("countries", 0)) != 3:
		_fail("Challenge should track distinct destination countries.")
		return

	var claimed := AirportChallengeRules.claim_milestone(state, 8, "bronze", now)
	if claimed.is_empty():
		_fail("Reached Bronze Wing milestone should be claimable.")
		return
	var next: Dictionary = claimed.get("state", {})
	if int(next.get("coins", 0)) != 2200:
		_fail("Bronze Wing should add 1,200 coins.")
		return
	if int(next.get("xp", 0)) != 40:
		_fail("Bronze Wing should add 40 XP.")
		return
	if not AirportChallengeRules.claim_milestone(next, 8, "bronze", now).is_empty():
		_fail("Weekly challenge milestones must not be claimable twice.")
		return

	# Same-week migration should add a missing theme id without resetting earned progress.
	var migrated := next.duplicate(true)
	var migrated_challenge: Dictionary = migrated.get("airport_challenge", {})
	var score_before_migration := int(migrated_challenge.get("score", 0))
	migrated_challenge.erase("theme_id")
	migrated["airport_challenge"] = migrated_challenge
	if not AirportChallengeRules.ensure_state(migrated, 8, now):
		_fail("Same-week legacy challenge state should gain the deterministic theme id.")
		return
	if int((migrated.get("airport_challenge", {}) as Dictionary).get("score", -1)) != score_before_migration:
		_fail("Adding the weekly theme to an existing save must preserve challenge progress.")
		return

	var next_week := now + float(AirportChallengeRules.WEEK_SECONDS)
	if not AirportChallengeRules.ensure_state(next, 8, next_week):
		_fail("Challenge should reset when the weekly key changes.")
		return
	var rolled := AirportChallengeRules.snapshot(next, 8, next_week)
	if int(rolled.get("score", -1)) != 0 or int(rolled.get("flights", -1)) != 0:
		_fail("Weekly rollover should reset challenge score and flight count.")
		return
	if String(rolled.get("theme_id", "")) != "passenger_rush":
		_fail("The next week should rotate from Balanced Operations to Passenger Rush.")
		return

	var rush_points := AirportChallengeRules.record_flight(
		next,
		8,
		{"passengers": 50, "distance_km": 1200, "resources": 1, "country": "FR"},
		next_week
	)
	if rush_points != 10:
		_fail("Passenger Rush should apply its passenger-heavy scoring profile.")
		return

	var world_tour_time := now + float(AirportChallengeRules.WEEK_SECONDS * 3)
	var world_state := {
		"airport_id": "world-tour-test",
		"coins": 0,
		"xp": 0
	}
	AirportChallengeRules.ensure_state(world_state, 8, world_tour_time)
	if String(AirportChallengeRules.snapshot(world_state, 8, world_tour_time).get("theme_id", "")) != "world_tour":
		_fail("The fourth theme in the rotation should be World Tour.")
		return
	var first_country_points := AirportChallengeRules.record_flight(
		world_state,
		8,
		{"passengers": 50, "distance_km": 1200, "resources": 1, "country": "JP"},
		world_tour_time
	)
	var repeat_country_points := AirportChallengeRules.record_flight(
		world_state,
		8,
		{"passengers": 50, "distance_km": 1200, "resources": 1, "country": "JP"},
		world_tour_time
	)
	if first_country_points - repeat_country_points != 5:
		_fail("World Tour should award its +5 bonus only on the first flight to a country.")
		return

	var screen := AirportChallengeScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(rolled)
	if not screen.is_open():
		_fail("Weekly challenge screen should open with the gameplay snapshot.")
		return
	if not screen.theme_label.text.contains("PASSENGER RUSH"):
		_fail("Challenge screen should prominently show the active weekly theme.")
		return
	screen.close_screen(true)
	if screen.is_open():
		_fail("Challenge screen should support silent navigation close.")
		return

	print("Weekly Airport Challenge passed: rotation, themed scoring, migration, rewards and rollover.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
