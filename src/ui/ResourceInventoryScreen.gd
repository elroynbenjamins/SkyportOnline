class_name ResourceInventoryScreen
extends CanvasLayer

signal rewarded_passenger_boost_requested
signal customize_requested

var root: Control
var passenger_label: Label
var passenger_boost_button: Button
var passenger_support_label: Label
var economy_history_label: Label
var resource_list: VBoxContainer


func _ready() -> void:
	layer = 35
	_build_ui()
	root.visible = false


func open_inventory(
	inventory: Dictionary,
	passengers: int,
	passenger_capacity: int,
	passengers_per_minute: float,
	rewarded_ad_available: bool = false,
	economy_stats: Dictionary = {}
) -> void:
	_refresh(
		inventory,
		passengers,
		passenger_capacity,
		passengers_per_minute,
		rewarded_ad_available,
		economy_stats
	)
	root.visible = true


func close_inventory() -> void:
	root.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("071923", 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 80
	panel.offset_top = 45
	panel.offset_right = -80
	panel.offset_bottom = -45
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := Label.new()
	title.text = "REGIONAL RESOURCES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)

	var customize_button := Button.new()
	customize_button.text = "🎨  CUSTOMIZE"
	customize_button.custom_minimum_size = Vector2(155, 44)
	customize_button.pressed.connect(
		func() -> void:
			customize_requested.emit()
	)
	header.add_child(customize_button)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(140, 44)
	close_button.pressed.connect(close_inventory)
	header.add_child(close_button)

	passenger_label = Label.new()
	passenger_label.add_theme_font_size_override("font_size", 16)
	passenger_label.add_theme_color_override("font_color", Color("f1d27a"))
	column.add_child(passenger_label)


	var passenger_actions := HBoxContainer.new()
	passenger_actions.add_theme_constant_override("separation", 10)
	column.add_child(passenger_actions)

	passenger_boost_button = Button.new()
	passenger_boost_button.text = "WATCH AD  •  +25 PASSENGERS"
	passenger_boost_button.custom_minimum_size = Vector2(300, 44)
	passenger_boost_button.pressed.connect(
		_on_rewarded_passenger_boost_pressed
	)
	passenger_actions.add_child(passenger_boost_button)

	passenger_support_label = Label.new()
	passenger_support_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passenger_support_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passenger_support_label.add_theme_font_size_override("font_size", 13)
	passenger_support_label.add_theme_color_override(
		"font_color",
		Color("a9c6cf")
	)
	passenger_actions.add_child(passenger_support_label)

	var explanation := Label.new()
	explanation.text = (
		"Country resources are earned from completed flights and spent on "
		+ "airport production/storage upgrades."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 13)
	explanation.add_theme_color_override("font_color", Color("a9c6cf"))
	column.add_child(explanation)


	economy_history_label = Label.new()
	economy_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_history_label.add_theme_font_size_override("font_size", 13)
	economy_history_label.add_theme_color_override(
		"font_color",
		Color("9fe3b7")
	)
	column.add_child(economy_history_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	resource_list = VBoxContainer.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_list.add_theme_constant_override("separation", 8)
	scroll.add_child(resource_list)


func _refresh(
	inventory: Dictionary,
	passengers: int,
	passenger_capacity: int,
	passengers_per_minute: float,
	rewarded_ad_available: bool,
	economy_stats: Dictionary
) -> void:
	passenger_label.text = (
		"👥 Passengers: %d / %d   •   +%.1f per minute"
		% [passengers, passenger_capacity, passengers_per_minute]
	)

	passenger_boost_button.disabled = not rewarded_ad_available
	if rewarded_ad_available:
		passenger_support_label.text = (
			"Rewarded boost: +25 passengers after a completed ad.  "
			+ "Friend gifts later: +10 each, max 3 incoming gifts/day."
		)
	else:
		passenger_support_label.text = (
			"Rewarded +25 passenger hook is ready; ad provider not "
			+ "connected yet. Friend gifts later: +10 each, max 3/day."
		)


	economy_history_label.text = (
		"LIFETIME AIRPORT FLOW  •  Generated %d pax  •  Boarded %d pax  "
		+ "•  Flights %d  •  Flight coins %d  •  XP %d  •  Resources %d"
	) % [
		int(economy_stats.get("passengers_generated", 0)),
		int(economy_stats.get("passengers_boarded", 0)),
		int(economy_stats.get("flights_completed", 0)),
		int(economy_stats.get("flight_coins", 0)),
		int(economy_stats.get("flight_xp", 0)),
		int(economy_stats.get("resources_earned", 0))
	]

	for child in resource_list.get_children():
		child.queue_free()

	var any_owned := false
	for country in CountryCatalog.get_countries():
		var country_code := String(country.get("id", ""))
		var resources: Array = country.get("resources", [])
		var owned_in_country := false
		for resource in resources:
			if int(inventory.get(String(resource.get("id", "")), 0)) > 0:
				owned_in_country = true
				break

		if not owned_in_country:
			continue

		any_owned = true
		var country_title := Label.new()
		country_title.text = "%s  •  %s" % [
			country_code,
			String(country.get("name", "Country"))
		]
		country_title.add_theme_font_size_override("font_size", 17)
		country_title.add_theme_color_override("font_color", Color("8dd6e8"))
		resource_list.add_child(country_title)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		resource_list.add_child(row)

		for resource in resources:
			var resource_id := String(resource.get("id", ""))
			var amount := int(inventory.get(resource_id, 0))
			if amount <= 0:
				continue

			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(card)

			var label := Label.new()
			label.custom_minimum_size = Vector2(0, 56)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.text = "%s\nOwned: %d" % [
				String(resource.get("name", "Resource")),
				amount
			]
			label.add_theme_font_size_override("font_size", 14)
			card.add_child(label)

	if not any_owned:
		var empty := Label.new()
		empty.text = (
			"No country resources owned yet.\n"
			+ "Complete international flights to start collecting them."
		)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		resource_list.add_child(empty)


func _on_rewarded_passenger_boost_pressed() -> void:
	rewarded_passenger_boost_requested.emit()
