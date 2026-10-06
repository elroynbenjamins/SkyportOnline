class_name DispatchChallengeScreen
extends CanvasLayer

signal close_requested
signal start_requested
signal claim_requested

var root: Control
var state_label: Label
var timer_label: Label
var score_label: Label
var best_label: Label
var combo_label: Label
var stats_label: Label
var readiness_label: Label
var scoring_label: Label
var reward_list: VBoxContainer
var action_button: Button
var snapshot: Dictionary = {}

func _ready() -> void:
	layer = 39
	_build_ui()
	root.visible = false

func open_screen(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	_refresh()
	root.visible = true

func close_screen(silent: bool = false) -> void:
	if root != null:
		root.visible = false
	if not silent:
		close_requested.emit()

func is_open() -> bool:
	return root != null and root.visible

func set_snapshot(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	if is_open():
		_refresh()

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("07151d", 0.98)
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 42
	panel.offset_top = 34
	panel.offset_right = -42
	panel.offset_bottom = -34
	GameUIStyle.apply_panel(panel, "raised")
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var title := Label.new()
	title.text = "✦ AIRPORT DISPATCH"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 24)
	title.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	header.add_child(title)

	timer_label = Label.new()
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.muted(timer_label)
	header.add_child(timer_label)

	var close := Button.new()
	close.text = "✕  ACTIVITIES"
	close.custom_minimum_size = Vector2(140, 42)
	GameUIStyle.apply_button(close, "secondary", true)
	close.pressed.connect(close_screen)
	header.add_child(close)

	var score_panel := PanelContainer.new()
	GameUIStyle.apply_panel(score_panel, "dark")
	column.add_child(score_panel)
	var score_box := VBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_theme_constant_override("separation", 4)
	score_panel.add_child(score_box)

	state_label = Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", GameUIStyle.COLOR_ACCENT)
	score_box.add_child(state_label)

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(score_label, 30)
	score_box.add_child(score_label)

	best_label = Label.new()
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(best_label)
	score_box.add_child(best_label)

	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 13)
	combo_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	score_box.add_child(combo_label)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 13)
	column.add_child(stats_label)

	readiness_label = Label.new()
	readiness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readiness_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(readiness_label)
	column.add_child(readiness_label)

	scoring_label = Label.new()
	scoring_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scoring_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(scoring_label)
	column.add_child(scoring_label)

	var rewards_panel := PanelContainer.new()
	rewards_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(rewards_panel, "context")
	column.add_child(rewards_panel)

	var rewards_box := VBoxContainer.new()
	rewards_box.add_theme_constant_override("separation", 6)
	rewards_panel.add_child(rewards_box)

	var rewards_title := Label.new()
	rewards_title.text = "DAILY REWARD TRACK"
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(rewards_title, 16)
	rewards_box.add_child(rewards_title)

	reward_list = VBoxContainer.new()
	reward_list.add_theme_constant_override("separation", 6)
	rewards_box.add_child(reward_list)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(0, 50)
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)

