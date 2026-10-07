extends CanvasLayer

const HUD_ICON_SVG := {
	"build": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><path d="M7 17.5l6.6-6.6 2.5 2.5-6.6 6.6H7v-2.5z" fill="#f8fcff"/><path d="M12.7 7.7l2.1-2.1 3.6 3.6-2.1 2.1-3.6-3.6z" fill="#f5b33b"/><path d="M5.6 6.3l4.1 4.1" stroke="#f8fcff" stroke-width="2" stroke-linecap="round"/></svg>""",
	"fleet": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><path d="M4.5 13l6.2-1.8 1.4-6.5c.2-.9 1.6-.9 1.8 0l.5 5.7 4.3-1.2c1-.3 1.5 1 .6 1.5l-4.7 2.7-.3 4.8 2 1.5v.9l-3.3-.8-3.3.8v-.9l2-1.5-.3-4-6.1.7c-1.1.1-1.7-1.5-.8-1.9z" fill="#f8fcff"/></svg>""",
	"world": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><circle cx="12" cy="12" r="6.3" fill="none" stroke="#f8fcff" stroke-width="1.5"/><path d="M5.9 12h12.2M12 5.7c2 1.8 3 3.9 3 6.3s-1 4.5-3 6.3M12 5.7c-2 1.8-3 3.9-3 6.3s1 4.5 3 6.3" fill="none" stroke="#f8fcff" stroke-width="1.2" stroke-linecap="round"/></svg>""",
	"activities": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><rect x="6.5" y="5.5" width="11" height="13" rx="1.8" fill="none" stroke="#f8fcff" stroke-width="1.5"/><rect x="9" y="4.2" width="6" height="2.8" rx="1" fill="#f5b33b"/><path d="M12 9l.9 1.8 2 .3-1.5 1.4.4 2-1.8-.9-1.8.9.4-2-1.5-1.4 2-.3L12 9z" fill="#f8fcff"/></svg>""",
	"social": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><circle cx="9" cy="9" r="2.4" fill="#f8fcff"/><circle cx="15.5" cy="10" r="2" fill="#f8fcff" opacity=".9"/><path d="M4.8 17.8c.4-3.1 2-4.6 4.4-4.6s4 1.5 4.4 4.6" fill="#f8fcff"/><path d="M13.2 17.8c.3-2.4 1.4-3.6 3.3-3.6 1.6 0 2.7 1.2 3 3.6" fill="#f8fcff" opacity=".85"/></svg>""",
	"more": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><circle cx="7" cy="12" r="1.7" fill="#f8fcff"/><circle cx="12" cy="12" r="1.7" fill="#f8fcff"/><circle cx="17" cy="12" r="1.7" fill="#f8fcff"/></svg>""",
	"passengers": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#075a78" stroke="#4bd7f6" stroke-width="1.2"/><circle cx="9" cy="8.8" r="2.2" fill="#f8fcff"/><circle cx="15.2" cy="9.5" r="1.8" fill="#f8fcff" opacity=".85"/><path d="M5 17.7c.4-3.2 1.9-4.8 4.2-4.8 2.4 0 3.8 1.6 4.2 4.8" fill="#f8fcff"/><path d="M13 17.7c.3-2.5 1.4-3.7 3.2-3.7 1.6 0 2.7 1.2 3 3.7" fill="#f8fcff" opacity=".82"/></svg>""",
	"fuel": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#4a3517" stroke="#f5c55d" stroke-width="1.2"/><rect x="6.5" y="5.5" width="7.5" height="12.5" rx="1.2" fill="#f5b33b"/><rect x="8" y="7" width="4.5" height="3.4" rx=".5" fill="#403418"/><path d="M14 8h2.2l1.6 1.8v5.6c0 .8-.5 1.3-1.2 1.3-.8 0-1.3-.5-1.3-1.3v-3.1" fill="none" stroke="#f8fcff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>""",
	"coins": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#3a3020" stroke="#f5b33b" stroke-width="1.2"/><ellipse cx="11.5" cy="8" rx="5.2" ry="2.2" fill="#f5b33b"/><path d="M6.3 8v3c0 1.2 2.3 2.2 5.2 2.2s5.2-1 5.2-2.2V8" fill="#f5b33b" opacity=".92"/><path d="M6.3 11v3c0 1.2 2.3 2.2 5.2 2.2s5.2-1 5.2-2.2v-3" fill="#f5b33b" opacity=".82"/><path d="M9.5 7.8h4" stroke="#6f4b0d" stroke-width="1.1" stroke-linecap="round"/></svg>""",
	"aero": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#2e2045" stroke="#c49af5" stroke-width="1.2"/><path d="M12 4.8l5.7 5.2L12 19.2 6.3 10 12 4.8z" fill="#c49af5"/><path d="M6.3 10h11.4M12 4.8L9.5 10 12 19.2 14.5 10 12 4.8z" fill="none" stroke="#f8fcff" stroke-width="1" stroke-linejoin="round"/></svg>""",
	"airfield": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><path d="M5 16.8h14" stroke="#f8fcff" stroke-width="1.6" stroke-linecap="round"/><path d="M7 13.8h10" stroke="#f8fcff" stroke-width="1.2" stroke-linecap="round" stroke-dasharray="2 2"/><path d="M6.5 9.8l4.2-1.1.9-3.5c.2-.7 1.1-.7 1.3 0l.4 3 3-.8c.8-.2 1.1.8.4 1.2l-3.2 1.8-.2 2.3-1.3.3-.3-2.1-5 .6c-.8.1-1.1-1.1-.2-1.7z" fill="#f8fcff"/></svg>""",
	"ops": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><path d="M8.5 7h7l1 2.2 2 .6v5.6H6V9.8l1.5-.6L8.5 7z" fill="#f8fcff"/><circle cx="9" cy="16" r="1.7" fill="#78df77"/><circle cx="15.5" cy="16" r="1.7" fill="#78df77"/><rect x="9.5" y="8.5" width="4.5" height="2" rx=".4" fill="#0b4f70"/></svg>""",
	"atc": """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="#0b4f70" stroke="#36d1f6" stroke-width="1.2"/><path d="M8 18h8l-1.2-8H9.2L8 18z" fill="#f8fcff"/><rect x="7.3" y="7" width="9.4" height="3.4" rx="1" fill="#f8fcff"/><rect x="9" y="8" width="2" height="1.4" fill="#0b4f70"/><rect x="13" y="8" width="2" height="1.4" fill="#0b4f70"/><path d="M12 7V4.8M12 4.8l3-1" stroke="#f5b33b" stroke-width="1.4" stroke-linecap="round"/></svg>"""
}
signal purchase_expansion_requested
signal building_selected(building_id: String)
signal rotate_building_requested
signal confirm_building_requested
signal cancel_building_requested
signal placement_expand_requested(parcel_id: String)
signal store_building_requested
signal stored_building_selected(building_uid: int)
signal airport_edit_requested
signal undo_airport_edit_requested
signal done_airport_edit_requested
signal navigation_requested(tab: String)
signal handling_attention_requested
signal fuel_order_requested
signal tutorial_action_requested(action: String, target: String)

var interface_root: Control
var title_label: Label
var airport_meta_label: Label
var level_label: Label
var xp_progress: ProgressBar
var xp_label: Label
var passenger_label: Label
var passenger_rate_label: Label
var passenger_icon: TextureRect
var fuel_label: Label
var fuel_rate_label: Label
var fuel_icon: TextureRect
var fuel_order_button: Button
var fuel_panel: PanelContainer
var coins_label: Label
var coins_icon: TextureRect
var gems_label: Label
var gems_icon: TextureRect
var airside_status_label: Label
var operation_status_label: Label
var atc_status_label: Label

var airside_status_chip: Button
var operation_status_chip: Button
var atc_status_chip: Button
var handling_attention_button: Button
var tutorial_objective_panel: PanelContainer
var tutorial_objective_button: Button
var tutorial_action := ""
var tutorial_target := ""
var status_detail_panel: PanelContainer
var status_detail_title: Label
var status_detail_body: Label
var expansion_banner: PanelContainer
var expansion_banner_title: Label
var expansion_banner_detail: Label
var expansion_banner_tween: Tween
var operation_toast_panel: PanelContainer
var operation_toast_label: Label
var operation_toast_tween: Tween
var dispatch_shift_panel: PanelContainer
var dispatch_shift_label: Label
var bottom_nav_panel: PanelContainer
var active_status_chip := ""
var status_details: Dictionary = {}
var current_operation_status_text := "Preparing airport..."
var current_operation_status_tone := "normal"
var operations_analytics: Dictionary = {}

var parcel_panel: PanelContainer
var parcel_title: Label
var parcel_requirements: Label
var purchase_button: Button

var build_action_panel: PanelContainer
var build_title: Label
var build_status: Label
var rotate_button: Button
var store_button: Button
var expand_here_button: Button
var place_button: Button

var build_hint: Label
var catalog_panel: PanelContainer
var catalog_count_label: Label
var catalog_help_label: Label
var catalog_close_button: Button
var edit_airport_button: Button
var airport_edit_panel: PanelContainer
var airport_edit_status: Label
var storage_button: Button
var undo_airport_edit_button: Button
var done_airport_edit_button: Button
var storage_panel: PanelContainer
var storage_list: VBoxContainer
var storage_count_label: Label

var catalog_buttons: Dictionary = {}
var catalog_definitions: Array[Dictionary] = []
var catalog_filter_buttons: Dictionary = {}
var selected_catalog_category := "ALL"

var current_parcel: Dictionary = {}
var current_level := 1
var current_coins := 0
var current_gems := 0
var active_building_id := ""
var active_build_mode := ""
var active_expand_parcel_id := ""
var event_nav_button: Button
var charter_nav_button: Button
var challenge_nav_button: Button
var activities_nav_button: Button
var social_nav_button: Button
var charter_activity_attention := false
var challenge_activity_attention := false
var event_activity_attention := false
var alliance_activity_attention := false
var mission_activity_attention := false
var nav_buttons: Dictionary = {}
var hud_icon_textures: Dictionary = {}


func _ready() -> void:
	_build_interface()



