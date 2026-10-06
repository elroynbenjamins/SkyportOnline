class_name WorldMapScreen
extends CanvasLayer

signal close_requested
signal flight_assignment_requested(
	aircraft: AircraftPrototype,
	destination_id: String
)

var root: Control
var screen_title_label: Label
var network_meta_label: Label
var home_hub_label: Label
var map_canvas: WorldMapCanvas
var map_hint_label: Label
var aircraft_list_container: VBoxContainer
var country_badge_rect: TextureRect
var country_title_label: Label
var country_status_label: Label
var country_picker: OptionButton
var country_resource_row: HBoxContainer
var destination_list_container: VBoxContainer
var details_title: Label
var route_card_label: Label
var reward_card_label: Label
var resource_card_label: Label
var resource_preview_row: HBoxContainer
var aircraft_fit_label: Label
var details_body: Label
var assignment_status: Label
var assign_button: Button

var aircraft_buttons: Array[Button] = []
var destination_buttons: Dictionary = {}
var aircraft: Array[AircraftPrototype] = []
var selected_aircraft_index := 0
var selected_country_code := ""
var selected_destination_id := ""
var home_country_code := "NL"
var player_level := 1
var mastery_hours_by_type: Dictionary = {}
var passenger_stock := 0
var passenger_capacity := 0
var route_history: Dictionary = {}
var contract_airport_key := ""
var priority_contract_progress: Dictionary = {}
var demand_now_override := -1
var refresh_accumulator := 0.0


func _ready() -> void:
	layer = 30
	_build_ui()
	root.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if root == null or not root.visible:
		return

	refresh_accumulator += delta
	if refresh_accumulator >= 1.0:
		refresh_accumulator = 0.0
		_refresh_aircraft_buttons()
		_refresh_destination_buttons()
		_refresh_details()


func open_map(
	aircraft_nodes: Array[AircraftPrototype],
	current_player_level: int,
	mastery_hours: Dictionary = {},
	current_passengers: int = 0,
	current_passenger_capacity: int = 0,
	history: Dictionary = {},
	airport_key: String = "",
	contract_progress: Dictionary = {},
	current_home_country_code: String = "NL"
) -> void:
	aircraft = aircraft_nodes
	player_level = current_player_level
	mastery_hours_by_type = mastery_hours.duplicate(true)
	passenger_stock = maxi(current_passengers, 0)
	passenger_capacity = maxi(current_passenger_capacity, 0)
	route_history = history.duplicate(true)
	contract_airport_key = airport_key
	priority_contract_progress = contract_progress.duplicate(true)
	home_country_code = current_home_country_code
	if CountryCatalog.get_country(home_country_code).is_empty():
		home_country_code = "NL"
	selected_aircraft_index = clampi(
		selected_aircraft_index,
		0,
		maxi(aircraft.size() - 1, 0)
	)

	if selected_country_code.is_empty():
		if not selected_destination_id.is_empty():
			var selected_destination := DestinationCatalog.get_destination(
				selected_destination_id
			)
			selected_country_code = String(
				selected_destination.get("country_code", "")
			)
		if selected_country_code.is_empty():
			var unlocked := DestinationCatalog.unlocked_for_level(player_level)
			if not unlocked.is_empty():
				selected_destination_id = String(unlocked[0]["id"])
				selected_country_code = String(
					unlocked[0].get("country_code", "")
				)
		if selected_country_code.is_empty():
			selected_country_code = home_country_code

	_refresh_map_state()
	_refresh_aircraft_buttons()
	_refresh_destination_buttons()
	_refresh_details()
	root.visible = true


func close_map() -> void:
	root.visible = false


func set_demand_time_override(now_unix: int) -> void:
	demand_now_override = now_unix
	if root != null and root.visible:
		_refresh_destination_buttons()
		_refresh_details()


func _demand_condition(destination_id: String) -> Dictionary:
	return DynamicDemandRules.condition_for(
		destination_id,
		demand_now_override
	)


func set_passenger_stock(
	current_passengers: int,
	current_capacity: int
) -> void:
	passenger_stock = maxi(current_passengers, 0)
	passenger_capacity = maxi(current_capacity, 0)
	if root != null and root.visible:
		_refresh_details()


