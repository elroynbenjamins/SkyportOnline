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
	var type_ids: Array[String] = []
	for offer_variant in offers:
		var typed_offer: Dictionary = offer_variant
		var type_id := String(typed_offer.get("contract_type_id", ""))
		if type_id.is_empty():
			_fail("Every Charter offer should expose a contract type.")
			return
		type_ids.append(type_id)
	if type_ids != ["standard", "express", "bulk"]:
		_fail("Day 200 should deterministically offer Standard, Express and Bulk contracts.")
		return

	# An idle board rotates daily and should expose a different mix of tradeoffs.
	var rotation_state := state.duplicate(true)
	var next_day := now + float(CharterRules.DAY_SECONDS)
	if not CharterRules.ensure_state(rotation_state, 22, next_day):
		_fail("An untouched Charter board should rotate on the next day.")
		return
	var rotated_offers: Array = (rotation_state.get("charter", {}) as Dictionary).get("offers", [])
	if rotated_offers.size() != CharterRules.OFFER_COUNT:
		_fail("Daily Charter rotation should still present three offers.")
		return
	var rotated_types: Array[String] = []
	for rotated_variant in rotated_offers:
		var rotated_offer: Dictionary = rotated_variant
		rotated_types.append(String(rotated_offer.get("contract_type_id", "")))
	if rotated_types != ["express", "bulk", "resource"]:
		_fail("Day 201 should rotate to Express, Bulk and Resource Priority.")
		return
	var resource_offer: Dictionary = rotated_offers[2]
	if int(resource_offer.get("resource_amount", 0)) != 2:
		_fail("Resource Priority should guarantee two country resources.")
		return
	var bulk_offer: Dictionary = rotated_offers[1]
	if int(bulk_offer.get("pallets", 0)) < 3:
		_fail("Bulk Haul should add meaningful pallet volume.")
		return
	var express_offer: Dictionary = rotated_offers[0]
	if int(express_offer.get("load_seconds", 999999)) >= int(express_offer.get("pallets", 1)) * CharterRules.LOAD_SECONDS_PER_PALLET:
		_fail("Express Freight should load faster than the standard per-pallet rate.")
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
	if String(active.get("contract_type_id", "")) != "standard":
		_fail("Accepted Charter should preserve its selected contract type.")
		return

	# Active contracts must not be replaced by the next daily board rotation.
	var active_next_day := accepted.duplicate(true)
	CharterRules.ensure_state(active_next_day, 22, next_day)
	var preserved_active: Dictionary = (active_next_day.get("charter", {}) as Dictionary).get("active", {})
	if String(preserved_active.get("id", "")) != String(active.get("id", "")):
		_fail("Daily board rotation must never replace an active Charter.")
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
	if String(reward.get("contract_type_name", "")).is_empty():
		_fail("Claim result should preserve the completed contract type for feedback.")
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
	var screen_snapshot := CharterRules.snapshot(
		next,
		22,
		true,
		true,
		float(complete_at + 1)
	)
	screen.open_screen(screen_snapshot)
	if not screen.is_open():
		_fail("Charter screen should open with the gameplay snapshot.")
		return
	if int(screen_snapshot.get("board_rotation_seconds", -1)) < 0:
		_fail("Charter snapshot should expose the idle board refresh timer.")
		return
	screen.close_screen()

	# Legacy active contracts gain neutral type metadata without changing rewards/timers.
	var legacy := {
		"airport_id": "legacy-charter",
		"charter": {
			"offers": [],
			"completed": 0,
			"serial": 2,
			"rotation_key": 200,
			"active": {
				"id": "legacy-active",
				"phase": "LOADING",
				"pallets": 2,
				"pallet_count": 0,
				"accepted_at": int(now),
				"depart_at": int(now) + 90,
				"complete_at": int(now) + 600,
				"coin_reward": 777,
				"xp_reward": 33
			}
		}
	}
	CharterRules.ensure_state(legacy, 22, now)
	var legacy_active: Dictionary = (legacy.get("charter", {}) as Dictionary).get("active", {})
	if String(legacy_active.get("contract_type_id", "")) != "standard":
		_fail("Legacy active Charter should migrate to neutral Standard Freight metadata.")
		return
	if int(legacy_active.get("coin_reward", 0)) != 777 or int(legacy_active.get("complete_at", 0)) != int(now) + 600:
		_fail("Legacy Charter migration must preserve reward and timing values.")
		return

	print("Cargo Charter gameplay passed: typed offers, daily rotation, active preservation, claim and legacy migration.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
