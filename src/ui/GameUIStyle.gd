class_name GameUIStyle
extends RefCounted

const COLOR_BG := Color("07151d")
const COLOR_BG_SOFT := Color("0b202b")
const COLOR_PANEL := Color("102b38")
const COLOR_PANEL_RAISED := Color("173846")
const COLOR_PANEL_DARK := Color("0b222d")
const COLOR_BORDER := Color("3a6676")
const COLOR_BORDER_SOFT := Color("274b59")
const COLOR_TEXT := Color("f3f7f8")
const COLOR_MUTED := Color("9fb8c1")
const COLOR_ACCENT := Color("62c7dd")
const COLOR_ACCENT_DARK := Color("23798d")
const COLOR_GOLD := Color("f1c45e")
const COLOR_GOLD_DARK := Color("a9782d")
const COLOR_SUCCESS := Color("82d9a5")
const COLOR_WARNING := Color("ffc66a")
const COLOR_DANGER := Color("ff7d75")
const COLOR_EVENT := Color("d97833")


static func panel(
	background: Color = COLOR_PANEL,
	border: Color = COLOR_BORDER,
	radius: int = 12,
	border_width: int = 1,
	shadow: bool = true
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0

	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.26)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)

	return style


static func top_bar() -> StyleBoxFlat:
	return panel(
		Color("102e3b", 0.96),
		Color("4b7b8b"),
		14,
		1,
		true
	)


static func card(active: bool = false) -> StyleBoxFlat:
	if active:
		return panel(
			Color("183d4a"),
			COLOR_ACCENT,
			10,
			2,
			false
		)
	return panel(
		Color("102a35"),
		Color("315766"),
		10,
		1,
		false
	)


static func gold_card() -> StyleBoxFlat:
	return panel(
		Color("3a3020"),
		COLOR_GOLD,
		10,
		2,
		false
	)


static func event_card() -> StyleBoxFlat:
	return panel(
		Color("3a2419"),
		COLOR_EVENT,
		10,
		2,
		false
	)


static func apply_panel(
	control: PanelContainer,
	variant: String = "panel"
) -> void:
	if control == null:
		return

	match variant:
		"top":
			control.add_theme_stylebox_override("panel", top_bar())
		"hud_top":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("0b2531", 0.98), Color("4d7a89"), 15, 1, true)
			)
		"hud_level":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("302919"), COLOR_GOLD, 12, 1, false)
			)
		"hud_passenger":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("102f3a"), Color("58b9cf"), 12, 1, false)
			)
		"hud_coin":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("342c18"), COLOR_GOLD_DARK, 12, 1, false)
			)
		"hud_premium":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("2a2038"), Color("a884d6"), 12, 1, false)
			)
		"dock":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("081b24", 0.98), Color("365a68"), 16, 1, true)
			)
		"context":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("0c2733", 0.985), Color("62a7ba"), 14, 2, true)
			)
		"context_preview":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("081c25"), Color("2e5c6b"), 10, 1, false)
			)
		"screen_top":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("0b2935", 0.99), Color("4b8191"), 15, 1, true)
			)
		"screen_section":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("0b222c", 0.985), Color("315866"), 13, 1, false)
			)
		"screen_focus":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("102f3b", 0.99), Color("62c7dd"), 14, 2, true)
			)
		"reward_tile":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("122c35"), Color("4d7988"), 11, 1, false)
			)
		"toast_success":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("123328", 0.98), COLOR_SUCCESS, 12, 2, true)
			)
		"toast_warning":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("3a2e18", 0.98), COLOR_WARNING, 12, 2, true)
			)
		"toast_danger":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("3a2022", 0.98), COLOR_DANGER, 12, 2, true)
			)
		"raised":
			control.add_theme_stylebox_override(
				"panel",
				panel(COLOR_PANEL_RAISED, COLOR_BORDER, 12, 1, true)
			)
		"dark":
			control.add_theme_stylebox_override(
				"panel",
				panel(COLOR_PANEL_DARK, COLOR_BORDER_SOFT, 12, 1, false)
			)
		"gold":
			control.add_theme_stylebox_override("panel", gold_card())
		"event":
			control.add_theme_stylebox_override("panel", event_card())
		_:
			control.add_theme_stylebox_override("panel", panel())


