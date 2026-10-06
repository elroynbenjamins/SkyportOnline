extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var now := float(DispatchChallengeRules.DAY_SECONDS * 100 + 120)
	var state := {
		"airport_id": "dispatch-test",
		"coins": 1000,
		"xp": 0
	}

	if DispatchChallengeRules.is_unlocked(11):
		_fail("Airport Dispatch must remain locked before level 12.")
		return
	if not DispatchChallengeRules.is_unlocked(12):
		_fail("Airport Dispatch should unlock at level 12.")
		return
	if DispatchChallengeRules.ensure_state(state, 11, now):
		_fail("Locked Dispatch should not initialize persistent mode state.")
		return
	if not DispatchChallengeRules.ensure_state(state, 12, now):
		_fail("First unlocked Dispatch access should initialize daily state.")
		return

	var started := DispatchChallengeRules.start_shift(
		state,
		12,
		now
	)
	if started.is_empty():
		_fail("Unlocked player should be able to start a Dispatch shift.")
		return
	var running := DispatchChallengeRules.snapshot(started, 12, now)
	if String(running.get("status", "")) != "RUNNING":
		_fail("New Dispatch shift should be RUNNING.")
		return
	if int(running.get("remaining_seconds", 0)) != DispatchChallengeRules.SHIFT_SECONDS:
		_fail("Dispatch shift should begin with the full three-minute timer.")
		return

	if DispatchChallengeRules.record_action(started, 12, "turnaround", 2, now + 5) != 10:
		_fail("Two completed turnarounds should add 10 Dispatch points.")
		return
	DispatchChallengeRules.record_action(started, 12, "departure", 4, now + 10)
	DispatchChallengeRules.record_action(started, 12, "return", 3, now + 20)
	DispatchChallengeRules.record_action(started, 12, "visitor_service", 2, now + 30)
	if DispatchChallengeRules.record_action(started, 12, "taxi_hold", 1, now + 40) != -2:
		_fail("Taxi hold should apply the two-point Dispatch penalty.")
		return

	var live := DispatchChallengeRules.snapshot(started, 12, now + 40)
	if int(live.get("score", 0)) != 96:
		_fail("Representative live shift should total 96 Dispatch points.")
		return
	if int(live.get("taxi_holds", 0)) != 1:
		_fail("Dispatch shift should track taxi-hold incidents.")
		return

	var end_time := now + float(DispatchChallengeRules.SHIFT_SECONDS) + 1.0
	if not DispatchChallengeRules.advance(started, 12, end_time):
		_fail("Dispatch shift should become READY when the timer expires.")
		return
	var result := DispatchChallengeRules.snapshot(started, 12, end_time)
	if String(result.get("status", "")) != "READY":
		_fail("Expired Dispatch shift should expose a READY result.")
		return
	if String(result.get("tier_id", "")) != "gold":
		_fail("96 Dispatch points should earn the Gold tier.")
		return
	if not bool(result.get("reward_available", false)):
		_fail("First Gold Dispatch result of the day should have a reward available.")
		return
	if DispatchChallengeRules.record_action(started, 12, "departure", 1, end_time + 1) != 0:
		_fail("Expired Dispatch shifts must stop accepting score events.")
		return

	var claimed := DispatchChallengeRules.claim_result(
		started,
		12,
		end_time
	)
	if claimed.is_empty():
		_fail("READY Dispatch result should be claimable.")
		return
	var claimed_state: Dictionary = claimed.get("state", {})
	var reward: Dictionary = claimed.get("reward", {})
	if not bool(reward.get("rewarded", false)):
		_fail("First daily Gold result should grant its reward.")
		return
	if int(claimed_state.get("coins", 0)) != 3500:
		_fail("Gold Dispatch should add 2,500 coins.")
		return
	if int(claimed_state.get("xp", 0)) != 80:
		_fail("Gold Dispatch should add 80 XP.")
		return
	var claimed_snapshot := DispatchChallengeRules.snapshot(
		claimed_state,
		12,
		end_time
	)
	if not bool(claimed_snapshot.get("reward_claimed", false)):
		_fail("Daily Dispatch reward should be marked claimed after payout.")
		return
	if int(claimed_snapshot.get("best_score", 0)) != 96:
		_fail("Dispatch should preserve the player's best daily score.")
		return

	# Practice remains available after the daily reward, but cannot pay twice.
	var practice := DispatchChallengeRules.start_shift(
		claimed_state,
		12,
		end_time + 10
	)
	if practice.is_empty():
		_fail("Player should be able to start a practice Dispatch shift after claiming.")
		return
	var practice_end := end_time + 10 + DispatchChallengeRules.SHIFT_SECONDS + 1
	DispatchChallengeRules.advance(practice, 12, practice_end)
	var practice_claim := DispatchChallengeRules.claim_result(
		practice,
		12,
		practice_end
	)
	if bool((practice_claim.get("reward", {}) as Dictionary).get("rewarded", true)):
		_fail("Practice Dispatch shift must not grant a second daily reward.")
		return
	if int((practice_claim.get("state", {}) as Dictionary).get("coins", 0)) != 3500:
		_fail("Practice result must not change coins after the daily reward was claimed.")
		return

	var next_day := float(
		DispatchChallengeRules.DAY_SECONDS * 101 + 120
	)
	var daily_state: Dictionary = practice_claim.get("state", {})
	if not DispatchChallengeRules.ensure_state(daily_state, 12, next_day):
		_fail("Dispatch reward window should reset on the next day.")
		return
	var next_day_snapshot := DispatchChallengeRules.snapshot(
		daily_state,
		12,
		next_day
	)
	if bool(next_day_snapshot.get("reward_claimed", true)):
		_fail("New day should restore the Dispatch daily reward.")
		return
	if int(next_day_snapshot.get("best_score", -1)) != 0:
		_fail("New day should reset the daily Dispatch best score.")
		return

	var screen := DispatchChallengeScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(next_day_snapshot)
	if not screen.is_open():
		_fail("Dispatch screen should open with mode snapshot.")
		return
	if not screen.action_button.text.contains("START 3-MINUTE SHIFT"):
		_fail("Fresh daily Dispatch screen should offer a rewarded shift.")
		return
	screen.close_screen(true)

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_dispatch_shift("RUNNING", 42, 125)
	if hud.dispatch_shift_panel == null or not hud.dispatch_shift_panel.visible:
		_fail("Live Dispatch HUD indicator should be visible during a running shift.")
		return
	if not hud.dispatch_shift_label.text.contains("2:05") or not hud.dispatch_shift_label.text.contains("42 PTS"):
		_fail("Live Dispatch HUD should show the exact countdown and score.")
		return
	hud.set_dispatch_shift("READY", 42, 0)
	if hud.dispatch_shift_panel.visible:
		_fail("Live Dispatch HUD indicator should hide after the shift ends.")
		return

	print("Airport Dispatch passed: timer, live HUD, scoring, penalty, Gold reward, practice and daily reset.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