func set_route_history(history: Dictionary) -> void:
	route_history = history.duplicate(true)
	if root != null and root.visible:
		_refresh_details()


func set_priority_contract_progress(
	progress: Dictionary
) -> void:
	priority_contract_progress = progress.duplicate(true)
	if root != null and root.visible:
		_refresh_destination_buttons()
		_refresh_details()


func _active_priority_contract() -> Dictionary:
	return RouteContractRules.active_contract(
		player_level,
		contract_airport_key,
		demand_now_override
	)


func set_assignment_status(text: String) -> void:
	assignment_status.text = text
	_refresh_aircraft_buttons()
	_refresh_details()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("07151d", 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	_build_top_bar()
	_build_aircraft_sidebar()
	_build_map_area()
	_build_details_sidebar()


func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_top = 10
	top.offset_right = -10
	top.offset_bottom = 68
	root.add_child(top)
	GameUIStyle.apply_panel(top, "screen_top")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(title_box)

	screen_title_label = Label.new()
	screen_title_label.text = "🌍  ROUTE CONTROL"
	screen_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.heading(screen_title_label, 22)
	title_box.add_child(screen_title_label)

	network_meta_label = Label.new()
	network_meta_label.text = "1  AIRCRAFT   →   2  COUNTRY   →   3  ROUTE   →   4  DISPATCH"
	network_meta_label.add_theme_font_size_override("font_size", 11)
	network_meta_label.add_theme_color_override("font_color", GameUIStyle.COLOR_ACCENT)
	title_box.add_child(network_meta_label)

	home_hub_label = Label.new()
	home_hub_label.text = "★ HOME HUB"
	home_hub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_hub_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(home_hub_label)
	row.add_child(home_hub_label)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(140, 42)
	close_button.pressed.connect(_on_close_pressed)
	GameUIStyle.apply_button(close_button, "secondary", true)
	row.add_child(close_button)


func _build_aircraft_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 10
	panel.offset_top = 80
	panel.offset_right = 270
	panel.offset_bottom = -10
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_section")

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = "1  YOUR AIRCRAFT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 16)
	wrapper.add_child(heading)

	aircraft_list_container = VBoxContainer.new()
	aircraft_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aircraft_list_container.add_theme_constant_override("separation", 6)
	wrapper.add_child(aircraft_list_container)

	assignment_status = Label.new()
	assignment_status.text = "Select an aircraft and destination."
	assignment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assignment_status.custom_minimum_size = Vector2(0, 70)
	assignment_status.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(assignment_status)
	wrapper.add_child(assignment_status)


func _build_map_area() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 282
	panel.offset_top = 80
	panel.offset_right = -382
	panel.offset_bottom = -10
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "context_preview")

	map_canvas = WorldMapCanvas.new()
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.clip_contents = true
	map_canvas.set_countries(CountryCatalog.get_countries())
	map_canvas.country_selected.connect(_on_country_selected)
	map_canvas.country_hovered.connect(_on_country_hovered)
	panel.add_child(map_canvas)

	var hint_panel := PanelContainer.new()
	hint_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_panel.offset_left = 12
	hint_panel.offset_top = 10
	hint_panel.offset_right = -12
	hint_panel.offset_bottom = 48
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(hint_panel)
	GameUIStyle.apply_panel(hint_panel, "dark")

	map_hint_label = Label.new()
	map_hint_label.text = "Tap a country marker to inspect routes and resources."
	map_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_hint_label.add_theme_font_size_override("font_size", 12)
	map_hint_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_MUTED
	)
	hint_panel.add_child(map_hint_label)


