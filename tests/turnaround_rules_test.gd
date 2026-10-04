extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := AircraftCatalog.all()
	if catalog.size() != 9:
		_fail("V1 should contain exactly 9 implemented S/M aircraft.")
		return

	var expected_ids := [
		"pico_p8",
		"swift_s14",
		"comet_c22",
		"voyager_v32",
		"nimbus_n40",
		"arrow_a52",
		"atlas_a64",
		"falcon_f72",
		"horizon_h88"
	]
	for aircraft_id in expected_ids:
		var profile := AircraftCatalog.get_profile(aircraft_id)
		if profile.is_empty():
			_fail("Missing approved V1 aircraft: %s" % aircraft_id)
			return
		if not String(profile.get("size", "")).is_empty() and not (
			String(profile.get("size", "")) in ["S", "M"]
		):
			_fail("V1 aircraft should currently be S or M only.")
			return

		var timing := TurnaroundRules.timing_for_profile(profile)
		for key in [
			"deboard_seconds",
			"cargo_unload_seconds",
			"fuel_seconds",
			"clean_seconds",
			"catering_seconds",
			"board_seconds",
			"cargo_load_seconds",
			"pushback_seconds"
		]:
			if float(timing.get(key, 0.0)) <= 0.0:
				_fail("%s should define positive %s." % [aircraft_id, key])
				return

	var pico := AircraftCatalog.get_profile("pico_p8")
	var swift := AircraftCatalog.get_profile("swift_s14")
	var nimbus := AircraftCatalog.get_profile("nimbus_n40")
	var atlas := AircraftCatalog.get_profile("atlas_a64")
	var falcon := AircraftCatalog.get_profile("falcon_f72")
	var horizon := AircraftCatalog.get_profile("horizon_h88")

	if absf(TurnaroundRules.estimated_turnaround_seconds(pico) - 31.0) > 0.001:
		_fail("Pico P8 standard return turnaround should be 31 seconds.")
		return
	if absf(TurnaroundRules.estimated_turnaround_seconds(swift) - 32.0) > 0.001:
		_fail("Swift S14 standard return turnaround should be 32 seconds.")
		return
	if absf(TurnaroundRules.estimated_turnaround_seconds(horizon) - 99.0) > 0.001:
		_fail("Horizon H88 standard return turnaround should be 99 seconds.")
		return

	var rapid_pico := TurnaroundRules.estimated_turnaround_seconds(
		pico,
		1.6,
		true
	)
	if rapid_pico >= 31.0:
		_fail("A rapid fuel station should reduce Pico turnaround time.")
		return

	if float(swift.get("taxi_speed", 0.0)) <= float(pico.get("taxi_speed", 0.0)):
		_fail("Swift S14 should taxi faster than Pico P8.")
		return
	if TurnaroundRules.estimated_turnaround_seconds(atlas) <= (
		TurnaroundRules.estimated_turnaround_seconds(nimbus)
	):
		_fail("Atlas A64 should create a larger ground-handling burden than Nimbus N40.")
		return
	if TurnaroundRules.estimated_turnaround_seconds(falcon) >= (
		TurnaroundRules.estimated_turnaround_seconds(atlas)
	):
		_fail("Falcon F72 should turn around faster than the economy-focused Atlas A64.")
		return

	var plane := AircraftPrototype.new()
	root.add_child(plane)
	plane.configure_aircraft_type("arrow_a52")
	if absf(plane.taxi_speed - float(
		AircraftCatalog.get_profile("arrow_a52").get("taxi_speed", 0.0)
	)) > 0.001:
		_fail("Aircraft prototype should apply per-plane taxi speed.")
		return
	if absf(
		plane.get_turnaround_seconds()
		- TurnaroundRules.estimated_turnaround_seconds(
			AircraftCatalog.get_profile("arrow_a52")
		)
	) > 0.001:
		_fail("Aircraft should expose its per-plane turnaround estimate.")
		return

	print(
		"Turnaround rules passed: Pico 31s, Swift 32s, "
		+ "Nimbus %.0fs, Atlas %.0fs, Falcon %.0fs, Horizon 99s."
		% [
			TurnaroundRules.estimated_turnaround_seconds(nimbus),
			TurnaroundRules.estimated_turnaround_seconds(atlas),
			TurnaroundRules.estimated_turnaround_seconds(falcon)
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