func _build_interface() -> void:
	interface_root = Control.new()
	var root := interface_root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 10
	top_panel.offset_top = 6
	top_panel.offset_right = -10
	top_panel.offset_bottom = 78
	root.add_child(top_panel)
	GameUIStyle.apply_panel(top_panel, "hud_top")

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 5)
	top_margin.add_theme_constant_override("margin_right", 5)
	top_margin.add_theme_constant_override("margin_top", 3)
	top_margin.add_theme_constant_override("margin_bottom", 3)
	top_panel.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top_margin.add_child(top_row)

	var level_card := PanelContainer.new()
	level_card.custom_minimum_size = Vector2(96, 66)
	GameUIStyle.apply_panel(level_card, "hud_level")
	top_row.add_child(level_card)

	var level_box := VBoxContainer.new()
	level_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_box.add_theme_constant_override("separation", 0)
	level_card.add_child(level_box)

	level_label = Label.new()
	level_label.text = "1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 26)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.02, 0.08, 0.12, 0.70)
	)
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 2)
	level_box.add_child(level_label)

	var identity_card := PanelContainer.new()
	identity_card.custom_minimum_size = Vector2(250, 62)
	identity_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	GameUIStyle.apply_panel(identity_card, "hud_identity")
	top_row.add_child(identity_card)

	var identity_box := VBoxContainer.new()
	identity_box.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_box.add_theme_constant_override("separation", 1)
	identity_card.add_child(identity_box)

	title_label = Label.new()
	title_label.text = "SkyportOnline"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", GameUIStyle.COLOR_TEXT)
	identity_box.add_child(title_label)

	xp_progress = ProgressBar.new()
	xp_progress.custom_minimum_size = Vector2(188, 12)
	xp_progress.show_percentage = false
	xp_progress.min_value = 0.0
	xp_progress.max_value = 1.0
	xp_progress.value = 0.0
	GameUIStyle.apply_progress(xp_progress, false)
	identity_box.add_child(xp_progress)

	xp_label = Label.new()
	xp_label.text = "0 / 100"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", Color.WHITE)
	identity_box.add_child(xp_label)

	airport_meta_label = Label.new()
	airport_meta_label.text = "APT • AIRPORT"
	airport_meta_label.visible = false
	identity_box.add_child(airport_meta_label)

	var passenger_chip := _build_hud_resource_chip(
		top_row,
		"PAX",
		"0 / 0",
		"+0.0/m",
		"hud_passenger",
		124,
		_hud_icon("passengers")
	)
	passenger_label = passenger_chip["value"] as Label
	passenger_rate_label = passenger_chip["detail"] as Label
	passenger_icon = passenger_chip["icon"] as TextureRect

	var fuel_chip := _build_hud_resource_chip(
		top_row,
		"FUEL",
		"0 / 0",
		"+0.0/m",
		"hud_fuel",
		112,
		_hud_icon("fuel")
	)
	fuel_label = fuel_chip["value"] as Label
	fuel_rate_label = fuel_chip["detail"] as Label
	fuel_icon = fuel_chip["icon"] as TextureRect
	fuel_panel = fuel_chip["panel"] as PanelContainer

	fuel_order_button = Button.new()
	fuel_order_button.text = "+"
	fuel_order_button.tooltip_text = "Order fuel • 750 coins"
	fuel_order_button.custom_minimum_size = Vector2(40, 44)
	fuel_order_button.add_theme_font_size_override("font_size", 24)
	GameUIStyle.apply_button(fuel_order_button, "primary", true)
	fuel_order_button.pressed.connect(_on_fuel_order_pressed)
	top_row.add_child(fuel_order_button)

	var coin_chip := _build_hud_resource_chip(
		top_row,
		"COINS",
		"0",
		"",
		"hud_coin",
		96,
		_hud_icon("coins")
	)
	coins_label = coin_chip["value"] as Label
	coins_icon = coin_chip["icon"] as TextureRect

	var aero_chip := _build_hud_resource_chip(
		top_row,
		"AERO",
		"0",
		"",
		"hud_premium",
		82,
		_hud_icon("aero")
	)
	gems_label = aero_chip["value"] as Label
	gems_icon = aero_chip["icon"] as TextureRect

	var settings_button := Button.new()
	settings_button.text = ""
	settings_button.custom_minimum_size = Vector2(48, 48)
	_apply_button_icon(
		settings_button,
		ProductionUIAssets.texture(
			ProductionUIAssets.SETTINGS_ICON
		),
		29
	)
	settings_button.tooltip_text = "Settings and more"
	GameUIStyle.apply_button(settings_button, "dock", true)
	settings_button.pressed.connect(
		_on_navigation_pressed.bind("more")
	)
	top_row.add_child(settings_button)

	tutorial_objective_panel = PanelContainer.new()
	tutorial_objective_panel.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)
	tutorial_objective_panel.offset_left = -360
	tutorial_objective_panel.offset_top = 82
	tutorial_objective_panel.offset_right = -10
	tutorial_objective_panel.offset_bottom = 117
	root.add_child(tutorial_objective_panel)
	GameUIStyle.apply_panel(
		tutorial_objective_panel,
		"hud_task"
	)
	tutorial_objective_panel.visible = false

	tutorial_objective_button = Button.new()
	tutorial_objective_button.text = "AIRPORT BASICS"
	tutorial_objective_button.alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	tutorial_objective_button.add_theme_font_size_override(
		"font_size",
		11
	)
	tutorial_objective_button.tooltip_text = (
		"Follow the starter airport tutorial."
	)
	GameUIStyle.apply_button(
		tutorial_objective_button,
		"nav",
		true
	)
	tutorial_objective_button.pressed.connect(
		_on_tutorial_objective_pressed
	)
	tutorial_objective_panel.add_child(
		tutorial_objective_button
	)

	var status_strip := HBoxContainer.new()
	status_strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_strip.offset_left = 10
	status_strip.offset_top = 82
	status_strip.offset_right = 610
	status_strip.offset_bottom = 117
	status_strip.add_theme_constant_override("separation", 4)
	root.add_child(status_strip)

	airside_status_chip = Button.new()
	airside_status_chip.text = "AIR • CHECKING"
	airside_status_chip.custom_minimum_size = Vector2(132, 34)
	_apply_button_icon(airside_status_chip, _hud_icon("airfield"), 18)
	GameUIStyle.apply_button(airside_status_chip, "nav", true)
	airside_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("airside")
	)
	status_strip.add_child(airside_status_chip)

	operation_status_chip = Button.new()
	operation_status_chip.text = "OPS • PREPARING"
	operation_status_chip.custom_minimum_size = Vector2(150, 34)
	_apply_button_icon(operation_status_chip, _hud_icon("ops"), 18)
	GameUIStyle.apply_button(operation_status_chip, "nav", true)
	operation_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("operations")
	)
	status_strip.add_child(operation_status_chip)

	atc_status_chip = Button.new()
	atc_status_chip.text = "ATC • CLEAR"
	atc_status_chip.custom_minimum_size = Vector2(136, 34)
	_apply_button_icon(atc_status_chip, _hud_icon("atc"), 18)
	GameUIStyle.apply_button(atc_status_chip, "nav", true)
	atc_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("atc")
	)
	status_strip.add_child(atc_status_chip)

	handling_attention_button = Button.new()
	handling_attention_button.text = "NEXT • NONE"
	handling_attention_button.custom_minimum_size = Vector2(160, 34)
	handling_attention_button.visible = false
	handling_attention_button.pressed.connect(
		_on_handling_attention_pressed
	)
	GameUIStyle.apply_button(
		handling_attention_button,
		"gold",
		true
	)
	status_strip.add_child(handling_attention_button)

	_build_expansion_banner(root)
	_build_operation_toast(root)
	_build_dispatch_shift_indicator(root)

	status_detail_panel = PanelContainer.new()
	status_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_detail_panel.offset_left = 10
	status_detail_panel.offset_top = 106
	status_detail_panel.offset_right = 620
	status_detail_panel.offset_bottom = 244
	status_detail_panel.visible = false
	root.add_child(status_detail_panel)
	GameUIStyle.apply_panel(status_detail_panel, "hud_status_detail")

	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 8)
	status_detail_panel.add_child(detail_row)

	var detail_text := VBoxContainer.new()
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_text.add_theme_constant_override("separation", 2)
	detail_row.add_child(detail_text)

	status_detail_title = Label.new()
	status_detail_title.text = "AIRPORT STATUS"
	GameUIStyle.heading(status_detail_title, 13)
	detail_text.add_child(status_detail_title)

	status_detail_body = Label.new()
	status_detail_body.text = "Select a status chip for details."
	status_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_detail_body.add_theme_font_size_override("font_size", 11)
	GameUIStyle.muted(status_detail_body)
	detail_text.add_child(status_detail_body)

	var detail_close := Button.new()
	detail_close.text = "✕"
	detail_close.custom_minimum_size = Vector2(34, 34)
	GameUIStyle.apply_button(detail_close, "secondary", true)
	detail_close.pressed.connect(_close_status_detail)
	detail_row.add_child(detail_close)

	airside_status_label = Label.new()
	operation_status_label = Label.new()
	atc_status_label = Label.new()
	for legacy_label in [airside_status_label, operation_status_label, atc_status_label]:
		legacy_label.visible = false
		root.add_child(legacy_label)

	status_details = {
		"airside": {
			"title": "AIRFIELD",
			"body": "Checking taxiway network...",
			"tone": "normal"
		},
		"operations": {
			"title": "GROUND OPS",
			"body": "Preparing first aircraft...",
			"tone": "normal"
		},
		"atc": {
			"title": "RUNWAY CONTROL",
			"body": "No active movements",
			"tone": "success"
		}
	}

	build_hint = Label.new()
	build_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_hint.offset_left = 12
	build_hint.offset_top = -118
	build_hint.offset_right = 700
	build_hint.offset_bottom = -94
	build_hint.text = "Tap BUILD for construction tools"
	build_hint.add_theme_font_size_override("font_size", 11)
	build_hint.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_MUTED
	)
	root.add_child(build_hint)
	build_hint.visible = false

	_build_context_panel(root)
	_build_airport_edit_panel(root)
	_build_storage_panel(root)
	_build_catalog_panel(root)
	_build_bottom_navigation(root)


