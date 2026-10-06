class_name AirportChallengeScreen
extends CanvasLayer

signal close_requested
signal claim_requested(milestone_id: String)

var root: Control
var timer_label: Label
var score_label: Label
var summary_label: Label
var progress_label: Label
var milestone_list: VBoxContainer
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
	panel.offset_left = 36
	panel.offset_top = 30
	panel.offset_right = -36
	panel.offset_bottom = -30
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
	title.text = "★ WEEKLY AIRPORT CHALLENGE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 24)
	title.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	header.add_child(title)

	timer_label = Label.new()
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.muted(timer_label)
	header.add_child(timer_label)

	var close := Button.new()
	close.text = "✕  AIRPORT"
	close.custom_minimum_size = Vector2(130, 42)
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

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(score_label, 28)
	score_box.add_child(score_label)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(progress_label)
	score_box.add_child(progress_label)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 13)
	score_box.add_child(summary_label)

	var help := Label.new()
	help.text = "Score points by completing normal passenger flights. Longer routes, fuller aircraft, country resources and first visits to new countries score more."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(help)
	column.add_child(help)

	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(list_panel, "context")
	column.add_child(list_panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 7)
	list_panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = "WEEKLY REWARD TRACK"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 16)
	wrapper.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(scroll)

	milestone_list = VBoxContainer.new()
	milestone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milestone_list.add_theme_constant_override("separation", 7)
	scroll.add_child(milestone_list)

func _refresh() -> void:
	var unlocked := bool(snapshot.get("unlocked", false))
	timer_label.text = "RESET IN %s" % _format_time(int(snapshot.get("seconds_remaining", 0)))
	if not unlocked:
		score_label.text = "LOCKED"
		progress_label.text = "Unlocks at Airport Level %d" % int(snapshot.get("unlock_level", AirportChallengeRules.UNLOCK_LEVEL))
		summary_label.text = "Keep growing your airport to enter the weekly challenge."
	else:
		var score := int(snapshot.get("score", 0))
		score_label.text = "%d PTS" % score
		var next_target := int(snapshot.get("next_target", 0))
		progress_label.text = "All weekly milestones complete" if next_target <= 0 else "%d points to next reward" % maxi(next_target - score, 0)
		summary_label.text = "%d flights • %d passengers • %d km • %d countries • %d resources" % [
			int(snapshot.get("flights", 0)),
			int(snapshot.get("passengers", 0)),
			int(snapshot.get("distance_km", 0)),
			int(snapshot.get("countries", 0)),
			int(snapshot.get("resources", 0))
		]

	for child in milestone_list.get_children():
		child.queue_free()
	for milestone_variant in snapshot.get("milestones", []):
		_add_milestone(milestone_variant, unlocked)

func _add_milestone(milestone: Dictionary, unlocked: bool) -> void:
	var card := PanelContainer.new()
	GameUIStyle.apply_panel(card, "dark")
	milestone_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.text = "%s • %d PTS" % [String(milestone.get("name", "Milestone")), int(milestone.get("target", 0))]
	GameUIStyle.heading(title, 15)
	text_box.add_child(title)

	var details := Label.new()
	var aero := int(milestone.get("aero", 0))
	details.text = "🪙 %d • %d XP%s" % [
		int(milestone.get("coins", 0)),
		int(milestone.get("xp", 0)),
		" • %d Aero" % aero if aero > 0 else ""
	]
	details.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(details)
	text_box.add_child(details)

	var claim := Button.new()
	claim.custom_minimum_size = Vector2(140, 48)
	if bool(milestone.get("claimed", false)):
		claim.text = "CLAIMED"
		claim.disabled = true
		GameUIStyle.apply_button(claim, "secondary", true)
	elif unlocked and bool(milestone.get("claimable", false)):
		claim.text = "CLAIM"
		GameUIStyle.apply_button(claim, "gold")
	else:
		claim.text = "IN PROGRESS"
		claim.disabled = true
		GameUIStyle.apply_button(claim, "secondary", true)
	claim.pressed.connect(func() -> void: claim_requested.emit(String(milestone.get("id", ""))))
	row.add_child(claim)

func _format_time(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var days := int(total / 86400)
	var hours := int((total % 86400) / 3600)
	if days > 0:
		return "%dd %02dh" % [days, hours]
	var minutes := int((total % 3600) / 60)
	return "%dh %02dm" % [hours, minutes]
