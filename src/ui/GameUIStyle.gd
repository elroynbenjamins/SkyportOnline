class_name GameUIStyle
extends RefCounted

# Friendly travel/airport palette — lightly saturated sky, aqua and
# mint surfaces with sand-gold rewards. Keep darker foundations under white
# body text so the brighter look does not cost small-screen legibility.
const COLOR_BG := Color("122d3c")
const COLOR_BG_SOFT := Color("1a4353")
const COLOR_PANEL := Color("214b5d")
const COLOR_PANEL_RAISED := Color("285b6c")
const COLOR_PANEL_DARK := Color("1a3d4f")
const COLOR_BORDER := Color("65afbf")
const COLOR_BORDER_SOFT := Color("467f91")
const COLOR_TEXT := Color("fbfdff")
const COLOR_MUTED := Color("c5e0e5")
const COLOR_ACCENT := Color("87dcdf")
const COLOR_ACCENT_DARK := Color("308e9e")
const COLOR_GOLD := Color("ffd184")
const COLOR_GOLD_DARK := Color("977039")
const COLOR_SUCCESS := Color("96e3b6")
const COLOR_WARNING := Color("ffcf86")
const COLOR_DANGER := Color("ff9a94")
const COLOR_EVENT := Color("f1ac82")


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

# Native-style surfaces replace legacy browser-era glossy textures in the
# airport's compact resource bar. World art and flight-state bubbles stay
# independent so Codex can later replace icon art without changing logic.
static func modern_resource_pill(kind: String) -> StyleBoxFlat:
	var fill := Color("275363", 0.97)
	var stroke := Color("84c4c6", 0.86)
	match kind:
		"level":
			fill = Color("29566e", 0.98)
			stroke = Color("93d4e2", 0.88)
		"identity":
			fill = Color("234c61", 0.98)
			stroke = Color("7dbfce", 0.83)
		"passenger":
			fill = Color("255d56", 0.98)
			stroke = Color("94dbbc", 0.91)
		"fuel":
			fill = Color("275671", 0.98)
			stroke = Color("94ccec", 0.88)
		"coin":
			fill = Color("5c4b31", 0.98)
			stroke = Color("e5c98c", 0.92)
		"premium":
			fill = Color("4e4367", 0.98)
			stroke = Color("c9b6eb", 0.9)
	var style := compact_panel(fill, stroke, 16, 1, true)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 3
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
			control.add_theme_stylebox_override("panel", modern_resource_pill("level"))
		"hud_identity":
			control.add_theme_stylebox_override("panel", modern_resource_pill("identity"))
		"hud_passenger":
			control.add_theme_stylebox_override("panel", modern_resource_pill("passenger"))
		"hud_fuel":
			control.add_theme_stylebox_override("panel", modern_resource_pill("fuel"))
		"hud_fuel_low":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("685336"), COLOR_WARNING, 16, 1, true)
			)
		"hud_fuel_critical":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("633c46"), COLOR_DANGER, 16, 1, true)
			)
		"hud_coin":
			control.add_theme_stylebox_override("panel", modern_resource_pill("coin"))
		"hud_premium":
			control.add_theme_stylebox_override("panel", modern_resource_pill("premium"))
		"hud_task":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("254d5a", 0.98), Color("83c7cc"), 15, 1, true)
			)
		"hud_status_detail":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("245267", 0.985), Color("88c7d3"), 16, 1, true)
			)
		"hud_footer":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("214e61", 0.97), Color("74bdcc"), 18, 1, true)
			)
		"hud_context":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("244e60", 0.985), Color("76bac6"), 16, 1, true)
			)
		"hud_drawer":
			control.add_theme_stylebox_override(
				"panel",
				compact_panel(Color("23495a", 0.99), Color("78b9c7"), 18, 1, true)
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
				panel(Color("214e61", 0.99), Color("83c5d1"), 18, 1, true)
			)
		"context_preview":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("254c5c"), Color("79b3c0"), 14, 1, false)
			)
		"screen_top":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("2a596d", 0.99), Color("84cbd3"), 18, 1, true)
			)
		"screen_section":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("234959", 0.99), Color("6da9b6"), 15, 1, false)
			)
		"screen_focus":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("2a6470", 0.99), Color("a0e2d8"), 18, 1, true)
			)
		"reward_tile":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("2c505d"), Color("7fa9b0"), 13, 1, false)
			)
		"mission_done":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("123126"), COLOR_SUCCESS, 12, 2, false)
			)
		"toast_success":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("285947", 0.98), COLOR_SUCCESS, 15, 1, true)
			)
		"toast_warning":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("655039", 0.98), COLOR_WARNING, 15, 1, true)
			)
		"toast_danger":
			control.add_theme_stylebox_override(
				"panel",
				panel(Color("623c43", 0.98), COLOR_DANGER, 15, 1, true)
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
			normal_bg = Color("387f86")
			normal_border = Color("a4d9d2")
			hover_bg = Color("44999a")
			pressed_bg = Color("2c6e76")
			pressed_border = Color("ceefdf")
		"gold":
			normal_bg = Color("916d3b")
			normal_border = Color("f6d69a")
			hover_bg = Color("a98145")
			pressed_bg = Color("785c33")
			pressed_border = Color("fff0cf")
		"danger":
			normal_bg = Color("924c59")
			normal_border = Color("eda19c")
			hover_bg = Color("a45a65")
			pressed_bg = Color("753e49")
			pressed_border = COLOR_DANGER
		"nav":
			normal_bg = Color("2c5b70")
			normal_border = Color("8bbecb")
			hover_bg = Color("376d7e")
			pressed_bg = Color("275568")
			pressed_border = COLOR_ACCENT
		"selected":
			normal_bg = Color("297786")
			normal_border = Color("abdfd6")
			hover_bg = Color("329099")
			pressed_bg = Color("235e6e")
			pressed_border = Color("e0faf6")
		"event":
			normal_bg = Color("965e45")
			normal_border = COLOR_EVENT
			hover_bg = Color("aa7056")
			pressed_bg = Color("754a39")
			pressed_border = Color("ffe1c7")
		"dock":
			# Modern floating tool surface: matte navy, thin outline and subtle
			# lift rather than the heavy glossy square legacy image asset.
			normal_bg = Color("295769", 0.98)
			normal_border = Color("80b9c5", 0.94)
			hover_bg = Color("366a78", 0.99)
			pressed_bg = Color("254c5d")
			pressed_border = Color("a2dde1")
		"dock_selected":
			normal_bg = Color("327e81", 0.99)
			normal_border = Color("b5e6d0")
			hover_bg = Color("42989a")
			pressed_bg = Color("24696e")
			pressed_border = Color("e5f9ed")
		"build_filter":
			normal_bg = Color("315d69", 0.97)
			normal_border = Color("85b4bd", 0.76)
			hover_bg = Color("416f79")
			pressed_bg = Color("28515e")
			pressed_border = COLOR_ACCENT
		"build_filter_selected":
			normal_bg = Color("367f7e", 0.99)
			normal_border = Color("b2e4d1")
			hover_bg = Color("49958e")
			pressed_bg = Color("2b686b")
			pressed_border = Color("ddf9e8")
		"hud_chip":
			normal_bg = Color("315b6a", 0.96)
			normal_border = Color("88b9c4", 0.82)
			hover_bg = Color("3c6a79")
			pressed_bg = Color("2b5265")
			pressed_border = COLOR_ACCENT
		"hud_chip_selected":
			normal_bg = Color("337e85", 0.99)
			normal_border = Color("ade0d6")
			hover_bg = Color("43949b")
			pressed_bg = Color("2c6475")
			pressed_border = Color("e1f9ee")
		"hud_chip_warning":
			normal_bg = Color("70583c", 0.97)
			normal_border = Color("f2ce8f", 0.82)
			hover_bg = Color("80664a")
			pressed_bg = Color("594730")
			pressed_border = COLOR_WARNING
		"hud_chip_danger":
			normal_bg = Color("784b56", 0.97)
			normal_border = Color("f0aca7", 0.8)
			hover_bg = Color("8d5c62")
			pressed_bg = Color("633c49")
			pressed_border = COLOR_DANGER
		"hud_soft":
			normal_bg = Color("365c6b")
			normal_border = Color("96cbd0")
			hover_bg = Color("457285")
			pressed_bg = Color("2c5060")
			pressed_border = Color("c8efed")
		"build_card":
			normal_bg = Color("2a5466", 0.985)
			normal_border = Color("86bdc7", 0.83)
			hover_bg = Color("356a78")
			pressed_bg = Color("234d63")
			pressed_border = COLOR_ACCENT
		"build_card_selected":
			normal_bg = Color("34766f")
			normal_border = Color("a8e1cb")
			hover_bg = Color("3d8b82")
			pressed_bg = Color("285f65")
			pressed_border = Color("e6fff2")
		"build_card_locked":
			normal_bg = Color("364951")
			normal_border = Color("607a82")
			hover_bg = Color("364951")
			pressed_bg = Color("364951")
			pressed_border = Color("607a82")
		"screen_tab":
			normal_bg = Color("305462")
			normal_border = Color("85b3bd")
			hover_bg = Color("396574")
			pressed_bg = Color("2b4b59")
			pressed_border = COLOR_ACCENT
		"screen_tab_selected":
			normal_bg = Color("347777")
			normal_border = Color("abe0d5")
			hover_bg = Color("428c86")
			pressed_bg = Color("286266")
			pressed_border = Color("ddf9eb")
		"mission_complete":
			normal_bg = Color("183a2d")
			normal_border = COLOR_SUCCESS
			hover_bg = Color("204a39")
			pressed_bg = Color("143126")
			pressed_border = Color("a8efc1")

	var floating := kind in ["dock", "dock_selected"]
	var building_card := kind in [
		"build_card", "build_card_selected", "build_card_locked"
	]
	var modern_chip := kind in [
		"build_filter", "build_filter_selected",
		"hud_chip", "hud_chip_selected", "hud_chip_warning", "hud_chip_danger",
		"hud_soft"
	]
	var radius := (
		16 if floating else (15 if building_card else (13 if modern_chip
		else (10 if compact else 12)))
	)
	var normal_style := panel(normal_bg, normal_border, radius, 1, floating or building_card)
	if building_card:
		normal_style.content_margin_left = 9
		normal_style.content_margin_right = 9
		normal_style.content_margin_top = 7
		normal_style.content_margin_bottom = 7
		normal_style.shadow_size = 3
		normal_style.shadow_offset = Vector2(0, 2)
		normal_style.shadow_color = Color(0, 0, 0, 0.17)
	if floating:
		normal_style.shadow_size = 4
		normal_style.shadow_offset = Vector2(0, 2)
		normal_style.shadow_color = Color(0, 0, 0, 0.25)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override(
		"hover",
		panel(hover_bg, normal_border, radius, 1, floating)
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
	# The airport dock intentionally uses the lightweight flat styles above.
	# Older glossy assets remain for other screens pending the art refactor.
	elif kind in [
		"nav",
		"screen_tab",
		"secondary"
	]:
		glossy_path = ProductionUIAssets.BUTTON_BLUE
	elif kind in [
		"selected",
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


# Shared world bubble skin, intentionally separate from all HUD/drawer buttons.
# Keeps the original minimum touch area while visual treatment communicates
# which of the Skyrama actions can be tapped next.
static func handling_action_palette(action: String) -> Dictionary:
	match action.to_upper():
		"RECEIVE", "LAND":
			return {"fill": Color("35769c"), "border": Color("b5e6f5")}
		"UNLOAD":
			return {"fill": Color("95634a"), "border": Color("ffd6b4")}
		"LOAD":
			return {"fill": Color("327f92"), "border": Color("b8eff0")}
		"SEND":
			return {"fill": Color("927246"), "border": Color("ffe3a4")}
		"HANGAR":
			return {"fill": Color("397d62"), "border": Color("b8f1cf")}
		_:
			return {"fill": Color("3b687e"), "border": COLOR_ACCENT}


static func apply_handling_action_bubble(button: Button, action: String) -> void:
	if button == null:
		return
	var colors := handling_action_palette(action)
	var fill: Color = colors["fill"]
	var outline: Color = colors["border"]
	var normal := panel(fill, outline, 18, 2, true)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.16)
	hover.border_color = outline.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.20)
	pressed.border_color = Color.WHITE
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", panel(Color.TRANSPARENT, outline, 18, 2, false))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_constant_override("h_separation", 6)
	button.add_theme_constant_override("icon_max_width", 22)


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
			Color("254a59"),
			Color("6b9cab"),
			10,
			1,
			false
		)
	)
	input.add_theme_stylebox_override(
		"focus",
		panel(
			Color("2e5b69"),
			COLOR_ACCENT,
			10,
			2,
			false
		)
	)
	input.add_theme_color_override("font_color", COLOR_TEXT)
	input.add_theme_color_override(
		"font_placeholder_color",
		Color("b0ced5")
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
