class_name WorldMapPanel
extends PanelContainer

signal close_requested
signal aircraft_selected(fleet_uid: int)
signal route_requested(fleet_uid: int, route_id: String)

var aircraft_picker: OptionButton
var map_canvas: WorldMapCanvas
var destination_title: Label
var destination_details: Label
var resources_label: Label
var dispatch_button: Button
var view_label: Label

var fleet_entries: Array[Dictionary] = []
var route_entries: Array[Dictionary] = []
var resource_inventory: Dictionary = {}
var selected_fleet_uid := -1
var selected_route_id := ""
var origin_country_code := "NL"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_top = 82
	offset_right = -24
	offset_bottom = -80
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()


func _build_interface() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	add_child(wrapper)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	wrapper.add_child(header)

	var title := Label.new()
	title.text = "WORLD ROUTES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var aircraft_label := Label.new()
	aircraft_label.text = "AIRCRAFT"
	aircraft_label.add_theme_font_size_override("font_size", 13)
	header.add_child(aircraft_label)

	aircraft_picker = OptionButton.new()
	aircraft_picker.custom_minimum_size = Vector2(250, 42)
	aircraft_picker.item_selected.connect(_on_aircraft_picker_selected)
	header.add_child(aircraft_picker)

	var europe_button := Button.new()
	europe_button.text = "EUROPE"
	europe_button.custom_minimum_size = Vector2(92, 42)
	europe_button.pressed.connect(
		func() -> void:
			map_canvas.set_view_mode("EUROPE")
			view_label.text = "EUROPE VIEW"
	)
	header.add_child(europe_button)

	var world_button := Button.new()
	world_button.text = "WORLD"
	world_button.custom_minimum_size = Vector2(92, 42)
	world_button.pressed.connect(
		func() -> void:
			map_canvas.set_view_mode("WORLD")
			view_label.text = "WORLD VIEW"
	)
	header.add_child(world_button)

	var close_button := Button.new()
	close_button.text = "✕ CLOSE"
	close_button.custom_minimum_size = Vector2(108, 42)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	wrapper.add_child(body)

	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map_panel)

	var map_wrapper := VBoxContainer.new()
	map_wrapper.add_theme_constant_override("separation", 4)
	map_panel.add_child(map_wrapper)

	view_label = Label.new()
	view_label.text = "EUROPE VIEW"
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_label.add_theme_font_size_override("font_size", 13)
	map_wrapper.add_child(view_label)

	map_canvas = WorldMapCanvas.new()
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.route_selected.connect(_on_map_route_selected)
	map_wrapper.add_child(map_canvas)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(350, 0)
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(details_panel)

	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_panel.add_child(details_scroll)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)

	destination_title = Label.new()
	destination_title.text = "Select a destination"
	destination_title.add_theme_font_size_override("font_size", 19)
	destination_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(destination_title)

	destination_details = Label.new()
	destination_details.text = "Tap a destination marker to inspect its route."
	destination_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination_details.add_theme_font_size_override("font_size", 14)
	details.add_child(destination_details)

	var resource_header := Label.new()
	resource_header.text = "COUNTRY RESOURCES"
	resource_header.add_theme_font_size_override("font_size", 15)
	details.add_child(resource_header)

	resources_label = Label.new()
	resources_label.text = "Each destination has three unique resources."
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources_label.add_theme_font_size_override("font_size", 14)
	details.add_child(resources_label)

	dispatch_button = Button.new()
	dispatch_button.text = "SELECT DESTINATION"
	dispatch_button.custom_minimum_size = Vector2(0, 58)
	dispatch_button.disabled = true
	dispatch_button.pressed.connect(_on_dispatch_pressed)
	details.add_child(dispatch_button)


func configure(
	new_fleet_entries: Array[Dictionary],
	new_route_entries: Array[Dictionary],
	active_fleet_uid: int,
	new_resource_inventory: Dictionary,
	new_origin_country_code: String = "NL"
) -> void:
	origin_country_code = new_origin_country_code.to_upper()
	fleet_entries.clear()
	for entry in new_fleet_entries:
		fleet_entries.append(entry.duplicate(true))

	route_entries.clear()
	for entry in new_route_entries:
		route_entries.append(_enrich_route(entry))

	resource_inventory = new_resource_inventory.duplicate(true)
	selected_fleet_uid = active_fleet_uid

	_rebuild_aircraft_picker()

	if selected_route_id.is_empty() or not _has_route(selected_route_id):
		selected_route_id = _first_route_id()

	map_canvas.configure(route_entries, origin_country_code)
	var origin := CountryCatalog.get_country(origin_country_code)
	if not origin.is_empty():
		view_label.text = "EUROPE VIEW • HOME: %s" % String(
			origin.get("name", origin_country_code)
		).to_upper()
	_refresh_destination_details()


func _enrich_route(source: Dictionary) -> Dictionary:
	var entry := source.duplicate(true)
	var country := CountryCatalog.get_country(
		String(entry.get("country_code", ""))
	)
	entry["country_name"] = String(country.get("name", "Unknown country"))
	entry["country_resources"] = CountryCatalog.get_resources(
		String(entry.get("country_code", ""))
	)
	return entry


