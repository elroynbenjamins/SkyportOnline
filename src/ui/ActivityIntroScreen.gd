class_name ActivityIntroScreen
extends CanvasLayer

signal continue_requested(mode_id: String)
signal close_requested

var root: Control
var title_label: Label
var mentor_label: Label
var intro_label: Label
var tip_label: Label
var continue_button: Button
var mode_id := ""

func _ready() -> void:
	layer = 46
	_build_ui()
	root.visible = false

func open_intro(id: String, definition: Dictionary) -> void:
	mode_id = id
	title_label.text = String(
		definition.get("title", "New Activity")
	).to_upper()
	mentor_label.text = "INTRODUCED BY %s" % String(
		definition.get("mentor", "Airport Operations")
	).to_upper()
	intro_label.text = String(definition.get("intro", ""))
	tip_label.text = "FIRST TIP • %s" % String(
		definition.get("tip", "")
	)
	root.visible = true

func close_intro(silent: bool = false) -> void:
	root.visible = false
	if not silent:
		close_requested.emit()

func is_open() -> bool:
	return root != null and root.visible

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("061017", 0.96)
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(650, 390)
	panel.position = Vector2(-325, -195)
	GameUIStyle.apply_panel(panel, "raised")
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "NEW AIRPORT ACTIVITY"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	column.add_child(eyebrow)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(title_label, 25)
	column.add_child(title_label)

	mentor_label = Label.new()
	mentor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mentor_label.add_theme_font_size_override("font_size", 11)
	GameUIStyle.muted(mentor_label)
	column.add_child(mentor_label)

	intro_label = Label.new()
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.add_theme_font_size_override("font_size", 15)
	column.add_child(intro_label)

	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 13)
	tip_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	column.add_child(tip_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)

	var later := Button.new()
	later.text = "NOT NOW"
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.custom_minimum_size = Vector2(0, 48)
	GameUIStyle.apply_button(later, "secondary", true)
	later.pressed.connect(close_intro)
	actions.add_child(later)

	continue_button = Button.new()
	continue_button.text = "SHOW ME"
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.custom_minimum_size = Vector2(0, 48)
	GameUIStyle.apply_button(continue_button, "gold")
	continue_button.pressed.connect(
		func() -> void:
			root.visible = false
			continue_requested.emit(mode_id)
	)
	actions.add_child(continue_button)
