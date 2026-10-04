class_name FleetPanel
extends PanelContainer

signal close_requested
signal aircraft_selected(fleet_uid: int)
signal aircraft_purchase_requested(aircraft_id: String)
signal route_requested(fleet_uid: int, route_id: String)

var owned_list: VBoxContainer
var catalog_list: VBoxContainer
var route_list: VBoxContainer
var selected_title: Label
var selected_details: Label
var capacity_label: Label
var hint_label: Label

var selected_fleet_uid := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 32
	offset_top = 84
	offset_right = -32
	offset_bottom = -80
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()


func _build_interface() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	add_child(wrapper)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	wrapper.add_child(header)

	var title := Label.new()
	title.text = "FLEET & ROUTE PLANNER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	capacity_label = Label.new()
	capacity_label.text = "Hangar 0/0"
	capacity_label.add_theme_font_size_override("font_size", 16)
	header.add_child(capacity_label)

	var close_button := Button.new()
	close_button.text = "✕ CLOSE"
	close_button.custom_minimum_size = Vector2(110, 42)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)

	hint_label = Label.new()
	hint_label.text = "Select a parked aircraft, choose a destination, then ground services will prepare it for departure."
	hint_label.add_theme_font_size_override("font_size", 14)
	wrapper.add_child(hint_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	wrapper.add_child(columns)

	var owned_panel := _make_column(columns, "OWNED FLEET", 300)
	owned_list = owned_panel.get_node("List") as VBoxContainer

	var catalog_panel := _make_column(columns, "AIRCRAFT CATALOG", 360)
	catalog_list = catalog_panel.get_node("List") as VBoxContainer

	var planner_panel := _make_column(columns, "ROUTE PLANNER", 0)
	planner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var planner_list := planner_panel.get_node("List") as VBoxContainer

	selected_title = Label.new()
	selected_title.text = "Select an aircraft"
	selected_title.add_theme_font_size_override("font_size", 18)
	planner_list.add_child(selected_title)

	selected_details = Label.new()
	selected_details.text = "Routes and expected profit will appear here."
	selected_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_details.add_theme_font_size_override("font_size", 13)
	planner_list.add_child(selected_details)

	var separator := HSeparator.new()
	planner_list.add_child(separator)

	route_list = VBoxContainer.new()
	route_list.add_theme_constant_override("separation", 4)
	planner_list.add_child(route_list)


func _make_column(parent: HBoxContainer, heading: String, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	if width > 0:
		panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Column"
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var label := Label.new()
	label.text = heading
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)

	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	box.add_child(list)
	return box


func configure(
	fleet_entries: Array[Dictionary],
	catalog_entries: Array[Dictionary],
	route_entries: Array[Dictionary],
	active_fleet_uid: int,
	capacity: Dictionary
) -> void:
	selected_fleet_uid = active_fleet_uid
	_clear(owned_list)
	_clear(catalog_list)
	_clear(route_list)

	capacity_label.text = "HANGAR  %d / %d  •  %d FREE" % [
		int(capacity.get("total_used", 0)),
		int(capacity.get("total_capacity", 0)),
		int(capacity.get("total_free", 0))
	]

	if fleet_entries.is_empty():
		var none := Label.new()
		none.text = "No aircraft owned."
		owned_list.add_child(none)

	for entry in fleet_entries:
		var button := Button.new()
		var uid := int(entry.get("fleet_uid", -1))
		var marker := "▶ " if uid == selected_fleet_uid else ""
		var state := String(entry.get("state", "HANGAR"))
		var destination := String(entry.get("destination_name", ""))
		var second_line := "%s • %s" % [
			String(entry.get("size_class", "S")),
			state.replace("_", " ").capitalize()
		]
		if not destination.is_empty():
			second_line += " → " + destination
		button.text = "%s%s  %s\n%s" % [
			marker,
			String(entry.get("label", "Aircraft")),
			String(entry.get("name", "")),
			second_line
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 52)
		button.pressed.connect(
			func() -> void: aircraft_selected.emit(uid)
		)
		owned_list.add_child(button)

	for entry in catalog_entries:
		var button := Button.new()
		var aircraft_id := String(entry.get("id", ""))
		var can_purchase := bool(entry.get("can_purchase", false))
		var reason := String(entry.get("purchase_reason", ""))
		button.text = "%s  [%s]\n%d pax • %d km • 🪙 %s" % [
			String(entry.get("name", "Aircraft")),
			String(entry.get("size_class", "S")),
			int(entry.get("capacity", 0)),
			int(entry.get("range_km", 0)),
			_format_number(int(entry.get("purchase_price", 0)))
		]
		if not reason.is_empty():
			button.text += " • " + reason
		button.disabled = not can_purchase
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		button.tooltip_text = String(entry.get("specialty", ""))
		button.pressed.connect(
			func() -> void: aircraft_purchase_requested.emit(aircraft_id)
		)
		catalog_list.add_child(button)

	var selected_entry: Dictionary = {}
	for entry in fleet_entries:
		if int(entry.get("fleet_uid", -1)) == selected_fleet_uid:
			selected_entry = entry
			break

	if selected_entry.is_empty():
		selected_title.text = "Select an aircraft"
		selected_details.text = "Choose one of your aircraft to compare its compatible destinations."
		return

	selected_title.text = "%s • %s" % [
		String(selected_entry.get("label", "Aircraft")),
		String(selected_entry.get("name", "Aircraft"))
	]
	selected_details.text = "%d seats • %d km range • %s\n%s" % [
		int(selected_entry.get("capacity", 0)),
		int(selected_entry.get("range_km", 0)),
		String(selected_entry.get("size_class", "S")) + "-class",
		String(selected_entry.get("route_hint", "Choose a destination."))
	]

	for route in route_entries:
		var button := Button.new()
		var route_id := String(route.get("id", ""))
		var can_dispatch := bool(route.get("can_dispatch", false))
		var reason := String(route.get("reason", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)

		if bool(route.get("compatible", false)):
			button.text = "%s → %s  •  %d km\n%d/%d pax • %d min • 🪙 +%s net • +%d XP" % [
				String(route.get("name", "Route")),
				String(route.get("destination_name", "")),
				int(route.get("distance_km", 0)),
				int(route.get("passengers", 0)),
				int(route.get("capacity", 0)),
				int(route.get("duration_minutes", 0)),
				_format_number(int(route.get("net_profit", 0))),
				int(route.get("xp_reward", 0))
			]
		else:
			button.text = "%s → %s  •  %d km\n%s" % [
				String(route.get("name", "Route")),
				String(route.get("destination_name", "")),
				int(route.get("distance_km", 0)),
				reason
			]

		if bool(route.get("selected", false)):
			button.text = "✓ " + button.text
		button.disabled = not can_dispatch
		button.pressed.connect(
			func() -> void:
				route_requested.emit(selected_fleet_uid, route_id)
		)
		route_list.add_child(button)


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


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
