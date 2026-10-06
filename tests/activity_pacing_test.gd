extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Keep the progression order intentional and stable.
	if ActivityProgressionRules.unlock_level("missions") != 1:
		_fail("Missions should be available from level 1.")
		return
	if ActivityProgressionRules.unlock_level("event") != 4:
		_fail("Seasonal Events should unlock at level 4.")
		return
	if ActivityProgressionRules.unlock_level("dispatch") != 8:
		_fail("Airport Dispatch should unlock at level 8.")
		return
	if ActivityProgressionRules.unlock_level("challenge") != 12:
		_fail("Weekly Airport Challenge should unlock at level 12.")
		return
	if ActivityProgressionRules.unlock_level("alliance") != 15:
		_fail("Alliance Operations should unlock at level 15.")
		return
	if ActivityProgressionRules.unlock_level("charter") != 22:
		_fail("Cargo Charter should remain the late level-22 activity.")
		return
	if DispatchChallengeRules.UNLOCK_LEVEL != 8:
		_fail("Dispatch gameplay gate should match the shared progression rules.")
		return
	if AirportChallengeRules.UNLOCK_LEVEL != 12:
		_fail("Weekly Challenge gameplay gate should match the shared progression rules.")
		return

	var state := AirportProgressionRules.new_state(
		"activity-pacing-test",
		1
	)
	if not ActivityProgressionRules.is_newly_unlocked(
		state,
		"missions",
		1
	):
		_fail("Fresh airport should mark Missions as a new activity.")
		return
	if ActivityProgressionRules.is_newly_unlocked(
		state,
		"dispatch",
		7
	):
		_fail("Dispatch must not become NEW before its level gate.")
		return
	if not ActivityProgressionRules.is_newly_unlocked(
		state,
		"dispatch",
		8
	):
		_fail("Dispatch should become NEW at level 8.")
		return
	if not ActivityProgressionRules.mark_tutorial_seen(
		state,
		"dispatch"
	):
		_fail("First Dispatch introduction should persist as seen.")
		return
	if ActivityProgressionRules.mark_tutorial_seen(
		state,
		"dispatch"
	):
		_fail("Activity introduction persistence should be idempotent.")
		return
	if ActivityProgressionRules.is_newly_unlocked(
		state,
		"dispatch",
		8
	):
		_fail("Seen Dispatch introduction should clear its NEW state.")
		return

	var intro := ActivityIntroScreen.new()
	root.add_child(intro)
	await process_frame
	var continued := {"mode": ""}
	intro.continue_requested.connect(
		func(mode_id: String) -> void:
			continued["mode"] = mode_id
	)
	intro.open_intro(
		"challenge",
		ActivityProgressionRules.definition("challenge")
	)
	if not intro.is_open():
		_fail("Reusable activity introduction should open.")
		return
	if not intro.title_label.text.contains(
		"WEEKLY AIRPORT CHALLENGE"
	):
		_fail("Activity introduction should show the selected mode title.")
		return
	if not intro.tip_label.text.contains("FIRST TIP"):
		_fail("Activity introduction should provide concise first-use guidance.")
		return
	intro.continue_button.pressed.emit()
	await process_frame
	if String(continued.get("mode", "")) != "challenge":
		_fail("Activity introduction should continue into the selected mode.")
		return
	if intro.is_open():
		_fail("Activity introduction should close after continuing.")
		return

	var hub := ActivitiesHubScreen.new()
	root.add_child(hub)
	await process_frame
	hub.open_screen({
		"attention_count": 1,
		"new_count": 1,
		"missions": {
			"title": "MISSIONS & PASS",
			"badge": "DAILY / WEEKLY",
			"status": "DAILY 0 / 4",
			"detail": "Mission detail",
			"attention": false,
			"new": false,
			"enabled": true,
			"action": "OPEN MISSIONS"
		},
		"event": {
			"title": "SEASONAL EVENT",
			"badge": "LIMITED TIME",
			"status": "NO EVENT ACTIVE",
			"detail": "Event detail",
			"attention": false,
			"new": false,
			"enabled": false,
			"locked_action": "INACTIVE"
		},
		"dispatch": {
			"title": "AIRPORT DISPATCH",
			"badge": "3-MINUTE LIVE SHIFT",
			"status": "READY",
			"detail": "Dispatch detail",
			"attention": false,
			"new": true,
			"enabled": true,
			"action": "OPEN DISPATCH"
		},
		"challenge": {
			"title": "WEEKLY AIRPORT CHALLENGE",
			"badge": "SOLO WEEKLY",
			"status": "REWARD READY",
			"detail": "Challenge detail",
			"attention": true,
			"new": false,
			"enabled": true,
			"action": "OPEN CHALLENGE"
		},
		"alliance": {
			"title": "ALLIANCE OPERATIONS",
			"badge": "CO-OP WEEKLY",
			"status": "UNLOCKS AT LEVEL 15",
			"detail": "Alliance detail",
			"attention": false,
			"new": false,
			"enabled": false,
			"locked_action": "LEVEL 15"
		},
		"charter": {
			"title": "CARGO CHARTER",
			"badge": "LOGISTICS",
			"status": "UNLOCKS AT LEVEL 22",
			"detail": "Charter detail",
			"attention": false,
			"new": false,
			"enabled": false,
			"locked_action": "LEVEL 22"
		}
	})
	if not hub.summary_label.text.contains("1 new activity"):
		_fail("Activities summary should distinguish newly unlocked modes.")
		return
	var found_intro_button := false
	for card in hub.cards_grid.get_children():
		for margin in card.get_children():
			for box in margin.get_children():
				for child in box.get_children():
					if (
						child is Button
						and String(child.text) == "INTRODUCE MODE"
					):
						found_intro_button = true
	if not found_intro_button:
		_fail("NEW activity card should invite the first-time introduction.")
		return
	hub.close_screen(true)

	var career_state := AirportProgressionRules.new_state(
		"career-activity-integration",
		22
	)
	var claimed_all: Dictionary = {}
	for quest_variant in AirportCareerCatalog.all():
		var career_quest: Dictionary = quest_variant
		claimed_all[String(career_quest.get("id", ""))] = true
	career_state["claimed"] = claimed_all
	var career := AirportCareerScreen.new()
	root.add_child(career)
	await process_frame
	var career_activity := {"mode": ""}
	career.activity_requested.connect(
		func(mode_id: String) -> void:
			career_activity["mode"] = mode_id
	)
	career.open_screen({
		"state": career_state,
		"airport": {
			"buildings": [],
			"parcels": [],
			"medium_ready": true
		},
		"level": 22,
		"active_owned": [],
		"npc_enabled": true,
		"activities": {
			"missions": {"new": false, "enabled": true},
			"event": {"new": false, "enabled": false},
			"dispatch": {"new": true, "enabled": true},
			"challenge": {"new": false, "enabled": true},
			"alliance": {"new": false, "enabled": false},
			"charter": {"new": false, "enabled": true}
		}
	})
	var introduce_dispatch := _find_button(
		career,
		"INTRODUCE • AIRPORT DISPATCH"
	)
	if introduce_dispatch == null:
		_fail(
			"Completed Career should still surface a direct shortcut to a newly unlocked Activity."
		)
		return
	introduce_dispatch.pressed.emit()
	await process_frame
	if String(career_activity.get("mode", "")) != "dispatch":
		_fail(
			"Career Activity shortcut should emit the selected mode id."
		)
		return
	career.close_screen()

	var social := SocialAirportScreen.new()
	root.add_child(social)
	await process_frame
	var social_snapshot := {
		"provider_connected": false,
		"local_simulation": true,
		"active_visits": [],
		"recent_completed": [],
		"social_state": {},
		"incoming_gift_status": {
			"received": 0,
			"cap": 3
		},
		"contacts": [
			{
				"id": "alliance-test",
				"display_name": "Alliance Test",
				"airport_code": "ALT",
				"airport_name": "Alliance Airport",
				"country_id": "NL",
				"relationship": "alliance"
			}
		],
		"alliance_operations_level": 15,
		"alliance_operations_level_unlocked": false
	}
	social.open_screen(social_snapshot)
	if not social.alliance_ops_button.disabled:
		_fail("Social Alliance Operations shortcut should be disabled before level 15.")
		return
	if not social.alliance_ops_button.text.contains("LV 15"):
		_fail("Locked Social Alliance shortcut should show the level requirement.")
		return
	social_snapshot["alliance_operations_level_unlocked"] = true
	social.set_snapshot(social_snapshot)
	if social.alliance_ops_button.disabled:
		_fail("Alliance shortcut should enable after level 15 when an Alliance contact exists.")
		return

	print("Activities pacing passed: staged levels, NEW persistence, intro UI, hub state and Alliance shortcut gate.")
	quit(0)


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and String((node as Button).text) == text_value:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
