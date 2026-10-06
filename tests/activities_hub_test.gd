extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame

	for required in ["build", "fleet", "world", "activities", "social", "more"]:
		if not hud.nav_buttons.has(required):
			_fail("Bottom navigation is missing %s after Activities consolidation." % required)
			return
	for removed in ["charter", "challenge", "event"]:
		if hud.nav_buttons.has(removed):
			_fail("%s should live inside Activities instead of the permanent bottom navigation." % removed)
			return

	hud.set_mission_activity_attention(true)
	if hud.activities_nav_button == null or "•" not in hud.activities_nav_button.text:
		_fail("Activities navigation should show attention when a mode reward is ready.")
		return
	hud.set_mission_activity_attention(false)

	var screen := ActivitiesHubScreen.new()
	root.add_child(screen)
	await process_frame
	var snapshot := {
		"attention_count": 2,
		"missions": {
			"title": "MISSIONS & PASS", "badge": "DAILY / WEEKLY",
			"status": "1 REWARD READY", "detail": "Mission detail",
			"attention": true, "enabled": true, "action": "OPEN MISSIONS"
		},
		"charter": {
			"title": "CARGO CHARTER", "badge": "LOGISTICS",
			"status": "3 CONTRACTS AVAILABLE", "detail": "Charter detail",
			"attention": false, "enabled": true, "action": "OPEN CHARTER"
		},
		"challenge": {
			"title": "WEEKLY AIRPORT CHALLENGE", "badge": "SOLO WEEKLY",
			"status": "55 PTS THIS WEEK", "detail": "Challenge detail",
			"attention": true, "enabled": true, "action": "OPEN CHALLENGE"
		},
		"alliance": {
			"title": "ALLIANCE OPERATIONS", "badge": "CO-OP WEEKLY",
			"status": "25 ALLIANCE PTS", "detail": "Alliance detail",
			"attention": false, "enabled": true, "action": "OPEN ALLIANCE OPS"
		},
		"event": {
			"title": "SEASONAL EVENT", "badge": "LIMITED TIME",
			"status": "NO EVENT ACTIVE", "detail": "Event detail",
			"attention": false, "enabled": false, "locked_action": "INACTIVE"
		}
	}
	screen.open_screen(snapshot)
	if not screen.is_open():
		_fail("Activities hub should open with a game-mode snapshot.")
		return
	if screen.cards_grid.get_child_count() != 5:
		_fail("Activities hub should render exactly five current activity cards.")
		return
	if "2 rewards ready" not in screen.summary_label.text:
		_fail("Activities hub should surface aggregate reward attention.")
		return

	screen.close_screen(true)
	if screen.is_open():
		_fail("Activities hub should support silent navigation close.")
		return

	print("Activities hub passed: consolidated nav, attention state and five mode cards.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
