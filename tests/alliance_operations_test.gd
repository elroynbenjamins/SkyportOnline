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
	var initial := AllianceOperationsRules.snapshot(
		state,
		now,
		false,
		true
	)
	if String(initial.get("project_id", "")) != "airbridge":
		_fail("Week 20 should resolve to the deterministic Regional Airbridge project.")
		return
	if String(initial.get("next_project_name", "")).is_empty():
		_fail("Alliance snapshot should preview the next weekly project.")
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

	# Same-week legacy migration should attach a project id without losing points or claims.
	var migrated := next.duplicate(true)
	var migrated_ops: Dictionary = migrated.get("alliance_ops", {})
	var points_before_migration := int(migrated_ops.get("personal_points", 0))
	migrated_ops.erase("project_id")
	migrated["alliance_ops"] = migrated_ops
	if not AllianceOperationsRules.ensure_state(migrated, now):
		_fail("Legacy same-week Alliance state should gain the deterministic project id.")
		return
	if int((migrated.get("alliance_ops", {}) as Dictionary).get("personal_points", -1)) != points_before_migration:
		_fail("Alliance project migration must preserve existing weekly contribution.")
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
	if String(rolled.get("project_id", "")) != "fleet_mobilization":
		_fail("The next project should rotate from Regional Airbridge to Fleet Mobilization.")
		return
	for milestone_variant in rolled.get("milestones", []):
		if bool((milestone_variant as Dictionary).get("claimed", false)):
			_fail("Weekly rollover should reset claimed milestones.")
			return

	AllianceOperationsRules.record_action(next, "flight", 1, next_week)
	AllianceOperationsRules.record_action(next, "alliance_visit", 1, next_week)
	AllianceOperationsRules.record_action(next, "alliance_gift", 1, next_week)
	var fleet_week := AllianceOperationsRules.snapshot(
		next,
		next_week,
		false,
		true
	)
	if int(fleet_week.get("personal_points", 0)) != 6:
		_fail("Fleet Mobilization should score flight +3, visit +2 and support +1.")
		return

	var host_week_time := now + float(AllianceOperationsRules.WEEK_SECONDS * 2)
	var host_state := {"airport_id": "host-project"}
	AllianceOperationsRules.ensure_state(host_state, host_week_time)
	if String(AllianceOperationsRules.snapshot(host_state, host_week_time, false, true).get("project_id", "")) != "host_network":
		_fail("The third Alliance project should be Host Network.")
		return
	AllianceOperationsRules.record_action(host_state, "alliance_visit", 1, host_week_time)
	if int(AllianceOperationsRules.snapshot(host_state, host_week_time, false, true).get("personal_points", 0)) != 5:
		_fail("Host Network should award five points for servicing an alliance visitor.")
		return

	var relief_week_time := now + float(AllianceOperationsRules.WEEK_SECONDS * 3)
	var relief_state := {"airport_id": "relief-project"}
	AllianceOperationsRules.ensure_state(relief_state, relief_week_time)
	if String(AllianceOperationsRules.snapshot(relief_state, relief_week_time, false, true).get("project_id", "")) != "passenger_relief":
		_fail("The fourth Alliance project should be Passenger Relief.")
		return
	AllianceOperationsRules.record_action(relief_state, "alliance_gift", 1, relief_week_time)
	if int(AllianceOperationsRules.snapshot(relief_state, relief_week_time, false, true).get("personal_points", 0)) != 4:
		_fail("Passenger Relief should award four points for alliance passenger support.")
		return

	var screen := AllianceOperationsScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(rolled)
	if not screen.is_open():
		_fail("Alliance Operations screen should open with weekly snapshot.")
		return
	if not screen.project_label.text.contains("FLEET MOBILIZATION"):
		_fail("Alliance Operations screen should show the active rotating project.")
		return
	if not screen.next_project_label.text.contains("HOST NETWORK"):
		_fail("Alliance Operations screen should preview the next weekly project.")
		return
	screen.close_screen(true)
	if screen.is_open():
		_fail("Alliance Operations screen should support a silent navigation close.")
		return

	print("Alliance Operations passed: rotating projects, weighted actions, migration, rewards and rollover.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