func _build_details_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -370
	panel.offset_top = 80
	panel.offset_right = -10
	panel.offset_bottom = -10
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_focus")

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 7)
	panel.add_child(shell)

	var heading := Label.new()
	heading.text = "2  COUNTRY & ROUTE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 16)
	shell.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)

	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 7)
	scroll.add_child(wrapper)

	var country_header := HBoxContainer.new()
	country_header.add_theme_constant_override("separation", 10)
	wrapper.add_child(country_header)

	country_badge_rect = TextureRect.new()
	country_badge_rect.custom_minimum_size = Vector2(64, 48)
	country_badge_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	country_badge_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	country_badge_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	country_header.add_child(country_badge_rect)

	var country_header_text := VBoxContainer.new()
	country_header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_header_text.alignment = BoxContainer.ALIGNMENT_CENTER
	country_header_text.add_theme_constant_override("separation", 1)
	country_header.add_child(country_header_text)

	country_title_label = Label.new()
	country_title_label.text = "Select a country"
	GameUIStyle.heading(country_title_label, 20)
	country_title_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	country_header_text.add_child(country_title_label)

	country_status_label = Label.new()
	country_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	country_status_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(country_status_label)
	country_header_text.add_child(country_status_label)

	country_picker = OptionButton.new()
	country_picker.custom_minimum_size = Vector2(0, 38)
	GameUIStyle.apply_button(country_picker, "secondary", true)
	for country in CountryCatalog.get_countries():
		var code := String(country.get("id", ""))
		var routes := _destinations_for_country(code)
		var route_badge := (
			" • %d route%s" % [
				routes.size(),
				"" if routes.size() == 1 else "s"
			]
			if not routes.is_empty()
			else " • resources"
		)
		country_picker.add_icon_item(
			CountryVisualCatalog.texture_for_country(code),
			"%s  %s%s" % [
				code,
				String(country.get("name", "Country")),
				route_badge
			]
		)
		var item_index := country_picker.item_count - 1
		country_picker.set_item_metadata(item_index, code)
	country_picker.item_selected.connect(_on_country_picker_selected)
	wrapper.add_child(country_picker)

	country_resource_row = HBoxContainer.new()
	country_resource_row.alignment = BoxContainer.ALIGNMENT_CENTER
	country_resource_row.add_theme_constant_override("separation", 6)
	wrapper.add_child(country_resource_row)

	destination_list_container = VBoxContainer.new()
	destination_list_container.add_theme_constant_override("separation", 4)
	wrapper.add_child(destination_list_container)

	for destination in DestinationCatalog.all():
		var destination_id := String(destination.get("id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(
			_on_destination_pressed.bind(destination_id)
		)
		GameUIStyle.apply_button(button, "screen_tab", true)
		destination_list_container.add_child(button)
		destination_buttons[destination_id] = button

	var route_heading := Label.new()
	route_heading.text = "3  ROUTE BRIEFING"
	route_heading.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(route_heading)
	wrapper.add_child(route_heading)

	details_title = Label.new()
	details_title.text = "Select a route"
	GameUIStyle.heading(details_title, 19)
	wrapper.add_child(details_title)

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 6)
	info_grid.add_theme_constant_override("v_separation", 6)
	wrapper.add_child(info_grid)

	route_card_label = _make_detail_card(
		info_grid,
		"ROUTE",
		GameUIStyle.COLOR_ACCENT
	)
	reward_card_label = _make_detail_card(
		info_grid,
		"REWARD",
		GameUIStyle.COLOR_GOLD
	)
	resource_card_label = _make_detail_card(
		info_grid,
		"RESOURCES",
		GameUIStyle.COLOR_SUCCESS
	)
	aircraft_fit_label = _make_detail_card(
		info_grid,
		"AIRCRAFT FIT",
		Color("d8b9ff")
	)

	resource_preview_row = HBoxContainer.new()
	resource_preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_preview_row.custom_minimum_size = Vector2(0, 42)
	resource_preview_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(resource_preview_row)

	var secondary_heading := Label.new()
	secondary_heading.text = "ROUTE STATUS"
	secondary_heading.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(secondary_heading)
	wrapper.add_child(secondary_heading)

	details_body = Label.new()
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_body.custom_minimum_size = Vector2(0, 86)
	details_body.add_theme_font_size_override("font_size", 13)
	details_body.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_TEXT
	)
	wrapper.add_child(details_body)

	assign_button = Button.new()
	assign_button.text = "4  DISPATCH FLIGHT"
	assign_button.custom_minimum_size = Vector2(0, 54)
	assign_button.add_theme_font_size_override("font_size", 16)
	assign_button.pressed.connect(_on_assign_pressed)
	GameUIStyle.apply_button(assign_button, "primary")
	shell.add_child(assign_button)


