class_name FleetScreen
extends CanvasLayer

var root: Control
var screen_title_label: Label
var screen_meta_label: Label
var owned_list: VBoxContainer
var details_title: Label
var selected_aircraft_image: TextureRect
var seats_chip: Label
var range_chip: Label
var speed_chip: Label
var size_chip: Label
var resource_chip: Label
var details_body: Label
var mastery_bar: ProgressBar
var mastery_label: Label
var catalog_list: VBoxContainer
var fleet_summary_label: Label

var aircraft: Array[AircraftPrototype] = []
var mastery_hours_by_type: Dictionary = {}
var player_level := 1
var selected_index := 0
var aircraft_buttons: Array[Button] = []
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
	if refresh_accumulator >= 0.75:
		refresh_accumulator = 0.0
		_refresh_owned_aircraft()
		_refresh_selected_details()


func open_fleet(
	aircraft_nodes: Array[AircraftPrototype],
	current_player_level: int,
	mastery_hours: Dictionary
) -> void:
	aircraft = aircraft_nodes
	player_level = current_player_level
	mastery_hours_by_type = mastery_hours.duplicate(true)

	if aircraft.is_empty():
		selected_index = 0
	else:
		selected_index = clampi(
			selected_index,
			0,
			aircraft.size() - 1
		)

	_refresh_owned_aircraft()
	_refresh_selected_details()
	_refresh_catalog()
	root.visible = true


func close_fleet() -> void:
	root.visible = false


func set_mastery_hours(mastery_hours: Dictionary) -> void:
	mastery_hours_by_type = mastery_hours.duplicate(true)
	if root != null and root.visible:
		_refresh_owned_aircraft()
		_refresh_selected_details()
		_refresh_catalog()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("07151d", 0.975)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	_build_header(root)

	var body := HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 14
	body.offset_top = 78
	body.offset_right = -14
	body.offset_bottom = -14
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	_build_owned_panel(body)
	_build_details_panel(body)
	_build_catalog_panel(body)


func _build_header(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 14
	panel.offset_top = 12
	panel.offset_right = -14
	panel.offset_bottom = 68
	parent.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_top")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(title_box)

	screen_title_label = Label.new()
	screen_title_label.text = "✈  FLEET BAY"
	GameUIStyle.heading(screen_title_label, 24)
	title_box.add_child(screen_title_label)

	screen_meta_label = Label.new()
	screen_meta_label.text = "AIRCRAFT STATUS  •  MASTERY  •  PERFORMANCE"
	screen_meta_label.add_theme_font_size_override("font_size", 11)
	screen_meta_label.add_theme_color_override("font_color", GameUIStyle.COLOR_ACCENT)
	title_box.add_child(screen_meta_label)

	fleet_summary_label = Label.new()
	fleet_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fleet_summary_label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(fleet_summary_label)
	row.add_child(fleet_summary_label)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(145, 42)
	close_button.pressed.connect(close_fleet)
	GameUIStyle.apply_button(close_button, "secondary", true)
	row.add_child(close_button)


func _build_owned_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	parent.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_section")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "YOUR FLEET"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 17)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	owned_list = VBoxContainer.new()
	owned_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_list.add_theme_constant_override("separation", 6)
	scroll.add_child(owned_list)


func _build_details_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_focus")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	details_title = Label.new()
	details_title.text = "SELECT AIRCRAFT"
	GameUIStyle.heading(details_title, 24)
	column.add_child(details_title)

	var preview_card := PanelContainer.new()
	preview_card.custom_minimum_size = Vector2(0, 116)
	GameUIStyle.apply_panel(preview_card, "context_preview")
	column.add_child(preview_card)

	selected_aircraft_image = TextureRect.new()
	selected_aircraft_image.custom_minimum_size = Vector2(180, 108)
	selected_aircraft_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_aircraft_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_aircraft_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_card.add_child(selected_aircraft_image)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	column.add_child(chip_row)

	seats_chip = _make_stat_chip(chip_row, "SEATS", GameUIStyle.COLOR_ACCENT)
	range_chip = _make_stat_chip(chip_row, "RANGE", GameUIStyle.COLOR_SUCCESS)
	speed_chip = _make_stat_chip(chip_row, "SPEED", GameUIStyle.COLOR_GOLD)
	size_chip = _make_stat_chip(chip_row, "SIZE", Color("d8b9ff"))
	resource_chip = _make_stat_chip(chip_row, "RESOURCE", GameUIStyle.COLOR_EVENT)

	mastery_label = Label.new()
	mastery_label.add_theme_font_size_override("font_size", 16)
	mastery_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	column.add_child(mastery_label)

	mastery_bar = ProgressBar.new()
	mastery_bar.custom_minimum_size = Vector2(0, 24)
	mastery_bar.min_value = 0.0
	mastery_bar.max_value = 1.0
	mastery_bar.value = 0.0
	mastery_bar.show_percentage = false
	GameUIStyle.apply_progress(mastery_bar, true)
	column.add_child(mastery_bar)

	details_body = Label.new()
	details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_body.add_theme_font_size_override("font_size", 14)
	details_body.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_TEXT
	)
	column.add_child(details_body)