func _build_hud_resource_chip(
	parent: HBoxContainer,
	caption: String,
	value_text: String,
	detail_text: String,
	panel_variant: String,
	minimum_width: int,
	icon_texture: Texture2D = null
) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minimum_width, 38)
	GameUIStyle.apply_panel(panel, panel_variant)
	parent.add_child(panel)

	var content_row := HBoxContainer.new()
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_row.add_theme_constant_override("separation", 6)
	panel.add_child(content_row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(26, 26)
	icon_rect.texture = icon_texture
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = icon_texture != null
	content_row.add_child(icon_rect)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	content_row.add_child(box)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.visible = false
	box.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", GameUIStyle.COLOR_TEXT)
	box.add_child(value_label)

	var detail_label := Label.new()
	detail_label.text = detail_text
	detail_label.visible = false
	box.add_child(detail_label)

	return {
		"panel": panel,
		"box": box,
		"icon": icon_rect,
		"value": value_label,
		"detail": detail_label
	}

func _on_fuel_order_pressed() -> void:
	fuel_order_requested.emit()



func set_handling_attention(
	aircraft_label: String,
	action: String,
	pending_count: int = 1
) -> void:
	if handling_attention_button == null:
		return

	var normalized_action := action.to_upper()
	if normalized_action.is_empty():
		handling_attention_button.visible = false
		return

	var suffix := ""
	if pending_count > 1:
		suffix = " +%d" % (pending_count - 1)
	handling_attention_button.text = "%s • %s%s" % [
		normalized_action,
		aircraft_label,
		suffix
	]
	handling_attention_button.tooltip_text = (
		"Focus the next aircraft waiting for %s."
		% normalized_action.capitalize()
	)
	handling_attention_button.visible = true

func _on_handling_attention_pressed() -> void:
	handling_attention_requested.emit()



func _build_expansion_banner(root: Control) -> void:
	expansion_banner = PanelContainer.new()
	expansion_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	expansion_banner.offset_left = 330
	expansion_banner.offset_top = 68
	expansion_banner.offset_right = -330
	expansion_banner.offset_bottom = 122
	expansion_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expansion_banner.visible = false
	root.add_child(expansion_banner)
	GameUIStyle.apply_panel(expansion_banner, "hud_task")

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	expansion_banner.add_child(row)

	var icon := Label.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.text = "✦"
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	expansion_banner_title = Label.new()
	expansion_banner_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expansion_banner_title.text = "AIRPORT EXPANDED"
	expansion_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expansion_banner_title.add_theme_font_size_override(
		"font_size",
		14
	)
	expansion_banner_title.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	text_box.add_child(expansion_banner_title)

	expansion_banner_detail = Label.new()
	expansion_banner_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expansion_banner_detail.text = "New land unlocked"
	expansion_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expansion_banner_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expansion_banner_detail.max_lines_visible = 2
	expansion_banner_detail.add_theme_font_size_override(
		"font_size",
		10
	)
	GameUIStyle.muted(expansion_banner_detail)
	text_box.add_child(expansion_banner_detail)


func _build_operation_toast(root: Control) -> void:
	operation_toast_panel = PanelContainer.new()
	operation_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	operation_toast_panel.offset_left = -250
	operation_toast_panel.offset_top = -116
	operation_toast_panel.offset_right = 250
	operation_toast_panel.offset_bottom = -72
	operation_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	operation_toast_panel.visible = false
	operation_toast_panel.modulate.a = 0.0
	root.add_child(operation_toast_panel)
	GameUIStyle.apply_panel(operation_toast_panel, "toast_success")

	operation_toast_label = Label.new()
	operation_toast_label.text = "Airport update"
	operation_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operation_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operation_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	operation_toast_label.max_lines_visible = 2
	operation_toast_label.add_theme_font_size_override("font_size", 12)
	operation_toast_label.add_theme_color_override("font_color", GameUIStyle.COLOR_TEXT)
	operation_toast_panel.add_child(operation_toast_label)


func _build_dispatch_shift_indicator(root: Control) -> void:
	dispatch_shift_panel = PanelContainer.new()
	dispatch_shift_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dispatch_shift_panel.offset_left = -292
	dispatch_shift_panel.offset_top = -112
	dispatch_shift_panel.offset_right = -10
	dispatch_shift_panel.offset_bottom = -68
	dispatch_shift_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dispatch_shift_panel.visible = false
	root.add_child(dispatch_shift_panel)
	GameUIStyle.apply_panel(dispatch_shift_panel, "hud_task")

	dispatch_shift_label = Label.new()
	dispatch_shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dispatch_shift_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dispatch_shift_label.add_theme_font_size_override("font_size", 12)
	dispatch_shift_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	dispatch_shift_panel.add_child(dispatch_shift_label)

func set_dispatch_shift(
	status: String,
	score: int,
	remaining_seconds: int,
	combo_count: int = 0
) -> void:
	if dispatch_shift_panel == null or dispatch_shift_label == null:
		return
	var running := status == "RUNNING"
	dispatch_shift_panel.visible = running
	if not running:
		return
	var total := maxi(remaining_seconds, 0)
	dispatch_shift_label.text = "✦ DISPATCH  %d:%02d  •  %d PTS%s" % [
		int(total / 60),
		total % 60,
		maxi(score, 0),
		"  •  COMBO x%d" % combo_count if combo_count >= 2 else ""
	]


func _show_operation_toast(text: String, tone: String) -> void:
	if operation_toast_panel == null or operation_toast_label == null:
		return
	if operation_toast_tween != null and operation_toast_tween.is_valid():
		operation_toast_tween.kill()

	var prefix := "✓ "
	var variant := "toast_success"
	match tone:
		"warning":
			prefix = "⚠ "
			variant = "toast_warning"
		"danger":
			prefix = "✕ "
			variant = "toast_danger"
	operation_toast_label.text = prefix + text
	GameUIStyle.apply_panel(operation_toast_panel, variant)
	operation_toast_panel.visible = true
	operation_toast_panel.modulate.a = 0.0

	operation_toast_tween = create_tween()
	operation_toast_tween.tween_property(
		operation_toast_panel,
		"modulate:a",
		1.0,
		0.12
	)
	operation_toast_tween.tween_interval(2.0)
	operation_toast_tween.tween_property(
		operation_toast_panel,
		"modulate:a",
		0.0,
		0.24
	)
	operation_toast_tween.tween_callback(
		func() -> void:
			operation_toast_panel.visible = false
	)



func _build_context_panel(root: Control) -> void:
	parcel_panel = PanelContainer.new()
	parcel_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	parcel_panel.offset_left = 10
	parcel_panel.offset_top = -130
	parcel_panel.offset_right = -382
	parcel_panel.offset_bottom = -62
	root.add_child(parcel_panel)
	GameUIStyle.apply_panel(parcel_panel, "hud_context")

	var parcel_row := HBoxContainer.new()
	parcel_row.add_theme_constant_override("separation", 8)
	parcel_panel.add_child(parcel_row)

	var parcel_text := VBoxContainer.new()
	parcel_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parcel_text.add_theme_constant_override("separation", 1)
	parcel_row.add_child(parcel_text)

	parcel_title = Label.new()
	parcel_title.text = "EXPAND LAND"
	parcel_title.add_theme_font_size_override("font_size", 15)
	parcel_text.add_child(parcel_title)

	parcel_requirements = Label.new()
	parcel_requirements.text = "Select an expansion parcel"
	parcel_requirements.add_theme_font_size_override("font_size", 11)
	parcel_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parcel_requirements.max_lines_visible = 2
	parcel_text.add_child(parcel_requirements)

	purchase_button = Button.new()
	purchase_button.custom_minimum_size = Vector2(150, 50)
	purchase_button.text = "SELECT LAND"
	purchase_button.disabled = true
	purchase_button.pressed.connect(_on_purchase_pressed)
	GameUIStyle.apply_button(purchase_button, "gold", true)
	parcel_row.add_child(purchase_button)

	build_action_panel = PanelContainer.new()
	build_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	build_action_panel.offset_left = 10
	build_action_panel.offset_top = -124
	build_action_panel.offset_right = -382
	build_action_panel.offset_bottom = -62
	build_action_panel.visible = false
	root.add_child(build_action_panel)
	GameUIStyle.apply_panel(build_action_panel, "hud_context")

	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 6)
	build_action_panel.add_child(build_row)

	var build_text := VBoxContainer.new()
	build_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_text.add_theme_constant_override("separation", 1)
	build_row.add_child(build_text)

	build_title = Label.new()
	build_title.text = "PLACE BUILDING"
	build_title.add_theme_font_size_override("font_size", 14)
	build_text.add_child(build_title)

	build_status = Label.new()
	build_status.text = "Tap owned land to preview placement."
	build_status.add_theme_font_size_override("font_size", 11)
	build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_status.max_lines_visible = 2
	build_text.add_child(build_status)

	store_button = Button.new()
	store_button.custom_minimum_size = Vector2(84, 48)
	store_button.text = "📦 STORE"
	store_button.visible = false
	store_button.pressed.connect(_on_store_building_pressed)
	GameUIStyle.apply_button(store_button, "secondary", true)
	build_row.add_child(store_button)

	rotate_button = Button.new()
	rotate_button.custom_minimum_size = Vector2(82, 48)
	rotate_button.text = "↻ ROTATE"
	rotate_button.pressed.connect(_on_rotate_pressed)
	GameUIStyle.apply_button(rotate_button, "secondary", true)
	build_row.add_child(rotate_button)

	var cancel_button := Button.new()
	cancel_button.custom_minimum_size = Vector2(82, 48)
	cancel_button.text = "✕ CANCEL"
	cancel_button.pressed.connect(_on_cancel_building_pressed)
	GameUIStyle.apply_button(cancel_button, "danger", true)
	build_row.add_child(cancel_button)

	expand_here_button = Button.new()
	expand_here_button.custom_minimum_size = Vector2(128, 48)
	expand_here_button.text = "EXPAND HERE"
	expand_here_button.visible = false
	expand_here_button.disabled = true
	expand_here_button.pressed.connect(
		_on_expand_here_pressed
	)
	GameUIStyle.apply_button(
		expand_here_button,
		"gold",
		true
	)
	build_row.add_child(expand_here_button)

	place_button = Button.new()
	place_button.custom_minimum_size = Vector2(118, 48)
	place_button.text = "PLACE"
	place_button.disabled = true
	place_button.pressed.connect(_on_confirm_building_pressed)
	GameUIStyle.apply_button(place_button, "primary", true)
	build_row.add_child(place_button)


func _build_airport_edit_panel(root: Control) -> void:
	airport_edit_panel = PanelContainer.new()
	airport_edit_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	airport_edit_panel.offset_left = 10
	airport_edit_panel.offset_top = -124
	airport_edit_panel.offset_right = -382
	airport_edit_panel.offset_bottom = -62
	airport_edit_panel.visible = false
	root.add_child(airport_edit_panel)
	GameUIStyle.apply_panel(airport_edit_panel, "hud_context")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	airport_edit_panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	var title := Label.new()
	title.text = "EDIT AIRPORT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	text_box.add_child(title)

	airport_edit_status = Label.new()
	airport_edit_status.text = (
		"Tap a movable building • changes save when confirmed"
	)
	airport_edit_status.add_theme_font_size_override("font_size", 11)
	text_box.add_child(airport_edit_status)

	storage_button = Button.new()
	storage_button.custom_minimum_size = Vector2(112, 48)
	storage_button.text = "📦 STORAGE"
	storage_button.pressed.connect(
		_on_storage_pressed
	)
	GameUIStyle.apply_button(
		storage_button,
		"secondary",
		true
	)
	row.add_child(storage_button)

	undo_airport_edit_button = Button.new()
	undo_airport_edit_button.custom_minimum_size = Vector2(86, 48)
	undo_airport_edit_button.text = "↶ UNDO"
	undo_airport_edit_button.disabled = true
	undo_airport_edit_button.pressed.connect(
		_on_undo_airport_edit_pressed
	)
	GameUIStyle.apply_button(
		undo_airport_edit_button,
		"secondary",
		true
	)
	row.add_child(undo_airport_edit_button)

	done_airport_edit_button = Button.new()
	done_airport_edit_button.custom_minimum_size = Vector2(88, 48)
	done_airport_edit_button.text = "✓ DONE"
	done_airport_edit_button.pressed.connect(
		_on_done_airport_edit_pressed
	)
	GameUIStyle.apply_button(
		done_airport_edit_button,
		"primary",
		true
	)
	row.add_child(done_airport_edit_button)