func _make_detail_card(
	parent: GridContainer,
	title: String,
	accent: Color
) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 76)
	GameUIStyle.apply_panel(card, "reward_tile")
	parent.add_child(card)

	var label := Label.new()
	label.text = title + "\n—"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", accent)
	card.add_child(label)
	return label


func _place_map_control(
	control: Control,
	normalized_position: Vector2,
	control_size: Vector2
) -> void:
	control.anchor_left = normalized_position.x
	control.anchor_right = normalized_position.x
	control.anchor_top = normalized_position.y
	control.anchor_bottom = normalized_position.y
	control.offset_left = -control_size.x * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_bottom = control_size.y * 0.5


func _refresh_aircraft_buttons() -> void:
	if aircraft_list_container == null:
		return

	while aircraft_buttons.size() < aircraft.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 68)
		GameUIStyle.apply_button(button, "build_card", true)
		var index := aircraft_buttons.size()
		button.pressed.connect(_on_aircraft_pressed.bind(index))
		aircraft_list_container.add_child(button)
		aircraft_buttons.append(button)

	for index in range(aircraft_buttons.size()):
		var button := aircraft_buttons[index]
		button.visible = index < aircraft.size()
		if not button.visible:
			continue

		var plane := aircraft[index]
		var plan := plane.get_flight_plan()
		var destination_text := "No route"
		if not plan.is_empty():
			destination_text = String(plan.get("city", "Assigned"))

		var mastery_hours := maxf(
			float(
				mastery_hours_by_type.get(
					plane.aircraft_type_id,
					0.0
				)
			),
			0.0
		)
		var mastery_stars := AircraftMastery.stars_for_hours(
			mastery_hours
		)
		var state_text := plane.state.replace("_", " ").capitalize()
		if plane.state == "EN_ROUTE":
			state_text = "En Route • %s" % FlightRules.format_duration(
				plane.get_flight_remaining_seconds()
			)

		button.text = "%s  •  %s  %s\n%s → %s" % [
			plane.name,
			plane.aircraft_display_name,
			AircraftMastery.format_stars(mastery_stars),
			state_text,
			destination_text
		]
		GameUIStyle.apply_button(
			button,
			"build_card_selected" if index == selected_aircraft_index else "build_card",
			true
		)
		button.disabled = index == selected_aircraft_index


func _refresh_destination_buttons() -> void:
	var active_contract := _active_priority_contract()
	var contract_destination_id := String(
		active_contract.get("destination_id", "")
	)
	var contract_state := RouteContractRules.progress_for(
		active_contract,
		priority_contract_progress
	)

	for destination in DestinationCatalog.all():
		var destination_id := String(destination.get("id", ""))
		if not destination_buttons.has(destination_id):
			continue

		var button: Button = destination_buttons[destination_id]
		var country_code := String(destination.get("country_code", ""))
		button.visible = country_code == selected_country_code
		if not button.visible:
			continue

		var required_level := int(destination.get("unlock_level", 1))
		button.disabled = player_level < required_level

		if button.disabled:
			GameUIStyle.apply_button(button, "build_card_locked", true)
			button.text = "🔒  %s  •  LV %d" % [
				String(destination.get("city", "Route")).to_upper(),
				required_level
			]
			continue

		var condition := _demand_condition(destination_id)
		var contract_suffix := ""
		if destination_id == contract_destination_id:
			if bool(contract_state.get("completed", false)):
				contract_suffix = "  •  ✓ CONTRACT"
			else:
				contract_suffix = "  •  ★ CONTRACT"

		var button_kind := "screen_tab"
		if destination_id == selected_destination_id:
			button_kind = "screen_tab_selected"
		elif destination_id == contract_destination_id:
			button_kind = "gold"
		elif String(condition.get("id", "normal")) in [
			"surge",
			"seasonal",
			"contract"
		]:
			button_kind = "event"

		GameUIStyle.apply_button(button, button_kind, true)
		button.text = "%s  •  %s%s" % [
			String(destination.get("city", "Route")).to_upper(),
			String(condition.get("short_label", "NORMAL")),
			contract_suffix
		]

	_refresh_country_summary()


