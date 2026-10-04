extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var validation := EventCatalog.validate_catalog()
	if not bool(validation.get("valid", false)):
		_fail(
			"Current event catalog should validate: %s"
			% str(validation.get("errors", []))
		)
		return

	var autumn := EventCatalog.get_event(
		"autumn_airbridge_2026"
	)
	var lantern := EventCatalog.get_event(
		"sky_lantern_festival_2026"
	)
	if autumn.is_empty() or lantern.is_empty():
		_fail("Live Autumn event and disabled template must both exist.")
		return

	if not bool(autumn.get("enabled", false)):
		_fail("Autumn Airbridge should currently be enabled.")
		return
	if bool(lantern.get("enabled", true)):
		_fail("Sky Lantern template should remain disabled.")
		return

	if EventCatalog.total_personal_currency(lantern) != 600:
		_fail("Standard template personal quest currency should total 600.")
		return
	if EventCatalog.total_personal_currency(autumn) != 620:
		_fail("Autumn featured-destination tuning should total 620 quest currency.")
		return

	if EventCatalog.total_shop_passengers(lantern) != 150:
		_fail("Standard template should cap shop passengers at 150.")
		return
	if EventCatalog.total_shop_passengers(autumn) != 150:
		_fail("Autumn event should cap shop passengers at 150.")
		return

	if EventCatalog.total_alliance_currency(lantern) != 300:
		_fail("Standard Alliance currency rewards should total 300.")
		return
	if EventCatalog.total_alliance_currency(autumn) != 300:
		_fail("Autumn Alliance currency rewards should total 300.")
		return

	var autumn_start := int(autumn.get("start_unix", 0))
	var live_events := EventCatalog.active_events(
		autumn_start + EventCatalog.SECONDS_PER_DAY
	)
	if live_events.size() != 1:
		_fail("Exactly one event should be active during Autumn Airbridge.")
		return
	if String(live_events[0].get("id", "")) != "autumn_airbridge_2026":
		_fail("Autumn Airbridge should be the active event in its window.")
		return

	var overlap := lantern.duplicate(true)
	overlap["enabled"] = true
	overlap["start_unix"] = autumn_start + 7 * EventCatalog.SECONDS_PER_DAY
	if not EventCatalog._windows_overlap(autumn, overlap):
		_fail("Overlapping 21-day event windows should be detected.")
		return

	overlap["start_unix"] = (
		autumn_start
		+ EventCatalog.EVENT_DURATION_DAYS
		* EventCatalog.SECONDS_PER_DAY
	)
	if EventCatalog._windows_overlap(autumn, overlap):
		_fail("Back-to-back 21-day events should not overlap.")
		return

	print(
		"Event ops safety passed: live Autumn tuning, standard template totals, "
		+ "passenger cap and overlap checks are valid."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
