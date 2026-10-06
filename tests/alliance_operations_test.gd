extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var now := 604800.0 * 20.0 + 3600.0
	var state := {
		"airport_id": "alliance-test",
		"coins": 1000,
		"xp": 0
	}
	if not AllianceOperationsRules.ensure_state(state, now):
		_fail("First Alliance Operations access should initialize weekly state.")
		return

	AllianceOperationsRules.record_action(state, "flight", 1, now)
	AllianceOperationsRules.record_action(state, "alliance_visit", 1, now)
	AllianceOperationsRules.record_action(state, "alliance_gift", 1, now)
	var snapshot := AllianceOperationsRules.snapshot(state, now, false, true)
	if int(snapshot.get("personal_points", 0)) != 5:
		_fail("Flight + alliance visit + alliance support should total 5 personal points.")
		return
	if int(snapshot.get("alliance_total", 0)) != 5:
		_fail("Local simulation should mirror personal contribution before server totals exist.")
		return

	AllianceOperationsRules.set_server_total(state, 25, now)
	snapshot = AllianceOperationsRules.snapshot(state, now, true, false)
	if int(snapshot.get("alliance_total", 0)) != 25:
		_fail("Connected alliance total should accept a server-backed project total.")
		return

	var tier_two: Dictionary = {}
	for milestone_variant in snapshot.get("milestones", []):
		var milestone: Dictionary = milestone_variant
		if String(milestone.get("id", "")) == "network_push":
			tier_two = milestone
			break
	if tier_two.is_empty() or not bool(tier_two.get("claimable", false)):
		_fail("Network Push should be claimable at 25 alliance / 5 personal points.")
		return

	var claimed := AllianceOperationsRules.claim_milestone(
		state,
		"network_push",
		now
	)
	if claimed.is_empty():
		_fail("Reached Alliance milestone should grant its reward.")
		return
	var next: Dictionary = claimed.get("state", {})
	if int(next.get("coins", 0)) != 3500:
		_fail("Network Push should add 2,500 coins.")
		return
	if int(next.get("xp", 0)) != 75:
		_fail("Network Push should add 75 XP.")
		return
	if not AllianceOperationsRules.claim_milestone(
		next,
		"network_push",
		now
	).is_empty():
		_fail("Alliance milestone rewards must not be claimable twice.")
		return

	var next_week := now + float(AllianceOperationsRules.WEEK_SECONDS)
	if not AllianceOperationsRules.ensure_state(next, next_week):
		_fail("Alliance Operations should reset when the weekly key changes.")
		return
	var rolled := AllianceOperationsRules.snapshot(
		next,
		next_week,
		false,
		true
	)
	if int(rolled.get("personal_points", -1)) != 0:
		_fail("Weekly rollover should reset personal contribution.")
		return
	for milestone_variant in rolled.get("milestones", []):
		if bool((milestone_variant as Dictionary).get("claimed", false)):
			_fail("Weekly rollover should reset claimed milestones.")
			return

	var screen := AllianceOperationsScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(rolled)
	if not screen.is_open():
		_fail("Alliance Operations screen should open with weekly snapshot.")
		return
	screen.close_screen(true)
	if screen.is_open():
		_fail("Alliance Operations screen should support a silent navigation close.")
		return

	print("Alliance Operations passed: weekly actions, server total, personal gate, rewards and rollover.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