func _build_catalog_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	parent.add_child(panel)
	GameUIStyle.apply_panel(panel, "screen_section")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "AIRCRAFT CATALOG"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 17)
	column.add_child(heading)

	var note := Label.new()
	note.text = "Aircraft unlock as your airport level grows."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(note)
	column.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	catalog_list = VBoxContainer.new()
	catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_list.add_theme_constant_override("separation", 5)
	scroll.add_child(catalog_list)


func _refresh_owned_aircraft() -> void:
	if owned_list == null:
		return

	while aircraft_buttons.size() < aircraft.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		GameUIStyle.apply_button(button, "build_card", true)
		var index := aircraft_buttons.size()
		button.pressed.connect(_on_aircraft_selected.bind(index))
		owned_list.add_child(button)
		aircraft_buttons.append(button)

	for index in range(aircraft_buttons.size()):
		var button := aircraft_buttons[index]
		button.visible = index < aircraft.size()
		if not button.visible:
			continue

		var plane := aircraft[index]
		button.icon = _aircraft_texture(plane.aircraft_type_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		var hours := _mastery_hours(plane.aircraft_type_id)
		var stars := AircraftMastery.stars_for_hours(hours)
		var route := _route_text(plane)

		button.text = "%s  •  %s\n%s  •  %s\n%s" % [
			String(plane.name),
			plane.aircraft_display_name,
			AircraftMastery.format_stars(stars),
			_state_text(plane),
			route
		]
		GameUIStyle.apply_button(
			button,
			"build_card_selected" if index == selected_index else "build_card",
			true
		)
		button.disabled = index == selected_index

	var active := 0
	var airborne := 0
	var waiting := 0
	for plane in aircraft:
		if plane.state in ["EN_ROUTE", "APPROACH", "LANDING_ROLL"]:
			airborne += 1
		elif plane.state in [
			"WAITING_PASSENGERS",
			"READY_FOR_DESTINATION",
			"READY_FOR_DEPARTURE"
		]:
			waiting += 1
		else:
			active += 1

	fleet_summary_label.text = (
		"%d owned  •  %d airborne  •  %d ground ops  •  %d waiting"
		% [aircraft.size(), airborne, active, waiting]
	)


func _refresh_selected_details() -> void:
	if aircraft.is_empty():
		details_title.text = "NO AIRCRAFT OWNED"
		selected_aircraft_image.texture = null
		_clear_stat_chips()
		mastery_label.text = "Purchase or unlock aircraft to build your fleet."
		mastery_bar.value = 0.0
		details_body.text = ""
		return

	if selected_index < 0 or selected_index >= aircraft.size():
		selected_index = 0

	var plane := aircraft[selected_index]
	var profile := plane.get_aircraft_profile()
	var hours := _mastery_hours(plane.aircraft_type_id)
	var mastery_status := AircraftMastery.status(hours)
	var stars := int(mastery_status.get("stars", 0))
	var next_hours := float(mastery_status.get("next_hours", 0.0))
	var current_floor := _current_mastery_floor(stars)

	details_title.text = "%s  •  %s" % [
		String(plane.name),
		plane.aircraft_display_name
	]
	selected_aircraft_image.texture = _aircraft_texture(
		plane.aircraft_type_id
	)

	seats_chip.text = "SEATS\n%d" % int(
		profile.get("passengers", 0)
	)
	range_chip.text = "RANGE\n%d km" % int(
		profile.get("range_km", 0)
	)
	speed_chip.text = "SPEED\n%d km/h" % int(
		profile.get("cruise_speed_kph", 0)
	)
	size_chip.text = "SIZE\n%s" % String(
		profile.get("size", "?")
	)
	resource_chip.text = "RESOURCE\n%+.0f%%" % (
		float(profile.get("resource_drop_modifier", 0.0)) * 100.0
	)

	mastery_label.text = "%s  •  %.1f flight hours" % [
		AircraftMastery.format_stars(stars),
		hours
	]

	if stars >= 5:
		mastery_bar.min_value = 0.0
		mastery_bar.max_value = 1.0
		mastery_bar.value = 1.0
	else:
		mastery_bar.min_value = current_floor
		mastery_bar.max_value = next_hours
		mastery_bar.value = clampf(hours, current_floor, next_hours)

	var base_passengers := int(profile.get("passengers", 0))
	var plan := plane.get_flight_plan()
	var demand_preview := PassengerDemandRules.preview_from_plan(
		profile,
		plan,
		hours
	)
	var route_passengers := base_passengers
	var mastery_passengers := AircraftMastery.passenger_requirement(
		base_passengers,
		hours
	)
	var demand_label := "No route"
	var load_factor := 1.0
	if not demand_preview.is_empty():
		route_passengers = int(
			demand_preview.get("route_requirement", base_passengers)
		)
		mastery_passengers = int(
			demand_preview.get(
				"mastery_requirement",
				route_passengers
			)
		)
		demand_label = String(
			demand_preview.get("demand_label", "Standard")
		)
		load_factor = float(
			demand_preview.get("adjusted_load_factor", 1.0)
		)
	var resource_modifier := float(
		profile.get("resource_drop_modifier", 0.0)
	)

	var route_detail := "No route assigned"
	if not plan.is_empty():
		route_detail = "%s, %s" % [
			String(plan.get("city", "Destination")),
			String(plan.get("country", ""))
		]
		if plane.state == "EN_ROUTE":
			route_detail += " • %s remaining" % FlightRules.format_duration(
				plane.get_flight_remaining_seconds()
			)

	var next_mastery := AircraftMastery.next_reward_text(stars)
	var progress_text := "Mastery complete"
	if stars < 5:
		progress_text = "Next star at %.0f h • %.1f h remaining" % [
			next_hours,
			maxf(next_hours - hours, 0.0)
		]

	details_body.text = (
		"STATUS\n"
		+ "%s\n"
		% _state_text(plane)
		+ "Route: %s\n"
		% route_detail
		+ "Stand UID: %d  •  Runway UID: %d\n\n"
		% [plane.stand_uid, plane.runway_uid]
		+ "AIRCRAFT\n"
		+ "%s class  •  %s\n"
		% [
			String(profile.get("size", "?")),
			String(profile.get("catalog_role", "Aircraft"))
		]
		+ "Seats: %d\n"
		% base_passengers
		+ "Current route demand: %s • %.0f%%\n"
		% [demand_label, load_factor * 100.0]
		+ "Passengers: %d → %d with Mastery\n"
		% [route_passengers, mastery_passengers]
		+ "Cruise: %d km/h\n"
		% int(profile.get("cruise_speed_kph", 0))
		+ "Range: %d km\n"
		% int(profile.get("range_km", 0))
		+ "Taxi speed: %.0f\n"
		% float(profile.get("taxi_speed", 0.0))
		+ "Resource modifier: %+.0f%%\n\n"
		% (resource_modifier * 100.0)
		+ "TURNAROUND PROFILE\n"
		+ "%s\n"
		% TurnaroundRules.compact_summary(profile)
		+ "Estimated return turnaround: %.0fs\n\n"
		% TurnaroundRules.estimated_turnaround_seconds(profile)
		+ "MASTERY\n"
		+ "%s\n"
		% AircraftMastery.current_benefit_text(stars)
		+ "%s\n"
		% progress_text
		+ "Next reward: %s"
		% next_mastery
	)


func _refresh_catalog() -> void:
	for child in catalog_list.get_children():
		child.queue_free()

	for profile in AircraftCatalog.all():
		var aircraft_id := String(profile.get("id", ""))
		var unlock_level := int(profile.get("unlock_level", 1))
		var owned_count := _owned_count(aircraft_id)
		var hours := _mastery_hours(aircraft_id)
		var stars := AircraftMastery.stars_for_hours(hours)

		var card := PanelContainer.new()
		GameUIStyle.apply_panel(
			card,
			"context" if owned_count > 0 else "screen_section"
		)
		catalog_list.add_child(card)

		var label := Label.new()
		label.custom_minimum_size = Vector2(0, 70)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)

		var lock_text := "UNLOCKED"
		if player_level < unlock_level:
			lock_text = "🔒 LV %d" % unlock_level

		var owned_text := ""
		if owned_count > 0:
			owned_text = " • Owned %d" % owned_count

		label.text = "%s  •  %s%s\n%s  •  %d seats  •  %d km\n%s" % [
			String(profile.get("name", aircraft_id)),
			lock_text,
			owned_text,
			String(profile.get("size", "?")),
			int(profile.get("passengers", 0)),
			int(profile.get("range_km", 0)),
			AircraftMastery.format_stars(stars)
		]

		if player_level < unlock_level:
			label.add_theme_color_override(
				"font_color",
				Color("71858c")
			)
		elif owned_count > 0:
			label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_SUCCESS
			)

		card.add_child(label)