func _rebuild_aircraft_picker() -> void:
	aircraft_picker.clear()
	var selected_index := -1

	for index in range(fleet_entries.size()):
		var entry := fleet_entries[index]
		var uid := int(entry.get("fleet_uid", -1))
		var state := String(entry.get("state", "HANGAR")).replace(
			"_",
			" "
		).capitalize()
		aircraft_picker.add_item(
			"%s • %s • %s" % [
				String(entry.get("label", "Aircraft")),
				String(entry.get("name", "Aircraft")),
				state
			]
		)
		aircraft_picker.set_item_metadata(index, uid)
		if uid == selected_fleet_uid:
			selected_index = index

	if selected_index >= 0:
		aircraft_picker.select(selected_index)
	elif aircraft_picker.item_count > 0:
		aircraft_picker.select(0)
		selected_fleet_uid = int(aircraft_picker.get_item_metadata(0))


func _refresh_destination_details() -> void:
	var route := _route_by_id(selected_route_id)
	if route.is_empty():
		destination_title.text = "Select a destination"
		destination_details.text = "Tap a route marker on the map."
		resources_label.text = "Each resource rolls independently at 40% after a completed flight."
		dispatch_button.text = "SELECT DESTINATION"
		dispatch_button.disabled = true
		return

	var country_name := String(route.get("country_name", "Country"))
	destination_title.text = "%s • %s" % [
		String(route.get("destination_name", "Destination")),
		country_name
	]

	var detail_lines := PackedStringArray([
		"%s • %d km • Airport Lv %d" % [
			String(route.get("name", "Route")),
			int(route.get("distance_km", 0)),
			int(route.get("unlock_level", 1))
		],
		"Passenger demand: %d • Max aircraft: %s" % [
			int(route.get("demand", 0)),
			String(route.get("max_aircraft_size", "S"))
		]
	])

	if bool(route.get("compatible", false)):
		detail_lines.append(
			"%d/%d passengers • %d min • +%d XP" % [
				int(route.get("passengers", 0)),
				int(route.get("capacity", 0)),
				int(route.get("duration_minutes", 0)),
				int(route.get("xp_reward", 0))
			]
		)
		detail_lines.append(
			"Gross 🪙 %s • Cost 🪙 %s • Net +🪙 %s" % [
				_format_number(int(route.get("gross_revenue", 0))),
				_format_number(int(route.get("operating_cost", 0))),
				_format_number(int(route.get("net_profit", 0)))
			]
		)
	else:
		detail_lines.append("Unavailable: " + String(route.get("reason", "Not compatible")))

	destination_details.text = "\n".join(detail_lines)

	var resource_lines := PackedStringArray()
	var chance := int(round(float(route.get("resource_drop_chance", 0.40)) * 100.0))
	for resource_variant in route.get("country_resources", []):
		var resource: Dictionary = resource_variant
		var resource_id := String(resource.get("id", ""))
		var owned := int(resource_inventory.get(resource_id, 0))
		resource_lines.append(
			"• %s  •  %d%% chance  •  Owned %d" % [
				String(resource.get("name", "Resource")),
				chance,
				owned
			]
		)
	resources_label.text = "\n".join(resource_lines)

	var can_dispatch := bool(route.get("can_dispatch", false))
	dispatch_button.disabled = not can_dispatch
	if can_dispatch:
		dispatch_button.text = "DISPATCH TO %s" % String(
			route.get("destination_name", "DESTINATION")
		).to_upper()
	else:
		var reason := String(route.get("reason", "Aircraft unavailable"))
		if bool(route.get("compatible", false)) and reason.is_empty():
			reason = "Aircraft currently unavailable"
		dispatch_button.text = reason.to_upper()


func _on_aircraft_picker_selected(index: int) -> void:
	if index < 0 or index >= aircraft_picker.item_count:
		return
	selected_fleet_uid = int(aircraft_picker.get_item_metadata(index))
	aircraft_selected.emit(selected_fleet_uid)


func _on_map_route_selected(route_id: String) -> void:
	selected_route_id = route_id
	_refresh_destination_details()


func _on_dispatch_pressed() -> void:
	if selected_fleet_uid < 0 or selected_route_id.is_empty():
		return
	route_requested.emit(selected_fleet_uid, selected_route_id)


func _has_route(route_id: String) -> bool:
	for route in route_entries:
		if String(route.get("id", "")) == route_id:
			return true
	return false


func _route_by_id(route_id: String) -> Dictionary:
	for route in route_entries:
		if String(route.get("id", "")) == route_id:
			return route.duplicate(true)
	return {}


func _first_route_id() -> String:
	for route in route_entries:
		if int(route.get("unlock_level", 1)) <= 1:
			return String(route.get("id", ""))
	if not route_entries.is_empty():
		return String(route_entries[0].get("id", ""))
	return ""


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[index] + result
		count += 1
	return result