func _refresh_details() -> void:
	if aircraft.is_empty():
		details_title.text = "NO AIRCRAFT"
		_clear_detail_cards()
		details_body.text = "No aircraft are available."
		assign_button.disabled = true
		return

	if selected_aircraft_index >= aircraft.size():
		selected_aircraft_index = 0

	var plane := aircraft[selected_aircraft_index]
	var destination := DestinationCatalog.get_destination(
		selected_destination_id
	)
	if destination.is_empty():
		var selected_country := CountryCatalog.get_country(
			selected_country_code
		)
		var country_resources := CountryResourceCatalog.resources_for_country(
			selected_country_code
		)
		details_title.text = "NO ACTIVE ROUTE"
		_clear_detail_cards()
		resource_card_label.text = "RESOURCES\n%s\n40%% base" % (
			_resource_names(country_resources)
		)
		_refresh_resource_preview(country_resources)
		if selected_country.is_empty():
			details_body.text = "Select a country on the world map."
			assign_button.text = "SELECT COUNTRY"
		else:
			details_body.text = (
				"%s currently has no dispatch destination in this "
				+ "route set. Its resources are already part of the "
				+ "country economy and can be used as the network expands."
			) % String(selected_country.get("name", selected_country_code))
			assign_button.text = "NO ROUTE YET"
		assign_button.disabled = true
		if map_canvas != null:
			map_canvas.set_selected_country(selected_country_code)
		return

	var profile := plane.get_aircraft_profile()
	var mastery_hours := maxf(
		float(
			mastery_hours_by_type.get(
				plane.aircraft_type_id,
				0.0
			)
		),
		0.0
	)
	var mastery_status := AircraftMastery.status(mastery_hours)
	var mastery_stars := int(mastery_status.get("stars", 0))
	var mastery_bonuses: Dictionary = mastery_status.get(
		"bonuses",
		{}
	).duplicate(true)
	var base_passengers := maxi(
		int(profile.get("passengers", 0)),
		0
	)
	var condition := _demand_condition(
		String(destination.get("id", ""))
	)
	var demand_preview := PassengerDemandRules.preview(
		profile,
		destination,
		mastery_hours,
		float(condition.get("demand_modifier", 1.0))
	)
	var route_passengers := int(
		demand_preview.get("route_requirement", base_passengers)
	)
	var required_passengers := int(
		demand_preview.get("mastery_requirement", route_passengers)
	)
	var load_factor := float(
		demand_preview.get("adjusted_load_factor", 1.0)
	)
	var demand_label := String(
		demand_preview.get("demand_label", "Standard")
	)
	var required_level := int(destination.get("unlock_level", 1))
	var level_ok := player_level >= required_level
	var range_ok := FlightRules.can_fly(profile, destination)
	var can_change := plane.can_change_flight_plan()
	var duration_seconds := FlightRules.duration_seconds(profile, destination)
	var preview_plan := DynamicDemandRules.apply_to_flight_plan(
		FlightRules.create_flight_plan(profile, destination),
		condition
	)
	var preview_coins := AircraftMastery.apply_coin_bonus(
		int(preview_plan.get("coin_reward", 0)),
		mastery_hours
	)
	var preview_xp := AircraftMastery.apply_xp_bonus(
		int(preview_plan.get("xp_reward", 0)),
		mastery_hours
	)
	var resource_chance := ResourceDropRules.chance_for_flight(
		profile,
		preview_plan
	)
	var country_resources := CountryResourceCatalog.resources_for_country(
		String(destination.get("country_code", ""))
	)

	selected_country_code = String(
		destination.get("country_code", selected_country_code)
	)
	_refresh_country_summary()
	details_title.text = "%s, %s" % [
		String(destination["city"]).to_upper(),
		String(destination["country"])
	]

	var current_plan := plane.get_flight_plan()
	var current_route := "None"
	if not current_plan.is_empty():
		current_route = "%s, %s" % [
			String(current_plan.get("city", "")),
			String(current_plan.get("country", ""))
		]

	var active_contract := _active_priority_contract()
	var contract_state := RouteContractRules.progress_for(
		active_contract,
		priority_contract_progress
	)
	var contract_text := "No Priority Contract on this route."
	if (
		not active_contract.is_empty()
		and String(active_contract.get("destination_id", ""))
			== String(destination.get("id", ""))
	):
		var progress := int(contract_state.get("progress", 0))
		var target := int(
			contract_state.get(
				"target",
				active_contract.get("target_flights", 3)
			)
		)
		if bool(contract_state.get("completed", false)):
			contract_text = (
				"✓ COMPLETED • %d/%d returns"
				% [progress, target]
			)
		else:
			contract_text = (
				"%d/%d successful returns • %s left\n"
				+ "Bonus: 🪙 %d • XP %d • %s"
			) % [
				progress,
				target,
				DynamicDemandRules.format_remaining(
					int(active_contract.get("remaining_seconds", 0))
				),
				int(active_contract.get("bonus_coins", 0)),
				int(active_contract.get("bonus_xp", 0)),
				RouteContractRules.format_resource_bundle(
					active_contract.get("bonus_resources", []) as Array
				)
			]

	var history_entry: Dictionary = route_history.get(
		String(destination.get("id", "")),
		{}
	)
	var history_text := "No completed flights yet"
	var history_flights := int(
		history_entry.get("flights_completed", 0)
	)
	if history_flights > 0:
		var total_boarded := int(
			history_entry.get("passengers_boarded", 0)
		)
		var avg_boarded := float(total_boarded) / float(history_flights)
		history_text = (
			"%d flights • %.1f avg pax • 🪙 %d • %d resources"
			% [
				history_flights,
				avg_boarded,
				int(history_entry.get("coins_earned", 0)),
				int(history_entry.get("resources_earned", 0))
			]
		)

	route_card_label.text = (
		"ROUTE\n"
		+ "%d km • %s\n"
		+ "%s • %.0f%% load\n"
		+ "%d → %d pax"
	) % [
		int(destination.get("distance_km", 0)),
		FlightRules.format_duration(duration_seconds),
		demand_label,
		load_factor * 100.0,
		route_passengers,
		required_passengers
	]

	reward_card_label.text = (
		"REWARD\n"
		+ "🪙 %d • XP %d\n"
		+ "%s\n"
		+ "Stock %d/%d"
	) % [
		preview_coins,
		preview_xp,
		String(condition.get("label", "Normal")),
		passenger_stock,
		passenger_capacity
	]

	resource_card_label.text = (
		"RESOURCES\n"
		+ "%s\n"
		+ "%.1f%% each"
	) % [
		_resource_names(country_resources),
		resource_chance * 100.0
	]
	_refresh_resource_preview(country_resources)

	aircraft_fit_label.text = (
		"AIRCRAFT FIT\n"
		+ "%s • %s\n"
		+ "%d seats • %d km\n"
		+ "%s"
	) % [
		plane.aircraft_display_name,
		String(profile.get("size", "?")),
		base_passengers,
		int(profile.get("range_km", 0)),
		AircraftMastery.format_stars(mastery_stars)
	]

	details_body.text = (
		"Condition: %s • %s left\n"
		+ "PRIORITY CONTRACT: %s\n"
		+ "Route History: %s\n"
		+ "Current route: %s\n"
		+ "Aircraft: %s"
	) % [
		String(condition.get("label", "Normal")),
		DynamicDemandRules.format_remaining(
			int(condition.get("remaining_seconds", 0))
		),
		contract_text.replace("\n", " • "),
		history_text,
		current_route,
		plane.state.replace("_", " ").capitalize()
	]

	assign_button.disabled = not (level_ok and range_ok and can_change)
	if not level_ok:
		assign_button.text = "UNLOCKS AT LV %d" % required_level
	elif not range_ok:
		assign_button.text = "OUT OF RANGE"
	elif not can_change:
		assign_button.text = "AIRCRAFT BUSY"
	elif passenger_stock < required_passengers:
		assign_button.text = "ASSIGN • WAIT FOR %d PAX • %s" % [
			required_passengers,
			FlightRules.format_duration(duration_seconds)
		]
	else:
		assign_button.text = "ASSIGN • %d PAX • %s" % [
			required_passengers,
			FlightRules.format_duration(duration_seconds)
		]

	if map_canvas != null:
		map_canvas.set_selected_country(selected_country_code)