static func apply_button(
	button: Button,
	kind: String = "secondary",
	compact: bool = false
) -> void:
	if button == null:
		return
	var style_key := kind + (":compact" if compact else ":full")
	if String(button.get_meta("game_style_key", "")) == style_key:
		return
	button.set_meta("game_style_key", style_key)

	var normal_bg := Color("173643")
	var normal_border := Color("3c6574")
	var hover_bg := Color("1d4656")
	var pressed_bg := Color("102a35")
	var pressed_border := COLOR_ACCENT
	var text_color := COLOR_TEXT

	match kind:
		"primary":
			normal_bg = Color("2b8094")
			normal_border = Color("6bd2e6")
			hover_bg = Color("3598ae")
			pressed_bg = Color("226c7e")
			pressed_border = Color("a3e9f5")
		"gold":
			normal_bg = Color("a56d27")
			normal_border = COLOR_GOLD
			hover_bg = Color("bf8131")
			pressed_bg = Color("80531f")
			pressed_border = Color("ffe59b")
		"danger":
			normal_bg = Color("743b3d")
			normal_border = Color("c96a6d")
			hover_bg = Color("8d474a")
			pressed_bg = Color("5a2e31")
			pressed_border = COLOR_DANGER
		"nav":
			normal_bg = Color("102b37")
			normal_border = Color("284c59")
			hover_bg = Color("183d4b")
			pressed_bg = Color("1b4b5c")
			pressed_border = COLOR_ACCENT
		"selected":
			normal_bg = Color("1d4d5c")
			normal_border = COLOR_ACCENT
			hover_bg = Color("245e70")
			pressed_bg = Color("173d4a")
			pressed_border = Color("9ce6f3")
		"event":
			normal_bg = Color("7c421f")
			normal_border = COLOR_EVENT
			hover_bg = Color("985126")
			pressed_bg = Color("603319")
			pressed_border = Color("ffb36a")
		"dock":
			normal_bg = Color("0d2631")
			normal_border = Color("294d5a")
			hover_bg = Color("143743")
			pressed_bg = Color("183f4d")
			pressed_border = COLOR_ACCENT
		"dock_selected":
			normal_bg = Color("1d5667")
			normal_border = Color("79d6e8")
			hover_bg = Color("246a7d")
			pressed_bg = Color("194b5a")
			pressed_border = Color("b5f1fb")
		"build_card":
			normal_bg = Color("112c37")
			normal_border = Color("315966")
			hover_bg = Color("183d49")
			pressed_bg = Color("1c4b59")
			pressed_border = COLOR_ACCENT
		"build_card_selected":
			normal_bg = Color("184653")
			normal_border = Color("72d0e2")
			hover_bg = Color("205967")
			pressed_bg = Color("153d48")
			pressed_border = Color("b4eff8")
		"build_card_locked":
			normal_bg = Color("18242a")
			normal_border = Color("34464d")
			hover_bg = Color("18242a")
			pressed_bg = Color("18242a")
			pressed_border = Color("34464d")
		"screen_tab":
			normal_bg = Color("0d2631")
			normal_border = Color("2b4d59")
			hover_bg = Color("173b48")
			pressed_bg = Color("194653")
			pressed_border = COLOR_ACCENT
		"screen_tab_selected":
			normal_bg = Color("1a5363")
			normal_border = Color("78d5e7")
			hover_bg = Color("216779")
			pressed_bg = Color("174754")
			pressed_border = Color("b6f1fb")
		"mission_complete":
			normal_bg = Color("183a2d")
			normal_border = COLOR_SUCCESS
			hover_bg = Color("204a39")
			pressed_bg = Color("143126")
			pressed_border = Color("a8efc1")

	var radius := 10 if compact else 12
	button.add_theme_stylebox_override(
		"normal",
		panel(normal_bg, normal_border, radius, 1, false)
	)
	button.add_theme_stylebox_override(
		"hover",
		panel(hover_bg, normal_border, radius, 2, false)
	)
	button.add_theme_stylebox_override(
		"pressed",
		panel(pressed_bg, pressed_border, radius, 2, false)
	)
	var disabled_bg := Color("16252c")
	var disabled_border := Color("2b3d44")
	if kind == "build_card_locked":
		disabled_bg = Color("131e24")
		disabled_border = Color("41525a")
	button.add_theme_stylebox_override(
		"disabled",
		panel(
			disabled_bg,
			disabled_border,
			radius,
			1,
			false
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		panel(Color(0, 0, 0, 0), COLOR_ACCENT, radius, 2, false)
	)

	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override(
		"font_disabled_color",
		Color("6f858c")
	)
	button.add_theme_font_size_override(
		"font_size",
		13 if compact else 15
	)


static func apply_progress(progress: ProgressBar, gold: bool = false) -> void:
	if progress == null:
		return

	progress.add_theme_stylebox_override(
		"background",
		panel(
			Color("091a22"),
			Color("294551"),
			8,
			1,
			false
		)
	)

	var fill_color := COLOR_GOLD if gold else COLOR_ACCENT
	progress.add_theme_stylebox_override(
		"fill",
		panel(
			fill_color,
			fill_color.lightened(0.18),
			8,
			0,
			false
		)
	)


static func apply_input(input: LineEdit) -> void:
	if input == null:
		return

	input.add_theme_stylebox_override(
		"normal",
		panel(
			Color("0b2029"),
			Color("375d6b"),
			10,
			1,
			false
		)
	)
	input.add_theme_stylebox_override(
		"focus",
		panel(
			Color("0e2630"),
			COLOR_ACCENT,
			10,
			2,
			false
		)
	)
	input.add_theme_color_override("font_color", COLOR_TEXT)
	input.add_theme_color_override(
		"font_placeholder_color",
		Color("6f8b95")
	)


static func heading(label: Label, size: int = 20) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_TEXT)


static func muted(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", COLOR_MUTED)
