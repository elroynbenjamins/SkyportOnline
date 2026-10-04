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

	var event := EventCatalog.get_event(
		"sky_lantern_festival_2026"
	)
	if event.is_empty():
		_fail("Disabled sample event should exist.")
		return

	if EventCatalog.total_personal_currency(event) != 600:
		_fail("Standard personal event currency should total 600.")
		return

	if EventCatalog.total_shop_passengers(event) != 150:
		_fail("Standard event shop should cap passengers at 150.")
		return

	if EventCatalog.total_alliance_currency(event) != 300:
		_fail("Standard Alliance currency rewards should total 300.")
		return

	var start := 1000000
	var left := event.duplicate(true)
	left["enabled"] = true
	left["start_unix"] = start

	var right := event.duplicate(true)
	right["id"] = "overlap_test"
	right["enabled"] = true
	right["start_unix"] = (
		start + 7 * EventCatalog.SECONDS_PER_DAY
	)

	if not EventCatalog._windows_overlap(left, right):
		_fail("Overlapping 21-day event windows should be detected.")
		return

	right["start_unix"] = (
		start
		+ EventCatalog.EVENT_DURATION_DAYS
		* EventCatalog.SECONDS_PER_DAY
	)
	if EventCatalog._windows_overlap(left, right):
		_fail("Back-to-back 21-day events should not overlap.")
		return

	var active_now := EventCatalog.active_events(
		int(Time.get_unix_time_from_system())
	)
	if not active_now.is_empty():
		_fail("The sample event ships disabled; no event should be active.")
		return

	print(
		"Event ops safety passed: catalog valid, template totals locked, "
		+ "overlap detection works."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
