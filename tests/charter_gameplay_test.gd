extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if CharterRules.is_unlocked(21):
		_fail("Cargo Charter must remain hidden before level 22.")
		return
	if not CharterRules.is_unlocked(22):
		_fail("Cargo Charter should unlock at level 22.")
		return

	var now := 86400.0 * 200.0
	var state := {
		"airport_id": "charter-test",
		"coins": 1000,
		"xp": 0,
		"pending_resource_grants": []
	}
	if not CharterRules.ensure_state(state, 22, now):
		_fail("First Charter initialization should create persistent state.")
		return
	var charter: Dictionary = state.get("charter", {})
	var offers: Array = charter.get("offers", [])
	if offers.size() != CharterRules.OFFER_COUNT:
		_fail("Unlocked Charter mode should present three contracts.")
		return

	var offer: Dictionary = offers[0]
	var blocked := CharterRules.accept_contract(
		state,
		String(offer.get("id", "")),
		22,
		false,
		now
	)
	if not blocked.is_empty():
		_fail("Charter contract must not start before the Logistics District is ready.")
		return

	var accepted := CharterRules.accept_contract(
		state,
		String(offer.get("id", "")),
		22,
		true,
		now
	)
	if accepted.is_empty():
		_fail("Ready Logistics District should allow a Charter contract.")
		return
	var active: Dictionary = (accepted.get("charter", {}) as Dictionary).get("active", {})
	if String(active.get("phase", "")) != "LOADING":
		_fail("Accepted Charter should begin in LOADING.")
		return

	var visual := CharterRules.visual_snapshot(accepted, 22, true, now)
	if not bool(visual.get("turnaround_active", false)):
		_fail("Loading Charter should drive the live cargo-aircraft visual.")
		return

	var depart_at := int(active.get("depart_at", int(now) + 1))
	CharterRules.advance(accepted, float(depart_at + 1))
	active = (accepted.get("charter", {}) as Dictionary).get("active", {})
	if String(active.get("phase", "")) != "EN_ROUTE":
		_fail("Charter should depart after loading completes.")
		return
	visual = CharterRules.visual_snapshot(accepted, 22, true, float(depart_at + 1))
	if bool(visual.get("turnaround_active", true)):
		_fail("Cargo aircraft visuals should clear after Charter departure.")
		return

	var complete_at := int(active.get("complete_at", depart_at + 1))
	CharterRules.advance(accepted, float(complete_at + 1))
	active = (accepted.get("charter", {}) as Dictionary).get("active", {})
	if String(active.get("phase", "")) != "READY":
		_fail("Completed Charter should become claimable.")
		return

	var claimed := CharterRules.claim_contract(
		accepted,
		22,
		float(complete_at + 1)
	)
	if claimed.is_empty():
		_fail("READY Charter should grant its reward.")
		return
	var next: Dictionary = claimed.get("state", {})
	var reward: Dictionary = claimed.get("reward", {})
	if int(reward.get("coins", 0)) <= 0 or int(reward.get("xp", 0)) <= 0:
		_fail("Charter rewards should include coins and XP.")
		return
	if (next.get("pending_resource_grants", []) as Array).is_empty():
		_fail("Charter reward should queue its guaranteed country resource safely.")
		return
	var next_charter: Dictionary = next.get("charter", {})
	if int(next_charter.get("completed", 0)) != 1:
		_fail("Claiming should advance Charter completion count.")
		return
	if (next_charter.get("offers", []) as Array).size() != CharterRules.OFFER_COUNT:
		_fail("Claiming should refill the three-contract board.")
		return

	var screen := CharterScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_screen(
		CharterRules.snapshot(next, 22, true, true, float(complete_at + 1))
	)
	if not screen.is_open():
		_fail("Charter screen should open with the gameplay snapshot.")
		return
	screen.close_screen()

	print("Cargo Charter gameplay passed: level gate, three offers, loading, departure, claim and resource reward.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
