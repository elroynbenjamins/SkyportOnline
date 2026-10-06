class_name AllianceOperationsScreen
extends CanvasLayer

signal close_requested
signal claim_requested(milestone_id: String)

var root: Control
var network_label: Label
var timer_label: Label
var personal_label: Label
var total_label: Label
var contribution_label: Label
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
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
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
	title.text = "◆ ALLIANCE OPERATIONS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 24)
	title.add_theme_color_override("font_color", GameUIStyle.COLOR_EVENT)
	header.add_child(title)

	timer_label = Label.new()
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.muted(timer_label)
	header.add_child(timer_label)

	var close := Button.new()
	close.text = "✕  SOCIAL"
	close.custom_minimum_size = Vector2(130, 42)
	GameUIStyle.apply_button(close, "secondary", true)
	close.pressed.connect(close_screen)
	header.add_child(close)

	network_label = Label.new()
	network_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	network_label.add_theme_font_size_override("font_size", 13)
	column.add_child(network_label)

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 10)
	column.add_child(score_row)

	personal_label = _score_card(score_row, "YOUR CONTRIBUTION")
	total_label = _score_card(score_row, "ALLIANCE TOTAL")

	var help_panel := PanelContainer.new()
	GameUIStyle.apply_panel(help_panel, "dark")
	column.add_child(help_panel)
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 3)
	help_panel.add_child(help_box)

	var help := Label.new()
	help.text = "WEEKLY AIRBRIDGE PROJECT"
	GameUIStyle.heading(help, 15)
	help_box.add_child(help)

	contribution_label = Label.new()
	contribution_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contribution_label.add_theme_font_size_override("font_size", 13)
	help_box.add_child(contribution_label)

	var milestone_panel := PanelContainer.new()
	milestone_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(milestone_panel, "context")
	column.add_child(milestone_panel)

	var milestone_wrapper := VBoxContainer.new()
	milestone_wrapper.add_theme_constant_override("separation", 7)
	milestone_panel.add_child(milestone_wrapper)

	var milestone_title := Label.new()
	milestone_title.text = "ALLIANCE MILESTONES"
	milestone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(milestone_title, 16)
	milestone_wrapper.add_child(milestone_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milestone_wrapper.add_child(scroll)

	milestone_list = VBoxContainer.new()
	milestone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milestone_list.add_theme_constant_override("separation", 7)
	scroll.add_child(milestone_list)

func _score_card(parent: HBoxContainer, caption: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(panel, "dark")
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title := Label.new()
	title.text = caption
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.muted(title)
	box.add_child(title)
	var value := Label.new()
	value.text = "0 PTS"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(value, 22)
	box.add_child(value)
	return value

func _refresh() -> void:
	var online := bool(snapshot.get("provider_connected", false))
	var local := bool(snapshot.get("local_simulation", false))
	if online:
		network_label.text = "● Online alliance totals are connected. Your contribution and alliance-wide progress both count."
		network_label.add_theme_color_override("font_color", GameUIStyle.COLOR_SUCCESS)
	elif local:
		network_label.text = "◌ Local test network: alliance total currently mirrors your own contribution until the online provider is connected."
		network_label.add_theme_color_override("font_color", GameUIStyle.COLOR_WARNING)
	else:
		network_label.text = "○ Alliance network offline. Personal contribution is still saved locally."
		GameUIStyle.muted(network_label)

	timer_label.text = "RESET IN %s" % _format_time(int(snapshot.get("seconds_remaining", 0)))
	personal_label.text = "%d PTS" % int(snapshot.get("personal_points", 0))
	total_label.text = "%d PTS" % int(snapshot.get("alliance_total", 0))

	var contributions: Dictionary = snapshot.get("contributions", {})
	contribution_label.text = (
		"Complete flights +1 • service alliance aircraft +3 • send alliance passenger support +1\n"
		+ "This week: %d flights • %d alliance visitors • %d support gifts"
	) % [
		int(contributions.get("flight", 0)),
		int(contributions.get("alliance_visit", 0)),
		int(contributions.get("alliance_gift", 0))
	]

	for child in milestone_list.get_children():
		child.queue_free()
	for milestone_variant in snapshot.get("milestones", []):
		_add_milestone(milestone_variant)

func _add_milestone(milestone: Dictionary) -> void:
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
	title.text = String(milestone.get("name", "Alliance milestone"))
	GameUIStyle.heading(title, 15)
	text_box.add_child(title)

	var details := Label.new()
	details.text = "Alliance %d pts • you %d pts • reward 🪙 %d + %d XP" % [
		int(milestone.get("target", 0)),
		int(milestone.get("personal_required", 0)),
		int(milestone.get("coins", 0)),
		int(milestone.get("xp", 0))
	]
	details.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(details)
	text_box.add_child(details)

	var claim := Button.new()
	claim.custom_minimum_size = Vector2(138, 48)
	if bool(milestone.get("claimed", false)):
		claim.text = "CLAIMED"
		claim.disabled = true
		GameUIStyle.apply_button(claim, "secondary", true)
	elif bool(milestone.get("claimable", false)):
		claim.text = "CLAIM"
		GameUIStyle.apply_button(claim, "gold")
	else:
		claim.text = "IN PROGRESS"
		claim.disabled = true
		GameUIStyle.apply_button(claim, "secondary", true)
	claim.pressed.connect(
		func() -> void:
			claim_requested.emit(String(milestone.get("id", "")))
	)
	row.add_child(claim)

func _format_time(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var days := int(total / 86400)
	var hours := int((total % 86400) / 3600)
	if days > 0:
		return "%dd %dh" % [days, hours]
	return "%dh" % hours
