class_name WorldMapScreen
extends CanvasLayer

signal close_requested
signal flight_assignment_requested(
	aircraft: AircraftPrototype,
	destination_id: String
)

var root: Control
var map_canvas: WorldMapCanvas
var aircraft_list_container: VBoxContainer
var details_title: Label
var details_body: Label
var assignment_status: Label
var assign_button: Button

var aircraft_buttons: Array[Button] = []
var destination_buttons: Dictionary = {}
var aircraft: Array[AircraftPrototype] = []
var selected_aircraft_index := 0
var selected_destination_id := ""
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
	contract_progress: Dictionary = {}
) -> void:
	aircraft = aircraft_nodes
	player_level = current_player_level
	mastery_hours_by_type = mastery_hours.duplicate(true)
	passenger_stock = maxi(current_passengers, 0)
	passenger_capacity = maxi(current_passenger_capacity, 0)
	route_history = history.duplicate(true)
	contract_airport_key = airport_key
	priority_contract_progress = contract_progress.duplicate(true)
	selected_aircraft_index = clampi(
		selected_aircraft_index,
		0,
		maxi(aircraft.size() - 1, 0)
	)

	if selected_destination_id.is_empty():
		var unlocked := DestinationCatalog.unlocked_for_level(player_level)
		if not unlocked.is_empty():
			selected_destination_id = String(unlocked[0]["id"])

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
	backdrop.color = Color("0a1d27", 0.98)
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)

	var title := Label.new()
	title.text = "🌍  WORLD MAP  •  EUROPE NETWORK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	row.add_child(title)

	var origin := Label.new()
	origin.text = "DEV HOME: %s" % DestinationCatalog.DEVELOPMENT_HOME_NAME
	origin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	origin.add_theme_font_size_override("font_size", 14)
	row.add_child(origin)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(140, 42)
	close_button.pressed.connect(_on_close_pressed)
	row.add_child(close_button)


func _build_aircraft_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 10
	panel.offset_top = 80
	panel.offset_right = 270
	panel.offset_bottom = -10
	root.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = "SELECT AIRCRAFT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
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
	wrapper.add_child(assignment_status)


func _build_map_area() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 282
	panel.offset_top = 80
	panel.offset_right = -350
	panel.offset_bottom = -10
	root.add_child(panel)

	map_canvas = WorldMapCanvas.new()
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.clip_contents = true
	panel.add_child(map_canvas)

	var home := Label.new()
	home.text = "★ %s" % DestinationCatalog.DEVELOPMENT_HOME_NAME
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_theme_font_size_override("font_size", 14)
	_place_map_control(home, WorldMapCanvas.HOME_POSITION, Vector2(150, 34))
	map_canvas.add_child(home)

	for destination in DestinationCatalog.all():
		var button := Button.new()
		var destination_id := String(destination["id"])
		button.text = "%s\n%s" % [
			String(destination["city"]).to_upper(),
			String(destination["country_code"])
		]
		button.custom_minimum_size = Vector2(118, 46)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(
			_on_destination_pressed.bind(destination_id)
		)

		var normalized_position: Vector2 = destination["map_position"]
		_place_map_control(
			button,
			normalized_position,
			Vector2(118, 46)
		)
		map_canvas.add_child(button)
		destination_buttons[destination_id] = button


func _build_details_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -338
	panel.offset_top = 80
	panel.offset_right = -10
	panel.offset_bottom = -10
	root.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 10)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = "FLIGHT DETAILS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	wrapper.add_child(heading)

	details_title = Label.new()
	details_title.text = "Select a destination"
	details_title.add_theme_font_size_override("font_size", 22)
	wrapper.add_child(details_title)

	details_body = Label.new()
	details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_body.add_theme_font_size_override("font_size", 15)
	wrapper.add_child(details_body)

	assign_button = Button.new()
	assign_button.text = "ASSIGN FLIGHT"
	assign_button.custom_minimum_size = Vector2(0, 58)
	assign_button.add_theme_font_size_override("font_size", 16)
	assign_button.pressed.connect(_on_assign_pressed)
	wrapper.add_child(assign_button)


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
		button.add_theme_font_size_override("font_size", 13)
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
		var destination_id := String(destination["id"])
		if not destination_buttons.has(destination_id):
			continue

		var button: Button = destination_buttons[destination_id]
		var required_level := int(destination.get("unlock_level", 1))
		button.disabled = player_level < required_level

		if button.disabled:
			button.text = "%s\n🔒 LV %d" % [
				String(destination["city"]).to_upper(),
				required_level
			]
			continue

		var condition := _demand_condition(destination_id)
		var contract_suffix := ""
		if destination_id == contract_destination_id:
			if bool(contract_state.get("completed", false)):
				contract_suffix = " • ✓ CONTRACT"
			else:
				contract_suffix = " • ★ CONTRACT"

		button.text = "%s\n%s • %s%s" % [
			String(destination["city"]).to_upper(),
			String(destination["country_code"]),
			String(condition.get("short_label", "NORMAL")),
			contract_suffix
		]


