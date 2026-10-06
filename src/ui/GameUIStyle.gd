class_name GameUIStyle
extends RefCounted

const COLOR_BG := Color("041521")
const COLOR_BG_SOFT := Color("07283b")
const COLOR_PANEL := Color("07334b")
const COLOR_PANEL_RAISED := Color("0a3b57")
const COLOR_PANEL_DARK := Color("061f30")
const COLOR_BORDER := Color("168fbd")
const COLOR_BORDER_SOFT := Color("155a78")
const COLOR_TEXT := Color("f8fcff")
const COLOR_MUTED := Color("b0cbd5")
const COLOR_ACCENT := Color("28c9f5")
const COLOR_ACCENT_DARK := Color("087fa6")
const COLOR_GOLD := Color("f5b33b")
const COLOR_GOLD_DARK := Color("b77412")
const COLOR_SUCCESS := Color("78df77")
const COLOR_WARNING := Color("f4a12a")
const COLOR_DANGER := Color("ff7168")
const COLOR_EVENT := Color("e7762d")


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
		style.shadow_color = Color(0, 0, 0, 0.34)
		style.shadow_size = 9
		style.shadow_offset = Vector2(0, 4)

	return style


static func compact_panel(
	background: Color = COLOR_PANEL,
	border: Color = COLOR_BORDER,
	radius: int = 10,
	border_width: int = 1,
	shadow: bool = false
) -> StyleBoxFlat:
	var style := panel(
		background,
		border,
		radius,
		border_width,
		shadow
	)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	if shadow:
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 2)
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
				compact_panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 0, false)
			)
		"hud_level":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.LEVEL_BADGE,
					28.0,
					8.0
				)
			)
		"hud_identity":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.IDENTITY_PANEL,
					22.0,
					10.0
				)
			)
		"hud_passenger":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.RESOURCE_CHIP,
					20.0,
					7.0
				)
			)
		"hud_fuel":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.RESOURCE_CHIP,
					20.0,
					7.0
				)
			)
		"hud_fuel_low":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("4a3517"), COLOR_WARNING, 11, 2, true)
			)
		"hud_fuel_critical":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("4b2526"), COLOR_DANGER, 11, 2, true)
			)
		"hud_coin":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.RESOURCE_CHIP,
					20.0,
					7.0
				)
			)
		"hud_premium":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.RESOURCE_CHIP,
					20.0,
					7.0
				)
			)
		"hud_task":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("102a35", 0.95), Color("315766"), 11, 1, true)
			)
		"hud_status_detail":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("062b42", 0.985), Color("25b5e2"), 12, 1, true)
			)
		"hud_context":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("08283a", 0.985), Color("258fb6"), 12, 1, true)
			)
		"hud_drawer":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("06283b", 0.992), Color("1d8db4"), 12, 1, true)
			)
		"dock":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 0, false)
			)
		"world_bubble":
			control.add_theme_stylebox_override(
				"panel",
				ProductionUIAssets.style_box(
					ProductionUIAssets.WORLD_BUBBLE,
					26.0,
					10.0
				)
			)
		"context":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("062b42", 0.992), Color("25b5e2"), 18, 2, true)
			)
		"context_preview":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("08283a"), Color("197ea4"), 12, 1, false)
			)
		"screen_top":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("06314a", 0.995), Color("28bfe9"), 18, 2, true)
			)
		"screen_section":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("07273a", 0.99), Color("18799f"), 14, 1, false)
			)
		"screen_focus":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("083f5d", 0.995), Color("36d1f6"), 16, 2, true)
			)
		"reward_tile":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("122c35"), Color("4d7988"), 11, 1, false)
			)
		"mission_done":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("123126"), COLOR_SUCCESS, 12, 2, false)
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
			normal_bg = Color("d67b12")
			normal_border = Color("ffd263")
			hover_bg = Color("ee941f")
			pressed_bg = Color("af610b")
			pressed_border = Color("fff0b2")
		"danger":
			normal_bg = Color("743b3d")
			normal_border = Color("c96a6d")
			hover_bg = Color("8d474a")
			pressed_bg = Color("5a2e31")
			pressed_border = COLOR_DANGER
		"nav":
			normal_bg = Color("08314a")
			normal_border = Color("197fa6")
			hover_bg = Color("0b4565")
			pressed_bg = Color("0b5777")
			pressed_border = COLOR_ACCENT
		"selected":
			normal_bg = Color("075c83")
			normal_border = Color("32d1f6")
			hover_bg = Color("0876a6")
			pressed_bg = Color("064f72")
			pressed_border = Color("bdf5ff")
		"event":
			normal_bg = Color("7c421f")
			normal_border = COLOR_EVENT
			hover_bg = Color("985126")
			pressed_bg = Color("603319")
			pressed_border = Color("ffb36a")
		"dock":
			normal_bg = Color("082b40")
			normal_border = Color("176d91")
			hover_bg = Color("0b3d59")
			pressed_bg = Color("0b4c69")
			pressed_border = COLOR_ACCENT
		"dock_selected":
			normal_bg = Color("0876aa")
			normal_border = Color("41d9ff")
			hover_bg = Color("0a8cc4")
			pressed_bg = Color("06638f")
			pressed_border = Color("d4f9ff")
		"build_card":
			normal_bg = Color("0a3046")
			normal_border = Color("176f95")
			hover_bg = Color("0b405b")
			pressed_bg = Color("0b506d")
			pressed_border = COLOR_ACCENT
		"build_card_selected":
			normal_bg = Color("075d83")
			normal_border = Color("3dd5fb")
			hover_bg = Color("0876a1")
			pressed_bg = Color("064f70")
			pressed_border = Color("c8f7ff")
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

	var glossy_path := ""
	if kind in ["primary", "mission_complete"]:
		glossy_path = ProductionUIAssets.BUTTON_GREEN
	elif kind == "dock":
		glossy_path = ProductionUIAssets.NAV_TILE
	elif kind == "dock_selected":
		glossy_path = ProductionUIAssets.NAV_TILE_SELECTED
	elif kind in [
		"nav",
		"build_card",
		"screen_tab",
		"secondary"
	]:
		glossy_path = ProductionUIAssets.BUTTON_BLUE
	elif kind in [
		"selected",
		"build_card_selected",
		"screen_tab_selected"
	]:
		glossy_path = ProductionUIAssets.BUTTON_BLUE

	if not glossy_path.is_empty():
		button.add_theme_stylebox_override(
			"normal",
			ProductionUIAssets.button_style(glossy_path)
		)
		button.add_theme_stylebox_override(
			"hover",
			ProductionUIAssets.button_style(glossy_path)
		)
		button.add_theme_stylebox_override(
			"disabled",
			ProductionUIAssets.button_style(
				ProductionUIAssets.BUTTON_GRAY
			)
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
		ProductionUIAssets.progress_style(
			ProductionUIAssets.PROGRESS_TRACK
		)
	)

	progress.add_theme_stylebox_override(
		"fill",
		ProductionUIAssets.progress_style(
			ProductionUIAssets.PROGRESS_GOLD
			if gold
			else ProductionUIAssets.PROGRESS_BLUE
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