func _build_storage_panel(root: Control) -> void:
	storage_panel = PanelContainer.new()
	storage_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	storage_panel.offset_left = -374
	storage_panel.offset_top = 108
	storage_panel.offset_right = -8
	storage_panel.offset_bottom = -62
	storage_panel.visible = false
	root.add_child(storage_panel)
	GameUIStyle.apply_panel(storage_panel, "hud_drawer")

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 5)
	storage_panel.add_child(wrapper)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	wrapper.add_child(header)

	var title := Label.new()
	title.text = "AIRPORT STORAGE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 14)
	header.add_child(title)

	storage_count_label = Label.new()
	storage_count_label.text = "0 STORED"
	storage_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	storage_count_label.add_theme_font_size_override("font_size", 10)
	GameUIStyle.muted(storage_count_label)
	header.add_child(storage_count_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(32, 30)
	GameUIStyle.apply_button(close_button, "secondary", true)
	close_button.pressed.connect(_on_storage_pressed)
	header.add_child(close_button)

	var help := Label.new()
	help.text = (
		"Stored buildings keep upgrades but pause airport effects."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 10)
	GameUIStyle.muted(help)
	wrapper.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(scroll)

	storage_list = VBoxContainer.new()
	storage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_list.add_theme_constant_override("separation", 5)
	scroll.add_child(storage_list)


func _build_catalog_panel(root: Control) -> void:
	catalog_panel = PanelContainer.new()
	catalog_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	catalog_panel.offset_left = -374
	catalog_panel.offset_top = 108
	catalog_panel.offset_right = -8
	catalog_panel.offset_bottom = -62
	root.add_child(catalog_panel)
	GameUIStyle.apply_panel(catalog_panel, "hud_drawer")
	catalog_panel.visible = false

	var catalog_wrapper := VBoxContainer.new()
	catalog_wrapper.add_theme_constant_override("separation", 5)
	catalog_panel.add_child(catalog_wrapper)

	var catalog_header_row := HBoxContainer.new()
	catalog_header_row.add_theme_constant_override("separation", 5)
	catalog_wrapper.add_child(catalog_header_row)

	var catalog_header := Label.new()
	catalog_header.text = "BUILD"
	catalog_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.heading(catalog_header, 14)
	catalog_header.add_theme_color_override("font_color", GameUIStyle.COLOR_ACCENT)
	catalog_header_row.add_child(catalog_header)

	catalog_count_label = Label.new()
	catalog_count_label.text = "0 AVAILABLE"
	catalog_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_count_label.add_theme_font_size_override("font_size", 9)
	GameUIStyle.muted(catalog_count_label)
	catalog_header_row.add_child(catalog_count_label)

	edit_airport_button = Button.new()
	edit_airport_button.text = "EDIT"
	edit_airport_button.custom_minimum_size = Vector2(62, 30)
	GameUIStyle.apply_button(edit_airport_button, "gold", true)
	edit_airport_button.pressed.connect(_on_airport_edit_pressed)
	catalog_header_row.add_child(edit_airport_button)

	catalog_close_button = Button.new()
	catalog_close_button.text = "✕"
	catalog_close_button.custom_minimum_size = Vector2(32, 30)
	GameUIStyle.apply_button(catalog_close_button, "secondary", true)
	catalog_close_button.pressed.connect(_on_catalog_close_pressed)
	catalog_header_row.add_child(catalog_close_button)

	catalog_help_label = Label.new()
	catalog_help_label.text = "Tap a building to place it"
	catalog_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_help_label.add_theme_font_size_override("font_size", 10)
	GameUIStyle.muted(catalog_help_label)
	catalog_wrapper.add_child(catalog_help_label)
	catalog_help_label.visible = false

	var filters := GridContainer.new()
	filters.columns = 6
	filters.add_theme_constant_override("h_separation", 3)
	filters.add_theme_constant_override("v_separation", 3)
	catalog_wrapper.add_child(filters)

	for filter_data in [
		["ALL", "ALL"],
		["INFRA", "Infrastructure"],
		["PAX", "Passenger"],
		["SERV", "Services"],
		["OPS", "Operations"],
		["DECOR", "Decorations"]
	]:
		var chip := Button.new()
		chip.text = String(filter_data[0])
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 30)
		var category := String(filter_data[1])
		GameUIStyle.apply_button(
			chip,
			"selected" if category == selected_catalog_category else "nav",
			true
		)
		chip.pressed.connect(_on_catalog_filter_pressed.bind(category))
		filters.add_child(chip)
		catalog_filter_buttons[category] = chip

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_wrapper.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "BuildingGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)


func _build_bottom_navigation(root: Control) -> void:
	bottom_nav_panel = PanelContainer.new()
	bottom_nav_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_nav_panel.offset_left = 16
	bottom_nav_panel.offset_top = -82
	bottom_nav_panel.offset_right = -16
	bottom_nav_panel.offset_bottom = -8
	root.add_child(bottom_nav_panel)
	GameUIStyle.apply_panel(bottom_nav_panel, "dock")

	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 8)
	bottom_nav_panel.add_child(nav_row)

	for item in ["BUILD", "FLEET", "WORLD", "ACTIVITIES", "SOCIAL", "MORE"]:
		var button := Button.new()
		button.text = item
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(88, 66)
		button.add_theme_font_size_override("font_size", 10)

		var tab: String = item.to_lower()
		_apply_button_icon(button, _nav_icon_for(tab), 27)
		GameUIStyle.apply_button(
			button,
			"dock_selected" if tab == "build" else "dock",
			true
		)
		nav_buttons[tab] = button
		if tab == "build":
			button.tooltip_text = "Airport home • building and layout tools"
			button.pressed.connect(_on_build_navigation_pressed)
		else:
			button.pressed.connect(_on_navigation_pressed.bind(tab))

		if tab == "activities":
			activities_nav_button = button
			button.tooltip_text = "Missions, Charter, weekly challenges, Alliance Operations and events"
		elif tab == "social":
			social_nav_button = button

		nav_row.add_child(button)

func _hud_icon(key: String) -> Texture2D:
	if hud_icon_textures.has(key):
		return hud_icon_textures[key] as Texture2D
	var svg_text := String(HUD_ICON_SVG.get(key, ""))
	if svg_text.is_empty():
		return null
	var image := Image.new()
	if image.load_svg_from_string(svg_text, 2.0) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	hud_icon_textures[key] = texture
	return texture


func _apply_button_icon(
	button: Button,
	texture: Texture2D,
	max_width: int
) -> void:
	if button == null or texture == null:
		return
	button.icon = texture
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", max_width)
	button.add_theme_constant_override("h_separation", 5)
	button.expand_icon = true


func _nav_icon_for(tab: String) -> Texture2D:
	if HUD_ICON_SVG.has(tab):
		return _hud_icon(tab)
	return _hud_icon("more")


func set_charter_available(value: bool, attention: bool = false) -> void:
	charter_activity_attention = value and attention
	_refresh_activities_nav()


func set_challenge_available(value: bool, attention: bool = false) -> void:
	challenge_activity_attention = value and attention
	_refresh_activities_nav()


func set_event_available(
	value: bool,
	event_name: String = ""
) -> void:
	# Events now live inside Activities. Keep this setter for existing event code.
	if not value:
		event_activity_attention = false
	_refresh_activities_nav()


func set_event_attention(claimable: bool) -> void:
	event_activity_attention = claimable
	_refresh_activities_nav()


func set_alliance_activity_attention(attention: bool) -> void:
	alliance_activity_attention = attention
	_refresh_activities_nav()


func set_mission_activity_attention(attention: bool) -> void:
	mission_activity_attention = attention
	_refresh_activities_nav()


func set_activities_attention(attention: bool) -> void:
	# Aggregate fallback for callers that already computed all activity states.
	if activities_nav_button == null:
		return
	activities_nav_button.text = "ACTIVITIES •" if attention else "ACTIVITIES"
	GameUIStyle.apply_button(
		activities_nav_button,
		"gold" if attention else "dock",
		true
	)


func _refresh_activities_nav() -> void:
	set_activities_attention(
		charter_activity_attention
		or challenge_activity_attention
		or event_activity_attention
		or alliance_activity_attention
		or mission_activity_attention
	)


func set_social_attention(active: bool) -> void:
	if social_nav_button == null:
		return
	if active:
		social_nav_button.text = "SOCIAL •"
		GameUIStyle.apply_button(
			social_nav_button,
			"gold",
			true
		)
	else:
		social_nav_button.text = "SOCIAL"
		GameUIStyle.apply_button(
			social_nav_button,
			"dock",
			true
		)


func set_interface_visible(value: bool) -> void:
	if interface_root != null:
		interface_root.visible = value



func set_airport_identity(
	airport_name: String,
	airport_code: String,
	country_name: String,
	account_type: String
) -> void:
	if title_label == null:
		return

	title_label.text = airport_name
	if airport_meta_label != null:
		var account_label := "GUEST" if account_type == "guest" else "LINKED"
		airport_meta_label.text = "%s • %s • %s" % [
			airport_code.to_upper(),
			country_name.to_upper(),
			account_label
		]
	if account_type == "guest":
		title_label.tooltip_text = (
			"Guest airport • secure or link later without losing progress."
		)
	else:
		title_label.tooltip_text = "Linked airport account"


