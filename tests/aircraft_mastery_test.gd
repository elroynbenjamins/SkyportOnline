extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_profile()

	var aerolet := AircraftCatalog.get_profile("aerolet_100")
	var london := DestinationCatalog.get_destination("london")
	var plan := FlightRules.create_flight_plan(aerolet, london)

	if plan.is_empty():
		_fail("Mastery test flight plan should be created.")
		return

	var expected_hours := (
		float(london.get("distance_km", 0.0))
		/ float(aerolet.get("cruise_speed_kph", 1.0))
	)
	if absf(
		float(plan.get("flight_hours", 0.0)) - expected_hours
	) > 0.001:
		_fail("Flight plan should track real route flight hours.")
		return

	var expected_stars := {
		0.0: 0,
		9.99: 0,
		10.0: 1,
		50.0: 2,
		150.0: 3,
		400.0: 4,
		1000.0: 5
	}
	for hours in expected_stars.keys():
		if AircraftMastery.stars_for_hours(float(hours)) != int(
			expected_stars[hours]
		):
			_fail("Mastery star milestone mismatch at %s hours." % hours)
			return

	if AircraftMastery.passenger_requirement(18, 0.0) != 18:
		_fail("Unmastered aircraft should use full passenger requirement.")
		return
	if AircraftMastery.passenger_requirement(18, 10.0) != 17:
		_fail("Star 1 should reduce an 18-seat requirement to 17.")
		return
	if AircraftMastery.passenger_requirement(18, 400.0) != 16:
		_fail("Star 4 should reduce an 18-seat requirement to 16.")
		return

	if AircraftMastery.apply_xp_bonus(100, 50.0) != 105:
		_fail("Star 2 should grant +5% XP.")
		return
	if AircraftMastery.apply_coin_bonus(100, 150.0) != 105:
		_fail("Star 3 should grant +5% coins.")
		return
	if AircraftMastery.apply_xp_bonus(100, 400.0) != 110:
		_fail("Star 4 should improve XP to +10%.")
		return
	if AircraftMastery.apply_coin_bonus(100, 1000.0) != 110:
		_fail("Star 5 should improve coin bonus to +10%.")
		return

	var profile := ProfileStore.create_guest_airport(
		"Mastery Test",
		"MST",
		"NL"
	)
	if profile.is_empty():
		_fail("Mastery persistence profile should be created.")
		return

	profile = ProfileStore.add_aircraft_mastery_hours(
		"aerolet_100",
		9.5
	)
	profile = ProfileStore.add_aircraft_mastery_hours(
		"aerolet_100",
		1.0
	)
	if profile.is_empty():
		_fail("Aircraft mastery hours should persist.")
		return

	var stored: Dictionary = profile.get(
		"aircraft_mastery_hours",
		{}
	)
	if absf(float(stored.get("aerolet_100", 0.0)) - 10.5) > 0.001:
		_fail("Mastery hours should accumulate by aircraft type.")
		return

	var reloaded := ProfileStore.load_profile()
	var reloaded_mastery: Dictionary = reloaded.get(
		"aircraft_mastery_hours",
		{}
	)
	if absf(
		float(reloaded_mastery.get("aerolet_100", 0.0)) - 10.5
	) > 0.001:
		_fail("Mastery hours should survive profile reload.")
		return

	if AircraftMastery.stars_for_hours(
		float(reloaded_mastery.get("aerolet_100", 0.0))
	) != 1:
		_fail("Persisted mastery should resolve to the correct star count.")
		return

	_cleanup_profile()
	print(
		"Aircraft mastery passed: 10/50/150/400/1000h milestones, "
		+ "passenger reductions, XP/coin bonuses, and persistence."
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
