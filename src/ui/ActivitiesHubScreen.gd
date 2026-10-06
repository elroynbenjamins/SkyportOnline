class_name ActivitiesHubScreen
extends CanvasLayer

signal close_requested
signal mode_requested(mode_id: String)

var root: Control
var cards_grid: GridContainer
var summary_label: Label
var snapshot: Dictionary = {}

func _ready() -> void:
	layer = 37
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
	panel.offset_left = 34
	panel.offset_top = 28
	panel.offset_right = -34
	panel.offset_bottom = -28
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
	title.text = "ACTIVITIES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 24)
	title.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "GAME MODES • WEEKLY GOALS • LIMITED EVENTS"
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(subtitle)
	header.add_child(subtitle)

	var close := Button.new()
	close.text = "✕  AIRPORT"
	close.custom_minimum_size = Vector2(130, 42)
	GameUIStyle.apply_button(close, "secondary", true)
	close.pressed.connect(close_screen)
	header.add_child(close)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 13)
	column.add_child(summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	cards_grid = GridContainer.new()
	cards_grid.columns = 2
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.add_theme_constant_override("h_separation", 10)
	cards_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(cards_grid)

func _refresh() -> void:
	for child in cards_grid.get_children():
		child.queue_free()

	var ready := int(snapshot.get("attention_count", 0))
	summary_label.text = (
		"%d reward%s ready • choose an activity"
		% [ready, "" if ready == 1 else "s"]
		if ready > 0
		else "Choose a mode. Progress updates automatically from normal airport play."
	)
	summary_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD if ready > 0 else GameUIStyle.COLOR_MUTED
	)

	for id in ["missions", "charter", "challenge", "alliance", "event"]:
		var data: Dictionary = snapshot.get(id, {})
		_add_card(id, data)

func _add_card(mode_id: String, data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 150)
	GameUIStyle.apply_panel(
		card,
		"raised" if bool(data.get("attention", false)) else "dark"
	)
	cards_grid.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	box.add_child(heading_row)

	var title := Label.new()
	title.text = String(data.get("title", mode_id.capitalize()))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 17)
	heading_row.add_child(title)

	var badge := Label.new()
	badge.text = String(data.get("badge", "AVAILABLE"))
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
		if bool(data.get("attention", false))
		else GameUIStyle.COLOR_ACCENT
	)
	heading_row.add_child(badge)

	var status := Label.new()
	status.text = String(data.get("status", "Available"))
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_SUCCESS
		if bool(data.get("attention", false))
		else GameUIStyle.COLOR_TEXT
	)
	box.add_child(status)

	var detail := Label.new()
	detail.text = String(data.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(detail)
	box.add_child(detail)

	var open := Button.new()
	open.size_flags_vertical = Control.SIZE_SHRINK_END
	open.custom_minimum_size = Vector2(0, 40)
	var enabled := bool(data.get("enabled", true))
	open.disabled = not enabled
	open.text = (
		String(data.get("action", "OPEN"))
		if enabled
		else String(data.get("locked_action", "LOCKED"))
	)
	GameUIStyle.apply_button(
		open,
		"gold" if bool(data.get("attention", false)) and enabled
		else ("primary" if enabled else "secondary"),
		true
	)
	open.pressed.connect(
		func() -> void:
			mode_requested.emit(mode_id)
	)
	box.add_child(open)