func set_build_catalog(definitions: Array[Dictionary]) -> void:
	catalog_definitions = definitions
	var grid := _find_building_grid()
	if grid == null:
		return

	for child in grid.get_children():
		child.queue_free()
	catalog_buttons.clear()

	for definition in catalog_definitions:
		var button := Button.new()
		button.custom_minimum_size = Vector2(164, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.tooltip_text = String(definition.get("description", ""))
		GameUIStyle.apply_button(button, "build_card", true)
		var icon := _catalog_icon_for(definition)
		if icon != null:
			button.icon = icon
		var id := String(definition["id"])
		button.pressed.connect(_on_building_button_pressed.bind(id))
		grid.add_child(button)
		catalog_buttons[id] = button

	_update_catalog_buttons()
	_apply_catalog_filter()

func _on_catalog_filter_pressed(category: String) -> void:
	selected_catalog_category = category
	for key in catalog_filter_buttons.keys():
		var chip: Button = catalog_filter_buttons[key]
		GameUIStyle.apply_button(
			chip,
			"selected" if String(key) == category else "nav",
			true
		)
	_apply_catalog_filter()


func _apply_catalog_filter() -> void:
	var visible_total := 0
	var available_total := 0
	for definition in catalog_definitions:
		var id := String(definition.get("id", ""))
		if not catalog_buttons.has(id):
			continue
		var button: Button = catalog_buttons[id]
		var category := String(definition.get("category", ""))
		var visible := (
			selected_catalog_category == "ALL"
			or category == selected_catalog_category
		)
		button.visible = visible
		if visible:
			visible_total += 1
			if current_level >= int(definition.get("level", 1)):
				available_total += 1
	if catalog_count_label != null:
		catalog_count_label.text = "%d/%d AVAILABLE" % [
			available_total,
			visible_total
		]


func _catalog_icon_for(definition: Dictionary) -> Texture2D:
	# Prefer the exact world art so build/storage cards always preview
	# what the player will actually place on the airport.
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	var regions: Array = definition.get(
		"world_sprite_regions",
		[]
	)
	if not atlas_path.is_empty() and not regions.is_empty():
		var atlas_resource := load(atlas_path)
		if atlas_resource is Texture2D:
			var first_region = regions[0]
			if first_region is Rect2:
				var atlas_texture := AtlasTexture.new()
				atlas_texture.atlas = atlas_resource as Texture2D
				atlas_texture.region = first_region
				return atlas_texture

	var variants: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if not variants.is_empty():
		var world_resource := load(variants[0])
		if world_resource is Texture2D:
			return world_resource as Texture2D

	var single_world_path := String(
		definition.get("world_sprite_path", "")
	)
	if not single_world_path.is_empty():
		var single_world_resource := load(single_world_path)
		if single_world_resource is Texture2D:
			return single_world_resource as Texture2D

	var path := String(definition.get("icon_path", ""))
	if path.is_empty():
		return null
	var resource := load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _find_building_grid() -> GridContainer:
	var root := get_child(0)
	if root == null:
		return null
	return root.find_child("BuildingGrid", true, false) as GridContainer


func set_player_data(level: int, coins: int, gems: int) -> void:
	current_level = level
	current_coins = coins
	current_gems = gems
	level_label.text = "%d" % level
	coins_label.text = _format_number(coins)
	gems_label.text = _format_number(gems)
	_update_catalog_buttons()

	if (
		not active_building_id.is_empty()
		and active_build_mode == "build"
	):
		var definition := BuildingCatalog.get_definition(active_building_id)
		show_build_preview(definition, {}, current_level, current_coins)
	elif (
		active_build_mode.is_empty()
		and active_building_id.is_empty()
		and not current_parcel.is_empty()
	):
		show_parcel(current_parcel, current_level, current_coins)






func set_level_progress(
	xp: int,
	level_start_xp: int,
	next_level_xp: int,
	max_level: bool = false
) -> void:
	if xp_progress == null or xp_label == null:
		return
	if max_level or next_level_xp <= level_start_xp:
		xp_progress.min_value = 0.0
		xp_progress.max_value = 1.0
		xp_progress.value = 1.0
		xp_label.text = "MAX"
		return
	var span := maxi(next_level_xp - level_start_xp, 1)
	var earned := clampi(xp - level_start_xp, 0, span)
	xp_progress.min_value = 0.0
	xp_progress.max_value = float(span)
	xp_progress.value = float(earned)
	xp_label.text = "%s/%s" % [
		_format_number(earned),
		_format_number(span)
	]


func set_passenger_data(
	passengers: int,
	capacity: int,
	per_minute: float
) -> void:
	if passenger_label == null:
		return
	passenger_label.text = "%d / %d" % [
		passengers,
		capacity
	]
	if passenger_rate_label != null:
		passenger_rate_label.text = "+%.1f/m" % per_minute


func set_fuel_data(
	fuel: int,
	capacity: int,
	per_minute: float
) -> void:
	if fuel_label == null:
		return

	fuel_label.text = "%d / %d" % [fuel, capacity]
	var ratio := 1.0
	if capacity > 0:
		ratio = clampf(
			float(maxi(fuel, 0)) / float(capacity),
			0.0,
			1.0
		)

	var status := "normal"
	if capacity > 0 and ratio <= 0.10:
		status = "critical"
	elif capacity > 0 and ratio <= 0.25:
		status = "low"

	if fuel_rate_label != null:
		match status:
			"critical":
				fuel_rate_label.text = "CRITICAL • +%.1f/m" % per_minute
				fuel_rate_label.add_theme_color_override(
					"font_color",
					GameUIStyle.COLOR_DANGER
				)
			"low":
				fuel_rate_label.text = "LOW • +%.1f/m" % per_minute
				fuel_rate_label.add_theme_color_override(
					"font_color",
					GameUIStyle.COLOR_WARNING
				)
			_:
				fuel_rate_label.text = "+%.1f/m" % per_minute
				GameUIStyle.muted(fuel_rate_label)

	if fuel_panel != null:
		GameUIStyle.apply_panel(
			fuel_panel,
			"hud_fuel_critical"
			if status == "critical"
			else (
				"hud_fuel_low"
				if status == "low"
				else "hud_fuel"
			)
		)

	if fuel_order_button != null:
		fuel_order_button.disabled = capacity <= 0 or fuel >= capacity
		fuel_order_button.tooltip_text = "Order fuel • 750 coins"
		GameUIStyle.apply_button(
			fuel_order_button,
			"danger"
			if status == "critical"
			else ("gold" if status == "low" else "secondary")
		)

func show_parcel(parcel: Dictionary, player_level: int, player_coins: int) -> void:
	current_parcel = parcel.duplicate(true)
	current_level = player_level
	current_coins = player_coins

	if (
		not active_building_id.is_empty()
		or active_build_mode == "airport_edit"
	):
		return

	parcel_panel.visible = true
	build_action_panel.visible = false

	if parcel.is_empty():
		parcel_title.text = "EXPAND AIRPORT"
		parcel_requirements.text = "Select a connected expansion district."
		purchase_button.text = "SELECT LAND"
		purchase_button.disabled = true
		return

	var zone_name := String(
		parcel.get(
			"name",
			String(parcel.get("id", "land")).replace("_", " ").capitalize()
		)
	)
	var zone_tag := String(parcel.get("tag", "EXPANSION"))
	var purpose := String(
		parcel.get(
			"purpose",
			"Additional airport building space."
		)
	)
	var unlock_names_value = parcel.get("unlock_names", [])
	var unlock_names := PackedStringArray()
	if unlock_names_value is Array:
		for name_variant in unlock_names_value:
			unlock_names.append(String(name_variant))

	if parcel.get("owned", false):
		parcel_title.text = zone_name.to_upper()
		parcel_requirements.text = "OWNED • %s\n%s" % [
			zone_tag,
			purpose
		]
		purchase_button.text = "OWNED"
		purchase_button.disabled = true
		return

	var required_level := int(parcel.get("level", 1))
	var cost := int(parcel.get("cost", 0))
	var progression_state := String(
		parcel.get("progression_state", "future")
	)

	parcel_title.text = zone_name.to_upper()
	if progression_state == "future":
		parcel_requirements.text = "%s • %s\nConnect adjacent airport land • Lv %d" % [
			zone_tag,
			purpose,
			required_level
		]
		purchase_button.text = "NOT CONNECTED"
		purchase_button.disabled = true
		return

	var detail := "%s • %s\nLv %d • 🪙 %s" % [
		zone_tag,
		purpose,
		required_level,
		_format_number(cost)
	]
	if not unlock_names.is_empty():
		detail += " • Best for: %s" % " / ".join(unlock_names)
	parcel_requirements.text = detail

	if player_level < required_level:
		purchase_button.text = "REQUIRES LV %d" % required_level
		purchase_button.disabled = true
	elif player_coins < cost:
		purchase_button.text = "NEED 🪙 %s" % _format_number(cost - player_coins)
		purchase_button.disabled = true
	else:
		purchase_button.text = "BUY  🪙 %s" % _format_number(cost)
		purchase_button.disabled = false


func enter_building_mode(definition: Dictionary) -> void:
	active_building_id = String(definition["id"])
	active_build_mode = "build"
	if catalog_panel != null:
		catalog_panel.visible = false
	build_hint.text = "PLACING BUILDING  •  Tap owned land • use Rotate / Place / Cancel below"
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = String(definition["name"]).to_upper()
	var footprint: Vector2i = definition["footprint"]
	build_status.text = "%s  •  %dx%d  •  %s%s" % [
		String(definition["description"]),
		footprint.x,
		footprint.y,
		_size_text(definition),
		_service_text(definition)
	]
	store_button.visible = false
	_reset_expand_here_action()
	rotate_button.visible = bool(definition.get("rotatable", false))
	place_button.text = "TAP LAND"
	place_button.disabled = true


func show_build_preview(definition: Dictionary, status: Dictionary, player_level: int, player_coins: int) -> void:
	if definition.is_empty():
		return

	active_building_id = String(definition["id"])
	active_build_mode = "build"
	if catalog_panel != null:
		catalog_panel.visible = false
	build_hint.text = "PLACING BUILDING  •  Tap owned land • use Rotate / Place / Cancel below"
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	current_level = player_level
	current_coins = player_coins
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = String(definition["name"]).to_upper()
	store_button.visible = false
	_reset_expand_here_action()
	rotate_button.visible = bool(definition.get("rotatable", false))

	var required_level := int(definition["level"])
	var cost := int(definition["cost"])

	if player_level < required_level:
		build_status.text = "Locked until airport Lv %d." % required_level
		place_button.text = "LV %d" % required_level
		place_button.disabled = true
		return

	if player_coins < cost:
		build_status.text = "Need 🪙 %s more." % _format_number(cost - player_coins)
		place_button.text = "🪙 %s" % _format_number(cost)
		place_button.disabled = true
		return

	_update_placement_expand_action(status)

	if status.is_empty():
		build_status.text = "Tap owned land to preview • Cost 🪙 %s" % _format_number(cost)
		place_button.text = "TAP LAND"
		place_button.disabled = true
		return

	if not bool(status.get("valid", false)):
		build_status.text = "Cannot build: %s" % String(status.get("reason", "Invalid placement."))
		place_button.text = "MOVE"
		place_button.disabled = true
		return

	var footprint: Vector2i = status.get("footprint", definition["footprint"])
	build_status.text = "Valid %dx%d • %s%s • Cost 🪙 %s" % [
		footprint.x,
		footprint.y,
		_size_text(definition),
		_service_text(definition),
		_format_number(cost)
	]

	var warning := String(status.get("warning", ""))
	if not warning.is_empty():
		build_status.text += "  •  ⚠ " + warning
	build_status.text += _synergy_preview_suffix(status)
	place_button.text = "BUILD  🪙 %s" % _format_number(cost)
	place_button.disabled = false


func enter_move_mode(definition: Dictionary) -> void:
	if definition.is_empty():
		return

	active_building_id = String(definition.get("id", ""))
	active_build_mode = "move"
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = "MOVE %s" % String(
		definition.get("name", "BUILDING")
	).to_upper()
	build_status.text = (
		"Drag or tap a new position • Moving is free"
	)
	store_button.visible = true
	_reset_expand_here_action()
	rotate_button.visible = bool(
		definition.get("rotatable", false)
	)
	place_button.text = "CONFIRM MOVE"
	place_button.disabled = false


func show_move_preview(
	definition: Dictionary,
	status: Dictionary
) -> void:
	if definition.is_empty():
		return

	active_building_id = String(definition.get("id", ""))
	active_build_mode = "move"
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = "MOVE %s" % String(
		definition.get("name", "BUILDING")
	).to_upper()
	store_button.visible = true
	_update_placement_expand_action(status)
	rotate_button.visible = bool(
		definition.get("rotatable", false)
	)

	if status.is_empty():
		build_status.text = (
			"Drag or tap a new position • Moving is free"
		)
		place_button.text = "CONFIRM MOVE"
		place_button.disabled = true
		return

	if not bool(status.get("valid", false)):
		build_status.text = "Cannot move: %s" % String(
			status.get("reason", "Invalid placement.")
		)
		place_button.text = "BLOCKED"
		place_button.disabled = true
		return

	var footprint: Vector2i = status.get(
		"footprint",
		definition.get("footprint", Vector2i.ONE)
	)
	build_status.text = "Valid %dx%d • Move FREE" % [
		footprint.x,
		footprint.y
	]
	var warning := String(status.get("warning", ""))
	if not warning.is_empty():
		build_status.text += "  •  ⚠ " + warning
	build_status.text += _synergy_preview_suffix(status)
	place_button.text = "CONFIRM MOVE"
	place_button.disabled = false


func enter_stored_building_mode(
	definition: Dictionary,
	building: Dictionary
) -> void:
	if definition.is_empty() or building.is_empty():
		return

	active_building_id = String(definition.get("id", ""))
	active_build_mode = "stored"
	if storage_panel != null:
		storage_panel.visible = false
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = "PLACE STORED %s" % String(
		definition.get("name", "BUILDING")
	).to_upper()
	build_status.text = "Tap owned land to place • FREE"
	store_button.visible = false
	_reset_expand_here_action()
	rotate_button.visible = bool(
		definition.get("rotatable", false)
	)
	place_button.text = "TAP LAND"
	place_button.disabled = true


func show_stored_building_preview(
	definition: Dictionary,
	status: Dictionary
) -> void:
	if definition.is_empty():
		return

	active_building_id = String(definition.get("id", ""))
	active_build_mode = "stored"
	if storage_panel != null:
		storage_panel.visible = false
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = "PLACE STORED %s" % String(
		definition.get("name", "BUILDING")
	).to_upper()
	store_button.visible = false
	_update_placement_expand_action(status)
	rotate_button.visible = bool(
		definition.get("rotatable", false)
	)

	if status.is_empty():
		build_status.text = "Tap owned land to place • FREE"
		place_button.text = "TAP LAND"
		place_button.disabled = true
		return

	if not bool(status.get("valid", false)):
		build_status.text = "Cannot place: %s" % String(
			status.get("reason", "Invalid placement.")
		)
		place_button.text = "BLOCKED"
		place_button.disabled = true
		return

	var footprint: Vector2i = status.get(
		"footprint",
		definition.get("footprint", Vector2i.ONE)
	)
	build_status.text = "Valid %dx%d • Place from storage FREE" % [
		footprint.x,
		footprint.y
	]
	var warning := String(status.get("warning", ""))
	if not warning.is_empty():
		build_status.text += "  •  ⚠ " + warning
	build_status.text += _synergy_preview_suffix(status)
	place_button.text = "PLACE"
	place_button.disabled = false



func set_stored_buildings(
	buildings: Array[Dictionary]
) -> void:
	if storage_list == null:
		return

	for child in storage_list.get_children():
		child.queue_free()

	var count := buildings.size()
	storage_count_label.text = "%d STORED" % count
	if storage_button != null:
		storage_button.text = "📦 STORAGE %d" % count

	if count <= 0:
		var empty_label := Label.new()
		empty_label.text = (
			"No stored buildings. Select a movable building and tap STORE."
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 11)
		GameUIStyle.muted(empty_label)
		storage_list.add_child(empty_label)
		return

	for building in buildings:
		var uid := int(building.get("uid", -1))
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if uid < 0 or definition.is_empty():
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(330, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		var footprint: Vector2i = definition.get(
			"footprint",
			Vector2i.ONE
		)
		if int(building.get("rotation", 0)) % 2 == 1:
			footprint = Vector2i(
				footprint.y,
				footprint.x
			)
		button.text = "%s • LV %d\\n%dx%d • PLACE FREE" % [
			String(definition.get("name", "Building")),
			int(building.get("upgrade_level", 1)),
			footprint.x,
			footprint.y
		]
		var icon := _catalog_icon_for(definition)
		if icon != null:
			button.icon = icon
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.expand_icon = true
			button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		GameUIStyle.apply_button(button, "secondary", true)
		button.pressed.connect(
			_on_stored_building_pressed.bind(uid)
		)
		storage_list.add_child(button)

func _reset_expand_here_action() -> void:
	active_expand_parcel_id = ""
	if expand_here_button == null:
		return
	expand_here_button.visible = false
	expand_here_button.disabled = true
	if place_button != null:
		place_button.visible = true


func _update_placement_expand_action(
	status: Dictionary
) -> void:
	_reset_expand_here_action()
	if status.is_empty() or expand_here_button == null:
		return

	var parcel_id := String(
		status.get("locked_parcel_id", "")
	)
	if parcel_id.is_empty():
		return

	active_expand_parcel_id = parcel_id
	expand_here_button.visible = true
	if place_button != null:
		place_button.visible = false

	var progression_state := String(
		status.get(
			"locked_parcel_state",
			"available"
		)
	)
	if progression_state == "future":
		expand_here_button.text = "CONNECT LAND\nFIRST"
		expand_here_button.disabled = true
		return

	var required_level := int(
		status.get("locked_parcel_level", 1)
	)
	var cost := int(
		status.get("locked_parcel_cost", 0)
	)
	var reserved_build_cost := 0
	if active_build_mode == "build":
		var definition := BuildingCatalog.get_definition(
			active_building_id
		)
		if not definition.is_empty():
			reserved_build_cost = maxi(
				int(definition.get("cost", 0)),
				0
			)
	var total_required_coins := cost + reserved_build_cost

	if current_level < required_level:
		expand_here_button.text = "EXPAND HERE\nLV %d" % required_level
		expand_here_button.disabled = true
		return

	if current_coins < total_required_coins:
		expand_here_button.text = "NEED 🪙 %s" % _format_number(
			total_required_coins - current_coins
		)
		expand_here_button.disabled = true
		return

	expand_here_button.text = "EXPAND HERE\n🪙 %s" % _format_number(
		cost
	)
	expand_here_button.disabled = false


func show_airport_edit_mode(
	active: bool,
	can_undo: bool = false,
	message: String = ""
) -> void:
	active_building_id = ""
	active_build_mode = "airport_edit" if active else ""
	build_action_panel.visible = false
	_reset_expand_here_action()
	airport_edit_panel.visible = active
	if storage_panel != null:
		storage_panel.visible = false
	if catalog_panel != null:
		catalog_panel.visible = not active

	if active:
		parcel_panel.visible = false
		build_hint.text = (
			"EDIT AIRPORT  •  Tap a movable building to reposition it"
		)
		undo_airport_edit_button.disabled = not can_undo
		airport_edit_status.text = (
			message
			if not message.is_empty()
			else "Tap a movable building • Confirm each move"
		)
	else:
		build_hint.text = (
			"AIRPORT VIEW  •  Tap aircraft/buildings for actions  •  BUILD opens construction"
		)
		airport_edit_status.text = (
			"Tap a movable building • changes save when confirmed"
		)
		undo_airport_edit_button.disabled = true
		parcel_panel.visible = true
		show_parcel(
			current_parcel,
			current_level,
			current_coins
		)


func set_airport_edit_undo_available(
	can_undo: bool
) -> void:
	if undo_airport_edit_button != null:
		undo_airport_edit_button.disabled = not can_undo


func show_airport_expanded(
	parcel_name: String,
	tile_count: int = 64,
	milestone: String = ""
) -> void:
	if expansion_banner == null:
		return

	if (
		expansion_banner_tween != null
		and expansion_banner_tween.is_valid()
	):
		expansion_banner_tween.kill()

	expansion_banner_title.text = "AIRPORT EXPANDED"
	expansion_banner_detail.text = "%s • +%d build tiles" % [
		parcel_name.to_upper(),
		tile_count
	]
	if not milestone.is_empty():
		expansion_banner_detail.text += "\n" + milestone
	expansion_banner.visible = true
	expansion_banner.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	expansion_banner_tween = create_tween()
	expansion_banner_tween.tween_property(
		expansion_banner,
		"modulate:a",
		1.0,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expansion_banner_tween.tween_interval(0.72)
	expansion_banner_tween.tween_property(
		expansion_banner,
		"modulate:a",
		0.0,
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	expansion_banner_tween.tween_callback(
		Callable(self, "_hide_expansion_banner")
	)


func _hide_expansion_banner() -> void:
	if expansion_banner != null:
		expansion_banner.visible = false


func set_starter_tutorial(snapshot: Dictionary) -> void:
	if (
		tutorial_objective_panel == null
		or tutorial_objective_button == null
	):
		return

	var active := bool(snapshot.get("active", false))
	var complete := bool(snapshot.get("complete", false))
	var title_value := String(snapshot.get("title", ""))
	if not active and complete and title_value.is_empty():
		tutorial_objective_panel.visible = false
		return
	tutorial_objective_panel.visible = active or complete

	if complete:
		tutorial_action = ""
		tutorial_target = ""
		tutorial_objective_button.text = (
			"AIRPORT BASICS • COMPLETE"
		)
		tutorial_objective_button.tooltip_text = String(
			snapshot.get(
				"guidance",
				"Starter airport tutorial complete."
			)
		)
		tutorial_objective_button.disabled = true
		return

	tutorial_action = String(
		snapshot.get("action", "")
	)
	tutorial_target = String(
		snapshot.get("target", "")
	)
	var step := int(snapshot.get("step", 1))
	var total := maxi(int(snapshot.get("total", 1)), 1)
	var title := String(snapshot.get("title", "Airport basics"))
	var reward := maxi(int(snapshot.get("reward", 0)), 0)
	tutorial_objective_button.text = (
		"%d/%d • %s%s" % [
			step,
			total,
			title.to_upper(),
			(
				" • +%s" % _format_number(reward)
				if reward > 0
				else ""
			)
		]
	)
	tutorial_objective_button.tooltip_text = String(
		snapshot.get("guidance", "")
	)
	tutorial_objective_button.disabled = (
		tutorial_action.is_empty()
	)


func _on_tutorial_objective_pressed() -> void:
	if tutorial_action.is_empty():
		return
	tutorial_action_requested.emit(
		tutorial_action,
		tutorial_target
	)


func set_operation_status(
	text: String,
	tone: String = "normal"
) -> void:
	var changed := (
		text != current_operation_status_text
		or tone != current_operation_status_tone
	)
	current_operation_status_text = text
	current_operation_status_tone = tone
	_refresh_operations_status()
	if changed and tone in ["success", "warning", "danger"]:
		_show_operation_toast(text, tone)


func set_operations_analytics(
	snapshot: Dictionary
) -> void:
	operations_analytics = snapshot.duplicate(true)
	_refresh_operations_status()


func _refresh_operations_status() -> void:
	if operation_status_label != null:
		operation_status_label.text = (
			"GROUND OPS\n"
			+ current_operation_status_text
		)

	var body := current_operation_status_text
	var live_value = operations_analytics.get(
		"live",
		{}
	)
	if live_value is Dictionary:
		var live: Dictionary = live_value
		if not live.is_empty():
			body += "\n\nLIVE TRAFFIC"
			body += "\nStands %d/%d • Taxi %d • Airborne %d" % [
				int(live.get("stands_occupied", 0)),
				int(live.get("stands_total", 0)),
				int(live.get("taxiing", 0)),
				int(live.get("airborne", 0))
			]
			body += "\nRunway %d active • %d waiting • Ground %d active • %d waiting" % [
				int(live.get("runway_active", 0)),
				int(live.get("runway_waiting", 0)),
				int(live.get("ground_active", 0)),
				int(live.get("ground_waiting", 0))
			]

			var inbound_holding := int(
				live.get("inbound_holding", 0)
			)
			var taxi_holds := int(
				live.get("taxi_holds", 0)
			)
			var waiting_passengers := int(
				live.get("waiting_passengers", 0)
			)
			if (
				inbound_holding > 0
				or taxi_holds > 0
				or waiting_passengers > 0
			):
				body += "\nHolding: %d inbound • %d taxi • %d passenger" % [
					inbound_holding,
					taxi_holds,
					waiting_passengers
				]

			var aircraft_value = live.get("aircraft", [])
			if aircraft_value is Array:
				var aircraft_rows: Array = aircraft_value
				var aircraft_limit := mini(
					aircraft_rows.size(),
					4
				)
				if aircraft_limit > 0:
					body += "\n\nAIRCRAFT"
					for index in range(aircraft_limit):
						var row: Dictionary = aircraft_rows[index]
						var phase := String(
							row.get("phase", "Operating")
						)
						var progress := float(
							row.get("phase_progress", -1.0)
						)
						var line := "%s • %s" % [
							String(row.get("label", "Aircraft")),
							phase
						]
						if progress >= 0.0:
							line += " • %d%%" % int(
								round(progress * 100.0)
							)
						var blocked := String(
							row.get("blocking_reason", "")
						)
						if not blocked.is_empty():
							line += "\n  ↳ %s" % blocked
						body += "\n" + line

	var analysis_value = operations_analytics.get(
		"analysis",
		{}
	)
	if analysis_value is Dictionary:
		var analysis: Dictionary = analysis_value
		var recommendation_value = analysis.get(
			"recommendation",
			{}
		)
		if recommendation_value is Dictionary:
			var recommendation: Dictionary = recommendation_value
			if not recommendation.is_empty():
				body += "\n\nBOTTLENECK • %s\n%s" % [
					String(
						recommendation.get(
							"title",
							"Operations healthy"
						)
					),
					String(
						recommendation.get(
							"detail",
							""
						)
					)
				]

		var ranked_value = analysis.get("ranked", [])
		if ranked_value is Array:
			var ranked: Array = ranked_value
			var limit := mini(ranked.size(), 3)
			if limit > 0:
				body += "\n\nTOP PRESSURE"
				for index in range(limit):
					var item: Dictionary = ranked[index]
					body += "\n%d. %s • %s" % [
						index + 1,
						String(item.get("name", "System")),
						String(item.get("detail", ""))
					]

	var payoff_value = operations_analytics.get(
		"payoff",
		{}
	)
	if payoff_value is Dictionary:
		var payoff: Dictionary = payoff_value
		var best_value_variant = payoff.get(
			"best_value",
			{}
		)
		if best_value_variant is Dictionary:
			var best_value: Dictionary = best_value_variant
			if not best_value.is_empty():
				body += "\n\nBEST PAYOFF\n%s" % String(
					best_value.get(
						"title",
						"Upgrade"
					)
				)
				body += "\n~%.1fs saved • %.1fs / 10k coins • 🪙 %d" % [
					float(
						best_value.get(
							"estimated_delay_saved_seconds",
							0.0
						)
					),
					float(
						best_value.get(
							"delay_saved_per_10k",
							0.0
						)
					),
					int(
						best_value.get(
							"coin_cost",
							0
						)
					)
				]
				var missing_total := int(
					best_value.get(
						"resource_missing_total",
						0
					)
				)
				if missing_total > 0:
					body += " • %d resource%s missing" % [
						missing_total,
						"" if missing_total == 1 else "s"
					]
				elif bool(
					best_value.get(
						"affordable_now",
						false
					)
				):
					body += " • READY NOW"

		var affordable_variant = payoff.get(
			"best_affordable",
			{}
		)
		if affordable_variant is Dictionary:
			var affordable: Dictionary = affordable_variant
			if (
				not affordable.is_empty()
				and (
					not (
						best_value_variant is Dictionary
					)
					or String(
						affordable.get("id", "")
					) != String(
						(best_value_variant as Dictionary).get(
							"id",
							""
						)
					)
				)
			):
				body += "\n\nBEST BUY NOW\n%s" % String(
					affordable.get(
						"title",
						"Upgrade"
					)
				)
				body += "\n~%.1fs saved • %.1fs / 10k coins • 🪙 %d" % [
					float(
						affordable.get(
							"estimated_delay_saved_seconds",
							0.0
						)
					),
					float(
						affordable.get(
							"delay_saved_per_10k",
							0.0
						)
					),
					int(
						affordable.get(
							"coin_cost",
							0
						)
					)
				]

	var chip_tone := current_operation_status_tone
	if chip_tone == "normal" and live_value is Dictionary:
		var live_tone: Dictionary = live_value
		if (
			int(live_tone.get("inbound_holding", 0)) > 0
			or int(live_tone.get("taxi_holds", 0)) > 0
			or int(live_tone.get("runway_waiting", 0)) > 0
			or int(live_tone.get("ground_waiting", 0)) > 0
			or int(live_tone.get("waiting_passengers", 0)) > 0
		):
			chip_tone = "warning"
	if chip_tone == "normal":
		var tone_analysis_value = operations_analytics.get(
			"analysis",
			{}
		)
		if tone_analysis_value is Dictionary:
			var tone_analysis: Dictionary = tone_analysis_value
			var recommendation_value = tone_analysis.get(
				"recommendation",
				{}
			)
			if recommendation_value is Dictionary:
				var recommendation: Dictionary = recommendation_value
				if String(
					recommendation.get(
						"tone",
						"normal"
					)
				) == "warning":
					chip_tone = "warning"

	_set_status_chip(
		"operations",
		operation_status_chip,
		"GROUND OPS",
		_compact_status(
			current_operation_status_text
		),
		body,
		chip_tone
	)


func set_atc_state(snapshot: Dictionary) -> void:
	var atc_level := int(
		snapshot.get("atc_level", 0)
	)
	var multiplier := float(
		snapshot.get("separation_multiplier", 1.0)
	)
	var control_text := "BASE ATC"
	if atc_level > 0:
		control_text = "ATC LV %d • x%.2f" % [
			atc_level,
			multiplier
		]

	var primary_value = snapshot.get("primary_runway", {})
	var primary: Dictionary = {}
	if primary_value is Dictionary:
		primary = primary_value

	if primary.is_empty():
		var empty_text := "%s • No active movements" % control_text
		var empty_tone := "success"
		var empty_compact := "✓ CLEAR"
		var analytics_value = snapshot.get("analytics", {})
		if analytics_value is Dictionary:
			var analytics: Dictionary = analytics_value
			if not analytics.is_empty():
				empty_text += "\n%.0f%% util • %.1fs avg wait" % [
					float(
						analytics.get(
							"average_utilization_pct",
							0.0
						)
					),
					float(
						analytics.get(
							"average_wait_seconds",
							0.0
						)
					)
				]
				var recommendation_value = analytics.get(
					"recommendation",
					{}
				)
				if recommendation_value is Dictionary:
					var recommendation: Dictionary = recommendation_value
					if not recommendation.is_empty():
						empty_text += "\nAdvice: %s" % String(
							recommendation.get(
								"title",
								"Keep monitoring"
							)
						)
						if String(
							recommendation.get(
								"tone",
								"normal"
							)
						) == "warning":
							empty_tone = "warning"
							empty_compact = "⚠ CAPACITY REVIEW"
		if atc_status_label != null:
			atc_status_label.text = "RUNWAY CONTROL\n" + empty_text
		_set_status_chip(
			"atc",
			atc_status_chip,
			"RUNWAY CONTROL",
			empty_compact,
			empty_text,
			empty_tone
		)
		return

	var runway_uid := int(primary.get("runway_uid", -1))
	var strategy_label := String(
		primary.get("strategy_label", "AUTO")
	)
	var sequence := String(
		primary.get("sequence_text", "CLEAR")
	)
	var spacing := float(
		primary.get("separation_remaining", 0.0)
	)
	var status := String(primary.get("status", "clear"))
	var waiting := int(primary.get("waiting", 0))

	var detail := "%s • RWY %d • %s\n%s" % [
		control_text,
		runway_uid,
		strategy_label,
		sequence
	]

	var analytics_value = snapshot.get("analytics", {})
	var analytics: Dictionary = {}
	if analytics_value is Dictionary:
		analytics = analytics_value
	if not analytics.is_empty():
		detail += "\n%.0f%% util • %.1fs avg wait • %.0f%% separation delay" % [
			float(
				analytics.get(
					"average_utilization_pct",
					0.0
				)
			),
			float(
				analytics.get(
					"average_wait_seconds",
					0.0
				)
			),
			float(
				analytics.get(
					"separation_delay_pct",
					0.0
				)
			)
		]
		var recommendation_value = analytics.get(
			"recommendation",
			{}
		)
		if recommendation_value is Dictionary:
			var recommendation: Dictionary = recommendation_value
			if not recommendation.is_empty():
				detail += "\nAdvice: %s" % String(
					recommendation.get(
						"title",
						"Keep monitoring"
					)
				)

	var tone := "success"
	var compact := "✓ RWY %d CLEAR" % runway_uid
	if status.begins_with("occupied"):
		tone = "danger"
		compact = "● RWY %d BUSY" % runway_uid
	elif spacing > 0.001 or waiting > 0:
		tone = "warning"
		compact = "⏳ RWY %d • %d WAIT" % [
			runway_uid,
			waiting
		]

	if tone == "success" and not analytics.is_empty():
		var recommendation_value = analytics.get(
			"recommendation",
			{}
		)
		if recommendation_value is Dictionary:
			var recommendation: Dictionary = recommendation_value
			if String(
				recommendation.get(
					"tone",
					"normal"
				)
			) == "warning":
				tone = "warning"
				compact = "⚠ CAPACITY REVIEW"

	if atc_status_label != null:
		atc_status_label.text = "RUNWAY CONTROL\n" + detail

	_set_status_chip(
		"atc",
		atc_status_chip,
		"RUNWAY CONTROL",
		compact,
		detail,
		tone
	)


func set_airside_status(status: Dictionary) -> void:
	var stands_total := int(status.get("stands_total", 0))
	var stands_connected := int(status.get("stands_connected", 0))
	var hangars_total := int(status.get("hangars_total", 0))
	var hangars_connected := int(status.get("hangars_connected", 0))
	var runways := int(status.get("runways", 0))

	var detail := ""
	var compact := ""
	var tone := "success"

	if (
		stands_connected == stands_total
		and hangars_connected == hangars_total
	):
		detail = "%d runway%s • %d/%d stands connected" % [
			runways,
			"" if runways == 1 else "s",
			stands_connected,
			stands_total
		]
		compact = "✓ %d/%d STANDS" % [
			stands_connected,
			stands_total
		]
	else:
		var disconnected := (
			(stands_total - stands_connected)
			+ (hangars_total - hangars_connected)
		)
		detail = "%d airside building%s need taxiway" % [
			disconnected,
			"" if disconnected == 1 else "s"
		]
		compact = "⚠ %d DISCONNECTED" % disconnected
		tone = "warning"

	if airside_status_label != null:
		airside_status_label.text = "AIRFIELD\n" + detail

	_set_status_chip(
		"airside",
		airside_status_chip,
		"AIRFIELD",
		compact,
		detail,
		tone
	)



func _set_status_chip(
	key: String,
	chip: Button,
	title: String,
	compact: String,
	body: String,
	tone: String
) -> void:
	status_details[key] = {
		"title": title,
		"body": body,
		"tone": tone
	}
	if chip != null:
		chip.text = "%s • %s" % [
			_status_icon(key),
			compact
		]
		GameUIStyle.apply_button(
			chip,
			_status_button_kind(
				tone,
				active_status_chip == key
			),
			true
		)

	if active_status_chip == key:
		_refresh_status_detail()


func _status_icon(key: String) -> String:
	match key:
		"airside":
			return "AIR"
		"operations":
			return "OPS"
		_:
			return "ATC"

func _status_button_kind(
	tone: String,
	active: bool
) -> String:
	if active:
		return "selected"
	match tone:
		"warning":
			return "gold"
		"danger":
			return "danger"
		_:
			return "nav"



func _compact_status(text: String) -> String:
	var compact := text.replace("\n", " • ")
	if compact.length() > 20:
		compact = compact.substr(0, 17) + "..."
	return compact.to_upper()

func _on_status_chip_pressed(key: String) -> void:
	if active_status_chip == key and status_detail_panel.visible:
		_close_status_detail()
		return

	active_status_chip = key
	status_detail_panel.visible = true
	_refresh_all_status_chip_styles()
	_refresh_status_detail()


func _close_status_detail() -> void:
	active_status_chip = ""
	if status_detail_panel != null:
		status_detail_panel.visible = false
	_refresh_all_status_chip_styles()


func _refresh_status_detail() -> void:
	if active_status_chip.is_empty():
		return
	var data: Dictionary = status_details.get(
		active_status_chip,
		{}
	)
	if data.is_empty():
		return

	status_detail_title.text = String(
		data.get("title", "AIRPORT STATUS")
	)
	status_detail_body.text = String(
		data.get("body", "")
	)

	var tone := String(data.get("tone", "normal"))
	match tone:
		"warning":
			status_detail_title.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_WARNING
			)
		"danger":
			status_detail_title.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_DANGER
			)
		"success":
			status_detail_title.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_SUCCESS
			)
		_:
			status_detail_title.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_TEXT
			)