func _refresh_details() -> void:
	if aircraft.is_empty():
		details_title.text = "NO AIRCRAFT"
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
		details_title.text = "SELECT DESTINATION"
		details_body.text = "Choose a destination on the map."
		assign_button.disabled = true
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

	details_body.text = (
		"AIRCRAFT\n"
		+ "%s • %s class\n"
		% [
			plane.aircraft_display_name,
			String(profile.get("size", "?"))
		]
		+ "Cruise: %d km/h\n"
		% int(profile.get("cruise_speed_kph", 0))
		+ "Range: %d km\n"
		% int(profile.get("range_km", 0))
		+ "Mastery: %s • %.1f h flown\n"
		% [
			AircraftMastery.format_stars(mastery_stars),
			mastery_hours
		]
		+ "Passenger demand: %s • %.0f%% load\n"
		% [demand_label, load_factor * 100.0]
		+ "Seats %d → route %d → Mastery %d\n"
		% [base_passengers, route_passengers, required_passengers]
		+ "Airport stock: %d / %d\n"
		% [passenger_stock, passenger_capacity]
		+ "Condition: %s • %s left\n"
		% [
			String(condition.get("label", "Normal")),
			DynamicDemandRules.format_remaining(
				int(condition.get("remaining_seconds", 0))
			)
		]
		+ "Demand modifier: %+.0f%% • Coins %+.0f%% • XP %+.0f%%\n"
		% [
			(float(condition.get("demand_modifier", 1.0)) - 1.0) * 100.0,
			(float(condition.get("coin_multiplier", 1.0)) - 1.0) * 100.0,
			(float(condition.get("xp_multiplier", 1.0)) - 1.0) * 100.0
		]
		+ "Mastery: XP +%.0f%% • Coins +%.0f%%\n"
		% [
			float(mastery_bonuses.get("xp_bonus", 0.0)) * 100.0,
			float(mastery_bonuses.get("coin_bonus", 0.0)) * 100.0
		]
		+ _next_mastery_text(mastery_status)
		+ "\nGround: ~%.0fs return + taxi\n"
		% TurnaroundRules.estimated_turnaround_seconds(profile)
		+ "Fuel %.0fs • Pax %.0f/%.0fs\n"
		% [
			float(profile.get("fuel_seconds", 0.0)),
			float(profile.get("deboard_seconds", 0.0)),
			float(profile.get("board_seconds", 0.0))
		]
		+ "Cargo %.0f/%.0fs • Clean %.0fs • Push %.0fs\n\n"
		% [
			float(profile.get("cargo_unload_seconds", 0.0)),
			float(profile.get("cargo_load_seconds", 0.0)),
			float(profile.get("clean_seconds", 0.0)),
			float(profile.get("pushback_seconds", 0.0))
		]
		+ "DESTINATION\n"
		+ "Distance: %d km\n"
		% int(destination.get("distance_km", 0))
		+ "Flight timer: %s\n"
		% FlightRules.format_duration(duration_seconds)
		+ "Reward: 🪙 %d  •  XP %d\n\n"
		% [
			preview_coins,
			preview_xp
		]
		+ "REGIONAL RESOURCES\n"
		+ "%s\n"
		% _resource_names(country_resources)
		+ "Chance: %.1f%% each • rolled independently\n\n"
		% (resource_chance * 100.0)
		+ "PRIORITY CONTRACT\n"
		+ "%s\n\n"
		% contract_text
		+ "ROUTE HISTORY\n"
		+ "%s\n\n"
		% history_text
		+ "Current route: %s\n"
		% current_route
		+ "Aircraft state: %s"
		% plane.state.replace("_", " ").capitalize()
	)

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

	var map_position: Vector2 = destination["map_position"]
	map_canvas.set_selected_position(map_position)


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


func _on_destination_pressed(destination_id: String) -> void:
	selected_destination_id = destination_id
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