func _make_stat_chip(
	parent: HBoxContainer,
	title: String,
	color: Color
) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 52)
	GameUIStyle.apply_panel(card, "reward_tile")
	parent.add_child(card)

	var label := Label.new()
	label.text = title + "\n—"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)
	return label


func _clear_stat_chips() -> void:
	for chip in [
		seats_chip,
		range_chip,
		speed_chip,
		size_chip,
		resource_chip
	]:
		if chip != null:
			chip.text = "—"


func _aircraft_texture(aircraft_type_id: String) -> Texture2D:
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


func _mastery_hours(aircraft_type_id: String) -> float:
	return maxf(
		float(mastery_hours_by_type.get(aircraft_type_id, 0.0)),
		0.0
	)


func _owned_count(aircraft_type_id: String) -> int:
	var count := 0
	for plane in aircraft:
		if plane.aircraft_type_id == aircraft_type_id:
			count += 1
	return count


func _route_text(plane: AircraftPrototype) -> String:
	var plan := plane.get_flight_plan()
	if plan.is_empty():
		return "No destination"
	return "→ %s" % String(plan.get("city", "Destination"))


func _state_text(plane: AircraftPrototype) -> String:
	var state_text := plane.state.replace("_", " ").capitalize()
	if plane.state == "EN_ROUTE":
		state_text += " • %s" % FlightRules.format_duration(
			plane.get_flight_remaining_seconds()
		)
	return state_text


func _current_mastery_floor(stars: int) -> float:
	if stars <= 0:
		return 0.0
	if stars >= AircraftMastery.STAR_MILESTONES_HOURS.size():
		return float(
			AircraftMastery.STAR_MILESTONES_HOURS[
				AircraftMastery.STAR_MILESTONES_HOURS.size() - 1
			]
		)
	return float(
		AircraftMastery.STAR_MILESTONES_HOURS[stars - 1]
	)


func _on_aircraft_selected(index: int) -> void:
	if index < 0 or index >= aircraft.size():
		return
	selected_index = index
	_refresh_owned_aircraft()
	_refresh_selected_details()