func _refresh_all_status_chip_styles() -> void:
	for key in ["airside", "operations", "atc"]:
		var chip: Button = null
		match key:
			"airside":
				chip = airside_status_chip
			"operations":
				chip = operation_status_chip
			"atc":
				chip = atc_status_chip
		if chip == null:
			continue
		var data: Dictionary = status_details.get(key, {})
		GameUIStyle.apply_button(
			chip,
			_status_button_kind(
				String(data.get("tone", "normal")),
				active_status_chip == key
			),
			true
		)


func exit_building_mode() -> void:
	active_building_id = ""
	active_build_mode = ""
	_reset_expand_here_action()
	build_action_panel.visible = false
	if airport_edit_panel != null:
		airport_edit_panel.visible = false
	if storage_panel != null:
		storage_panel.visible = false
	if catalog_panel != null:
		catalog_panel.visible = true
	build_hint.text = "AIRPORT VIEW  •  Tap aircraft/buildings for actions  •  BUILD opens construction"
	parcel_panel.visible = true
	show_parcel(current_parcel, current_level, current_coins)


func _update_catalog_buttons() -> void:
	for definition in catalog_definitions:
		var id := String(definition["id"])
		if not catalog_buttons.has(id):
			continue
		var button: Button = catalog_buttons[id]
		var required_level := int(definition["level"])
		var cost := int(definition["cost"])

		if current_level < required_level:
			GameUIStyle.apply_button(button, "build_card_locked", true)
			button.text = "%s\nLOCKED • LV %d" % [
				String(definition["menu_name"]),
				required_level
			]
			button.disabled = true
		else:
			var selected := id == active_building_id
			GameUIStyle.apply_button(
				button,
				"build_card_selected" if selected else "build_card",
				true
			)
			button.text = "%s%s\n%s COINS • LV %d • %s" % [
				"SELECTED • " if selected else "",
				String(definition["menu_name"]),
				_format_number(cost),
				required_level,
				_size_text(definition)
			]
			button.disabled = false
	_apply_catalog_filter()


