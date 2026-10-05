class_name AircraftContextCard
extends CanvasLayer

signal choose_route_requested(aircraft: AircraftPrototype)
signal fleet_requested(aircraft: AircraftPrototype)
signal social_requested(aircraft: AircraftPrototype)

var root: Control
var panel: PanelContainer
var aircraft_image: TextureRect
var title_label: Label
var state_label: Label
var route_label: Label
var service_label: Label
var passenger_label: Label
var mastery_label: Label
var primary_button: Button
var fleet_button: Button

var selected_aircraft: AircraftPrototype
var mastery_hours_by_type: Dictionary = {}
var passenger_stock := 0
var passenger_capacity := 0
var refresh_accumulator := 0.0


func _ready() -> void:
	layer = 24
	_build_ui()
	root.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if root == null or not root.visible:
		return

	if (
		selected_aircraft == null
		or not is_instance_valid(selected_aircraft)
		or not selected_aircraft.visible
	):
		close_card()
		return

	refresh_accumulator += delta
	if refresh_accumulator >= 0.25:
		refresh_accumulator = 0.0
		refresh_card()


func show_aircraft(
	aircraft: AircraftPrototype,
	mastery_hours: Dictionary,
	current_passengers: int,
	current_capacity: int
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	selected_aircraft = aircraft
	mastery_hours_by_type = mastery_hours.duplicate(true)
	passenger_stock = maxi(current_passengers, 0)
	passenger_capacity = maxi(current_capacity, 0)
	refresh_card()
	root.visible = true


func close_card() -> void:
	if root != null:
		root.visible = false
	selected_aircraft = null


func is_open() -> bool:
	return (
		root != null
		and root.visible
		and selected_aircraft != null
		and is_instance_valid(selected_aircraft)
	)


func set_passenger_stock(
	current_passengers: int,
	current_capacity: int
) -> void:
	passenger_stock = maxi(current_passengers, 0)
	passenger_capacity = maxi(current_capacity, 0)
	if is_open():
		refresh_card()


func set_mastery_hours(mastery_hours: Dictionary) -> void:
	mastery_hours_by_type = mastery_hours.duplicate(true)
	if is_open():
		refresh_card()


func refresh_card() -> void:
	if (
		selected_aircraft == null
		or not is_instance_valid(selected_aircraft)
	):
		return

	var aircraft := selected_aircraft
	var profile := aircraft.get_aircraft_profile()
	var plan := aircraft.get_flight_plan()
	var mastery_hours := maxf(
		float(
			mastery_hours_by_type.get(
				aircraft.aircraft_type_id,
				0.0
			)
		),
		0.0
	)
	var stars := AircraftMastery.stars_for_hours(
		mastery_hours
	)
	var required_passengers := PassengerDemandRules.required_from_plan(
		profile,
		plan,
		mastery_hours
	)

	title_label.text = "%s  •  %s" % [
		String(aircraft.name),
		aircraft.aircraft_display_name
	]
	aircraft_image.texture = _aircraft_texture(
		aircraft.aircraft_type_id
	)

	var readable_state := aircraft.state.replace(
		"_",
		" "
	).capitalize()
	state_label.text = readable_state
	_apply_state_color(aircraft.state)

	route_label.text = _route_text(aircraft, plan)
	service_label.text = _service_text(aircraft)

	passenger_label.text = "👥 %d needed  •  Airport %d/%d" % [
		required_passengers,
		passenger_stock,
		passenger_capacity
	]
	if passenger_stock < required_passengers:
		passenger_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_WARNING
		)
	else:
		passenger_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_SUCCESS
		)

	mastery_label.text = "%s  •  %.1f h" % [
		AircraftMastery.format_stars(stars),
		mastery_hours
	]

	if aircraft.is_social_visitor():
		var social := aircraft.get_social_visit_data()
		var relationship := String(
			social.get("relationship", "friend")
		).capitalize()
		var country_id := String(
			social.get("country_id", "")
		)
		var country := CountryCatalog.get_country(country_id)
		route_label.text = "Visiting from %s • %s" % [
			String(
				social.get(
					"airport_name",
					"Friend Airport"
				)
			),
			String(country.get("name", country_id))
		]
		passenger_label.text = "👥 VISITOR • Your passenger stock is not consumed"
		passenger_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_ACCENT
		)
		mastery_label.text = "%s FLIGHT • %s" % [
			relationship.to_upper(),
			country_id
		]
		primary_button.text = "👥  SOCIAL NETWORK"
		primary_button.disabled = false
		GameUIStyle.apply_button(
			primary_button,
			"gold"
		)
		fleet_button.visible = false
		return

	var can_choose_route := aircraft.can_change_flight_plan()
	if can_choose_route:
		primary_button.text = "🌍  CHOOSE ROUTE"
		primary_button.disabled = false
		GameUIStyle.apply_button(
			primary_button,
			"primary"
		)
		fleet_button.visible = true
	else:
		primary_button.text = "✈  VIEW IN FLEET"
		primary_button.disabled = false
		GameUIStyle.apply_button(
			primary_button,
			"selected"
		)
		fleet_button.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 14
	panel.offset_top = -344
	panel.offset_right = 430
	panel.offset_bottom = -84
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "raised")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(112, 82)
	GameUIStyle.apply_panel(preview, "dark")
	header.add_child(preview)

	aircraft_image = TextureRect.new()
	aircraft_image.custom_minimum_size = Vector2(108, 78)
	aircraft_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aircraft_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aircraft_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(aircraft_image)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_text)

	title_label = Label.new()
	GameUIStyle.heading(title_label, 18)
	header_text.add_child(title_label)

	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 13)
	header_text.add_child(state_label)

	mastery_label = Label.new()
	mastery_label.add_theme_font_size_override("font_size", 13)
	mastery_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	header_text.add_child(mastery_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 42)
	GameUIStyle.apply_button(
		close_button,
		"secondary",
		true
	)
	close_button.pressed.connect(close_card)
	header.add_child(close_button)

	route_label = Label.new()
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_label.add_theme_font_size_override("font_size", 14)
	route_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	column.add_child(route_label)

	service_label = Label.new()
	service_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	service_label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(service_label)
	column.add_child(service_label)

	passenger_label = Label.new()
	passenger_label.add_theme_font_size_override("font_size", 13)
	column.add_child(passenger_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	primary_button = Button.new()
	primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_button.custom_minimum_size = Vector2(0, 48)
	primary_button.pressed.connect(
		_on_primary_pressed
	)
	GameUIStyle.apply_button(
		primary_button,
		"primary"
	)
	actions.add_child(primary_button)

	fleet_button = Button.new()
	fleet_button.text = "FLEET"
	fleet_button.custom_minimum_size = Vector2(100, 48)
	fleet_button.pressed.connect(
		_on_fleet_pressed
	)
	GameUIStyle.apply_button(
		fleet_button,
		"secondary",
		true
	)
	actions.add_child(fleet_button)


func _route_text(
	aircraft: AircraftPrototype,
	plan: Dictionary
) -> String:
	if plan.is_empty():
		return "No destination assigned"

	var text := "→ %s, %s" % [
		String(plan.get("city", "Destination")),
		String(plan.get("country", ""))
	]
	if aircraft.state == "EN_ROUTE":
		text += "  •  %s remaining" % (
			FlightRules.format_duration(
				aircraft.get_flight_remaining_seconds()
			)
		)
	return text


func _service_text(aircraft: AircraftPrototype) -> String:
	if aircraft.is_taxi_holding():
		return "Taxi hold • %s" % aircraft.get_taxi_hold_reason()

	if (
		aircraft.turnaround_panel != null
		and aircraft.turnaround_panel.visible
		and aircraft.turnaround_label != null
		and not aircraft.turnaround_label.text.is_empty()
	):
		return aircraft.turnaround_label.text

	match aircraft.state:
		"READY_FOR_DESTINATION":
			return "Ready for a destination assignment"
		"WAITING_PASSENGERS":
			return "Waiting for enough passengers to board"
		"READY_FOR_DEPARTURE":
			return "Turnaround complete • awaiting runway"
		"HOLD_SHORT":
			return "Holding short • awaiting runway clearance"
		"EN_ROUTE":
			return "Airborne"
		"HOLDING_FOR_ARRIVAL":
			return "Inbound • waiting for stand/runway"
		_:
			return TurnaroundRules.compact_summary(
				aircraft.get_aircraft_profile()
			)


func _apply_state_color(state: String) -> void:
	var color := GameUIStyle.COLOR_TEXT
	if state in [
		"READY_FOR_DESTINATION",
		"READY_FOR_DEPARTURE",
		"PARKED"
	]:
		color = GameUIStyle.COLOR_SUCCESS
	elif state in [
		"WAITING_PASSENGERS",
		"HOLD_SHORT",
		"HOLDING_FOR_ARRIVAL"
	]:
		color = GameUIStyle.COLOR_WARNING
	elif state in [
		"TAKEOFF_ROLL",
		"CLIMBING",
		"EN_ROUTE",
		"APPROACH",
		"LANDING_ROLL"
	]:
		color = GameUIStyle.COLOR_ACCENT

	state_label.add_theme_color_override(
		"font_color",
		color
	)


func _aircraft_texture(
	aircraft_type_id: String
) -> Texture2D:
	if aircraft_type_id.is_empty():
		return null

	var path := (
		"res://assets/pixel/aircraft/%s/%s_ne.png"
		% [aircraft_type_id, aircraft_type_id]
	)
	if not ResourceLoader.exists(path):
		return null

	var resource := load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _on_primary_pressed() -> void:
	if (
		selected_aircraft == null
		or not is_instance_valid(selected_aircraft)
	):
		return

	if selected_aircraft.is_social_visitor():
		social_requested.emit(
			selected_aircraft
		)
	elif selected_aircraft.can_change_flight_plan():
		choose_route_requested.emit(
			selected_aircraft
		)
	else:
		fleet_requested.emit(
			selected_aircraft
		)


func _on_fleet_pressed() -> void:
	if (
		selected_aircraft != null
		and is_instance_valid(selected_aircraft)
	):
		fleet_requested.emit(
			selected_aircraft
		)