func _refresh() -> void:
	var unlocked := bool(snapshot.get("unlocked", false))
	var status := String(snapshot.get("status", "IDLE"))
	var score := int(snapshot.get("score", 0))
	var combo := int(snapshot.get("combo_count", 0))
	var max_combo := int(snapshot.get("max_combo", 0))
	var combo_bonus := int(snapshot.get("combo_bonus", 0))
	var penalty_points := int(snapshot.get("penalty_points", 0))
	var points_to_next := int(snapshot.get("points_to_next_tier", 0))
	var next_tier_name := String(snapshot.get("next_tier_name", ""))

	score_label.text = "%d PTS" % score
	best_label.text = "BEST TODAY: %d" % int(snapshot.get("best_score", 0))
	readiness_label.visible = true

	if not unlocked:
		state_label.text = "LOCKED"
		timer_label.text = ""
		combo_label.text = ""
		stats_label.text = "Airport Dispatch unlocks at Level %d." % int(
			snapshot.get(
				"unlock_level",
				DispatchChallengeRules.UNLOCK_LEVEL
			)
		)
		readiness_label.text = (
			"Build your airport and learn the normal operations loop first."
		)
	elif status == "RUNNING":
		state_label.text = "LIVE SHIFT • KEEP TRAFFIC MOVING"
		timer_label.text = "%s LEFT" % _format_time(
			int(snapshot.get("remaining_seconds", 0))
		)
		combo_label.text = (
			"COMBO x%d • +%d COMBO PTS%s" % [
				combo,
				combo_bonus,
				(
					" • %d TO %s" % [
						points_to_next,
						next_tier_name.to_upper()
					]
					if points_to_next > 0
					else " • GOLD SECURED"
				)
			]
			if combo >= 2
			else (
				"%d TO %s • complete another clean operation within %ds to build a combo" % [
					points_to_next,
					next_tier_name.to_upper(),
					int(snapshot.get("combo_window_seconds", 30))
				]
				if points_to_next > 0
				else "GOLD SECURED • keep improving your best"
			)
		)
		stats_label.text = "%d turnarounds • %d departures • %d returns • %d visitors • %d taxi holds" % [
			int(snapshot.get("turnarounds", 0)),
			int(snapshot.get("departures", 0)),
			int(snapshot.get("returns", 0)),
			int(snapshot.get("visitor_services", 0)),
			int(snapshot.get("taxi_holds", 0))
		]
		readiness_label.text = (
			"Clean operations keep the combo alive. Any taxi hold breaks the streak."
		)
	elif status == "READY":
		var tier_name := String(snapshot.get("tier_name", ""))
		state_label.text = (
			"%s RESULT" % tier_name.to_upper()
			if not tier_name.is_empty()
			else "SHIFT COMPLETE • NO MEDAL"
		)
		timer_label.text = "SHIFT COMPLETE"
		combo_label.text = "MAX COMBO x%d • +%d COMBO PTS • −%d PENALTY PTS" % [
			max_combo,
			combo_bonus,
			penalty_points
		]
		stats_label.text = "%d turnarounds • %d departures • %d returns • %d visitors • %d taxi holds" % [
			int(snapshot.get("turnarounds", 0)),
			int(snapshot.get("departures", 0)),
			int(snapshot.get("returns", 0)),
			int(snapshot.get("visitor_services", 0)),
			int(snapshot.get("taxi_holds", 0))
		]
		readiness_label.text = (
			"Smooth shift" if penalty_points == 0
			else "%d points lost to congestion. Cleaner taxi flow will improve the next run." % penalty_points
		)
	else:
		state_label.text = "3-MINUTE LIVE OPERATIONS SHIFT"
		timer_label.text = ""
		combo_label.text = "CHAIN CLEAN OPERATIONS • COMBO BONUS UP TO +%d EACH" % int(
			snapshot.get("max_combo_bonus", 4)
		)
		stats_label.text = (
			"Operate your real airport for three minutes. Turn around owned aircraft, dispatch departures, handle returns and service visiting aircraft."
		)
		readiness_label.text = _readiness_text()

	var scoring: Dictionary = snapshot.get("scoring", {})
	scoring_label.text = (
		"SCORING  •  Turnaround +%d  •  Departure +%d  •  Return +%d  •  Visitor +%d  •  Taxi hold %d & breaks combo\n"
		+ "COMBO  •  each clean operation within %ds adds +1 / +2 / +3 / +4 bonus points"
	) % [
		int(scoring.get("turnaround", 5)),
		int(scoring.get("departure", 8)),
		int(scoring.get("return", 12)),
		int(scoring.get("visitor_service", 10)),
		int(scoring.get("taxi_hold", -4)),
		int(snapshot.get("combo_window_seconds", 30))
	]

	for child in reward_list.get_children():
		child.queue_free()
	for tier_variant in snapshot.get("tiers", []):
		var tier: Dictionary = tier_variant
		var row := Label.new()
		row.text = "%s • %d PTS • 🪙 %d • %d XP" % [
			String(tier.get("name", "Medal")),
			int(tier.get("target", 0)),
			int(tier.get("coins", 0)),
			int(tier.get("xp", 0))
		]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 13)
		if score >= int(tier.get("target", 0)):
			row.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_GOLD
			)
		else:
			GameUIStyle.muted(row)
		reward_list.add_child(row)

	action_button.disabled = false
	if not unlocked:
		action_button.text = "UNLOCKS AT LEVEL %d" % int(
			snapshot.get(
				"unlock_level",
				DispatchChallengeRules.UNLOCK_LEVEL
			)
		)
		action_button.disabled = true
		GameUIStyle.apply_button(action_button, "secondary", true)
	elif status == "RUNNING":
		action_button.text = "RETURN TO AIRPORT • KEEP DISPATCHING"
		GameUIStyle.apply_button(action_button, "primary")
	elif status == "READY":
		action_button.text = (
			"CLAIM RESULT"
			if bool(snapshot.get("reward_available", false))
			else "FINISH SHIFT"
		)
		GameUIStyle.apply_button(
			action_button,
			"gold"
			if bool(snapshot.get("reward_available", false))
			else "primary"
		)
	else:
		action_button.text = (
			"START PRACTICE SHIFT"
			if bool(snapshot.get("reward_claimed", false))
			else "START DAILY DISPATCH SHIFT"
		)
		GameUIStyle.apply_button(action_button, "gold")


func _readiness_text() -> String:
	var aircraft := int(snapshot.get("airport_aircraft", 0))
	var at_stand := int(snapshot.get("airport_at_stand", 0))
	var passengers := int(snapshot.get("passenger_stock", 0))
	var capacity := int(snapshot.get("passenger_capacity", 0))
	var runway_queue := int(snapshot.get("runway_queue", 0))
	var ground_queue := int(snapshot.get("ground_queue", 0))
	var inbound := int(snapshot.get("inbound_holding", 0))

	var warning := ""
	if aircraft <= 0:
		warning = " • WARNING: no operational aircraft deployed"
	elif passengers < 20:
		warning = " • LOW PASSENGER STOCK"
	elif runway_queue + ground_queue + inbound >= 3:
		warning = " • AIRPORT ALREADY CONGESTED"

	return "CURRENT AIRPORT • %d aircraft • %d at stands • passengers %d/%d • runway queue %d • service queue %d • inbound %d%s" % [
		aircraft,
		at_stand,
		passengers,
		capacity,
		runway_queue,
		ground_queue,
		inbound,
		warning
	]

func _on_action_pressed() -> void:
	var status := String(snapshot.get("status", "IDLE"))
	if status == "RUNNING":
		close_screen(true)
	elif status == "READY":
		claim_requested.emit()
	else:
		start_requested.emit()

func _format_time(seconds: int) -> String:
	var total := maxi(seconds, 0)
	return "%d:%02d" % [int(total / 60), total % 60]