func _service_text(definition: Dictionary) -> String:
	var services: Dictionary = definition.get("services", {})
	if not services.is_empty():
		var names: Array[String] = []
		for service_type in services.keys():
			names.append(_service_short_name(String(service_type)))
		names.sort()
		var first_data: Dictionary = services[services.keys()[0]]
		var speed := float(first_data.get("service_speed", 1.0))
		var vehicles := int(first_data.get("vehicle_capacity", 1))
		return " • %s x%.2f • %d each" % [
			"/".join(names),
			speed,
			vehicles
		]

	var service_type := String(definition.get("service", ""))
	if service_type.is_empty():
		return ""

	var speed := float(definition.get("service_speed", 1.0))
	var vehicles := int(definition.get("vehicle_capacity", 1))
	return " • %s x%.2f • %d vehicle%s" % [
		_service_short_name(service_type),
		speed,
		vehicles,
		"" if vehicles == 1 else "s"
	]


func _service_short_name(service_type: String) -> String:
	match service_type:
		"passenger":
			return "Pax"
		"cargo":
			return "Bag"
		"cleaning":
			return "Clean"
		"catering":
			return "Cater"
		"pushback":
			return "Tow"
		_:
			return "Fuel"


func _size_text(definition: Dictionary) -> String:
	var sizes: PackedStringArray = definition["sizes"]
	var result := ""
	for index in range(sizes.size()):
		if index > 0:
			result += "/"
		result += sizes[index]
	return result