func _refresh_resource_preview(
	resources: Array[Dictionary]
) -> void:
	if resource_preview_row == null:
		return

	for child in resource_preview_row.get_children():
		child.free()

	resource_preview_row.visible = not resources.is_empty()
	for resource in resources:
		var resource_id := String(resource.get("id", ""))
		var resource_name := String(resource.get("name", "Resource"))

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ResourceVisualCatalog.texture_for_resource(
			resource_id
		)
		icon.tooltip_text = resource_name
		resource_preview_row.add_child(icon)


func _clear_detail_cards() -> void:
	if route_card_label != null:
		route_card_label.text = "ROUTE\n—"
	if reward_card_label != null:
		reward_card_label.text = "REWARD\n—"
	if resource_card_label != null:
		resource_card_label.text = "RESOURCES\n—"
	if resource_preview_row != null:
		for child in resource_preview_row.get_children():
			child.queue_free()
	if aircraft_fit_label != null:
		aircraft_fit_label.text = "AIRCRAFT FIT\n—"


func _next_mastery_text(status: Dictionary) -> String:
	var stars := int(status.get("stars", 0))
	if stars >= 5:
		return "Mastery complete • 5 Stars"

	return "Next Star: %.1f / %.0f flight hours" % [
		float(status.get("hours", 0.0)),
		float(status.get("next_hours", 0.0))
	]