func _on_expand_here_pressed() -> void:
	if (
		expand_here_button == null
		or expand_here_button.disabled
		or active_expand_parcel_id.is_empty()
	):
		return
	placement_expand_requested.emit(
		active_expand_parcel_id
	)


func _on_store_building_pressed() -> void:
	if store_button != null and store_button.visible:
		store_building_requested.emit()


func _on_storage_pressed() -> void:
	if storage_panel == null:
		return
	storage_panel.visible = not storage_panel.visible


func _on_stored_building_pressed(uid: int) -> void:
	if storage_panel != null:
		storage_panel.visible = false
	stored_building_selected.emit(uid)


func _on_airport_edit_pressed() -> void:
	airport_edit_requested.emit()


func _on_undo_airport_edit_pressed() -> void:
	if (
		undo_airport_edit_button != null
		and not undo_airport_edit_button.disabled
	):
		undo_airport_edit_requested.emit()


func _on_done_airport_edit_pressed() -> void:
	done_airport_edit_requested.emit()


func _on_purchase_pressed() -> void:
	purchase_expansion_requested.emit()


func _on_building_button_pressed(building_id: String) -> void:
	if catalog_panel != null:
		catalog_panel.visible = false
	build_hint.text = "PLACING BUILDING  •  Tap owned land • use Rotate / Place / Cancel below"
	building_selected.emit(building_id)

func _on_catalog_close_pressed() -> void:
	if catalog_panel != null:
		catalog_panel.visible = false
	build_hint.text = "AIRPORT VIEW  •  BUILD reopens construction"


func _on_rotate_pressed() -> void:
	rotate_building_requested.emit()


func _on_confirm_building_pressed() -> void:
	confirm_building_requested.emit()


func _on_cancel_building_pressed() -> void:
	cancel_building_requested.emit()


func _synergy_preview_suffix(
	status: Dictionary
) -> String:
	var synergy_value = status.get("synergy", {})
	if not (synergy_value is Dictionary):
		return ""
	var synergy: Dictionary = synergy_value
	if synergy.is_empty():
		return ""

	var text := String(
		synergy.get("preview_text", "")
	)
	if text.is_empty():
		return ""

	var active := bool(
		synergy.get("active", false)
	)
	if active:
		return "  •  ✦ " + text
	return "  •  ◇ " + text


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result


func _on_build_navigation_pressed() -> void:
	if catalog_panel != null:
		catalog_panel.visible = true
	if storage_panel != null:
		storage_panel.visible = false
	if status_detail_panel != null:
		_close_status_detail()
	build_hint.text = "BUILD AIRPORT  •  Choose a building from the drawer"
	set_operation_status("Construction drawer opened • choose a building to place.")

func _on_navigation_pressed(tab: String) -> void:
	navigation_requested.emit(tab)