func _resource_names(resources: Array[Dictionary]) -> String:
	if resources.is_empty():
		return "No regional resources configured."

	var names: Array[String] = []
	for resource in resources:
		names.append(String(resource.get("name", "Resource")))
	return " • ".join(names)


func _on_aircraft_pressed(index: int) -> void:
	if index < 0 or index >= aircraft.size():
		return
	selected_aircraft_index = index
	_refresh_aircraft_buttons()
	_refresh_details()


func _on_country_selected(country_code: String) -> void:
	_select_country(country_code)


func _on_country_picker_selected(index: int) -> void:
	if country_picker == null:
		return
	_select_country(
		String(country_picker.get_item_metadata(index))
	)


func _on_country_hovered(country_code: String) -> void:
	if map_hint_label == null:
		return
	if country_code.is_empty():
		map_hint_label.text = (
			"Tap a country marker to inspect routes and resources."
		)
		return

	var country := CountryCatalog.get_country(country_code)
	if country.is_empty():
		return
	var routes := _destinations_for_country(country_code)
	var route_text := (
		"%d route%s" % [
			routes.size(),
			"" if routes.size() == 1 else "s"
		]
		if not routes.is_empty()
		else "future destination"
	)
	map_hint_label.text = "%s  •  %s  •  %s" % [
		String(country.get("name", country_code)),
		String(country.get("region", "")),
		route_text
	]


func _select_country(country_code: String) -> void:
	var country := CountryCatalog.get_country(country_code)
	if country.is_empty():
		return

	selected_country_code = country_code
	var routes := _destinations_for_country(country_code)
	var keep_current := false
	if not selected_destination_id.is_empty():
		var current_destination := DestinationCatalog.get_destination(
			selected_destination_id
		)
		keep_current = (
			String(current_destination.get("country_code", ""))
			== country_code
		)

	if not keep_current:
		selected_destination_id = ""
		var first_route := ""
		for destination in routes:
			var destination_id := String(destination.get("id", ""))
			if first_route.is_empty():
				first_route = destination_id
			if player_level >= int(destination.get("unlock_level", 1)):
				selected_destination_id = destination_id
				break
		if selected_destination_id.is_empty():
			selected_destination_id = first_route

	_refresh_map_state()
	_refresh_destination_buttons()
	_refresh_details()


func _refresh_map_state() -> void:
	if map_canvas == null:
		return

	var route_codes: Array[String] = []
	var unlocked_codes: Array[String] = []
	for destination in DestinationCatalog.all():
		var country_code := String(destination.get("country_code", ""))
		if not route_codes.has(country_code):
			route_codes.append(country_code)
		if (
			player_level >= int(destination.get("unlock_level", 1))
			and not unlocked_codes.has(country_code)
		):
			unlocked_codes.append(country_code)

	map_canvas.set_countries(CountryCatalog.get_countries())
	map_canvas.set_home_country(home_country_code)
	map_canvas.set_route_countries(route_codes, unlocked_codes)
	map_canvas.set_selected_country(selected_country_code)

	if home_hub_label != null:
		var home_country := CountryCatalog.get_country(home_country_code)
		home_hub_label.text = "★ HOME  •  %s" % String(
			home_country.get("name", home_country_code)
		).to_upper()

	_refresh_country_summary()


func _refresh_country_summary() -> void:
	if country_title_label == null or country_status_label == null:
		return

	var country := CountryCatalog.get_country(selected_country_code)
	if country.is_empty():
		country_title_label.text = "SELECT A COUNTRY"
		country_status_label.text = (
			"Tap any country marker to inspect its resources and routes."
		)
		if country_badge_rect != null:
			country_badge_rect.texture = null
			country_badge_rect.tooltip_text = ""
		_refresh_country_resource_row([])
		return

	var routes := _destinations_for_country(selected_country_code)
	var unlocked_count := 0
	for destination in routes:
		if player_level >= int(destination.get("unlock_level", 1)):
			unlocked_count += 1

	country_title_label.text = "%s  •  %s" % [
		String(country.get("id", "")),
		String(country.get("name", "Country"))
	]
	if country_badge_rect != null:
		country_badge_rect.texture = CountryVisualCatalog.texture_for_country(
			selected_country_code
		)
		country_badge_rect.tooltip_text = "%s • %s" % [
			String(country.get("name", "Country")),
			String(country.get("region", ""))
		]
	_refresh_country_resource_row(country.get("resources", []) as Array)
	if country_picker != null:
		for index in range(country_picker.item_count):
			if (
				String(country_picker.get_item_metadata(index))
				== selected_country_code
			):
				country_picker.select(index)
				break
	var home_suffix := (
		"  •  HOME HUB"
		if selected_country_code == home_country_code
		else ""
	)
	if routes.is_empty():
		country_status_label.text = "%s  •  No active route yet%s" % [
			String(country.get("region", "")),
			home_suffix
		]
	else:
		country_status_label.text = (
			"%s  •  %d route%s  •  %d unlocked%s"
		) % [
			String(country.get("region", "")),
			routes.size(),
			"" if routes.size() == 1 else "s",
			unlocked_count,
			home_suffix
		]


func _refresh_country_resource_row(resources: Array) -> void:
	if country_resource_row == null:
		return

	for child in country_resource_row.get_children():
		child.free()

	country_resource_row.visible = not resources.is_empty()
	for resource in resources:
		var resource_id := String(resource.get("id", ""))
		var resource_name := String(resource.get("name", "Resource"))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 76)
		GameUIStyle.apply_panel(card, "reward_tile")
		country_resource_row.add_child(card)

		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 1)
		card.add_child(content)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ResourceVisualCatalog.texture_for_resource(resource_id)
		icon.tooltip_text = resource_name
		content.add_child(icon)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_TEXT
		)
		label.text = resource_name
		content.add_child(label)


func _destinations_for_country(
	country_code: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination in DestinationCatalog.all():
		if String(destination.get("country_code", "")) == country_code:
			result.append(destination.duplicate(true))
	return result


func _on_destination_pressed(destination_id: String) -> void:
	var destination := DestinationCatalog.get_destination(destination_id)
	if destination.is_empty():
		return
	selected_destination_id = destination_id
	selected_country_code = String(
		destination.get("country_code", selected_country_code)
	)
	_refresh_map_state()
	_refresh_destination_buttons()
	_refresh_details()


func _on_assign_pressed() -> void:
	if aircraft.is_empty():
		return
	if selected_aircraft_index >= aircraft.size():
		return
	if selected_destination_id.is_empty():
		return

	var plane := aircraft[selected_aircraft_index]
	flight_assignment_requested.emit(
		plane,
		selected_destination_id
	)


func _on_close_pressed() -> void:
	close_map()
	close_requested.emit()
