class_name SocialAirportScreen
extends CanvasLayer

signal close_requested
signal visit_requested(contact_id: String)
signal passenger_gift_requested(contact_id: String)
signal alliance_operations_requested

var root: Control
var network_label: Label
var summary_label: Label
var contacts_list: VBoxContainer
var incoming_list: VBoxContainer
var history_list: VBoxContainer
var gift_status_label: Label
var alliance_ops_button: Button
var snapshot: Dictionary = {}


func _ready() -> void:
	layer = 34
	_build_ui()
	root.visible = false


func open_screen(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	_refresh()
	root.visible = true


func close_screen() -> void:
	if root != null:
		root.visible = false


func is_open() -> bool:
	return root != null and root.visible


func set_snapshot(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	if is_open():
		_refresh()


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

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_top = 10
	top.offset_right = -10
	top.offset_bottom = 76
	root.add_child(top)
	GameUIStyle.apply_panel(top, "top")

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top.add_child(top_row)

	var title := Label.new()
	title.text = "👥  SOCIAL AIRPORT NETWORK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.heading(title, 22)
	top_row.add_child(title)

	network_label = Label.new()
	network_label.text = "LOCAL NETWORK"
	network_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	network_label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(network_label)
	top_row.add_child(network_label)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(140, 42)
	close_button.pressed.connect(_on_close_pressed)
	GameUIStyle.apply_button(close_button, "secondary", true)
	top_row.add_child(close_button)

	var summary_panel := PanelContainer.new()
	summary_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	summary_panel.offset_left = 10
	summary_panel.offset_top = 86
	summary_panel.offset_right = -10
	summary_panel.offset_bottom = 142
	root.add_child(summary_panel)
	GameUIStyle.apply_panel(summary_panel, "dark")

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 16)
	summary_panel.add_child(summary_row)

	summary_label = Label.new()
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_row.add_child(summary_label)

	gift_status_label = Label.new()
	gift_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gift_status_label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(gift_status_label)
	summary_row.add_child(gift_status_label)

	alliance_ops_button = Button.new()
	alliance_ops_button.text = "◆ ALLIANCE OPS"
	alliance_ops_button.custom_minimum_size = Vector2(158, 42)
	GameUIStyle.apply_button(alliance_ops_button, "event", true)
	alliance_ops_button.pressed.connect(_on_alliance_ops_pressed)
	summary_row.add_child(alliance_ops_button)

	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 10
	columns.offset_top = 152
	columns.offset_right = -10
	columns.offset_bottom = -10
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)

	contacts_list = _build_column(
		columns,
		"FRIENDS & ALLIANCE",
		0.43
	)
	incoming_list = _build_column(
		columns,
		"INCOMING TRAFFIC",
		0.31
	)
	history_list = _build_column(
		columns,
		"RECENTLY SERVICED",
		0.26
	)


func _build_column(
	parent: HBoxContainer,
	title_text: String,
	stretch_ratio: float
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	GameUIStyle.apply_panel(panel, "raised")
	parent.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	panel.add_child(wrapper)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(title, 15)
	wrapper.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _refresh() -> void:
	var provider_connected := bool(
		snapshot.get("provider_connected", false)
	)
	var local_simulation := bool(
		snapshot.get("local_simulation", false)
	)
	if provider_connected:
		network_label.text = "● ONLINE NETWORK"
		network_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_SUCCESS
		)
	elif local_simulation:
		network_label.text = "◌ LOCAL TEST NETWORK"
		network_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_WARNING
		)
	else:
		network_label.text = "○ NETWORK OFFLINE"
		GameUIStyle.muted(network_label)

	var active: Array = snapshot.get("active_visits", [])
	var social_state: Dictionary = snapshot.get(
		"social_state",
		{}
	)
	summary_label.text = (
		"%d inbound/active • %d visits serviced • 🪙 %d social earnings"
		% [
			active.size(),
			int(social_state.get("visits_serviced_total", 0)),
			int(social_state.get("social_coins_earned", 0))
		]
	)

	var gift_status: Dictionary = snapshot.get(
		"incoming_gift_status",
		{}
	)
	gift_status_label.text = "Incoming passenger gifts %d/%d today • +%d each" % [
		int(gift_status.get("received", 0)),
		int(gift_status.get("cap", 3)),
		PassengerSupportRules.friend_gift_amount()
	]


	var has_alliance := false
	for contact_variant in snapshot.get("contacts", []):
		var contact: Dictionary = contact_variant
		if String(contact.get("relationship", "")) == "alliance":
			has_alliance = true
			break
	if alliance_ops_button != null:
		var level_unlocked := bool(
			snapshot.get(
				"alliance_operations_level_unlocked",
				true
			)
		)
		var unlock_level := int(
			snapshot.get(
				"alliance_operations_level",
				ActivityProgressionRules.ALLIANCE_UNLOCK_LEVEL
			)
		)
		alliance_ops_button.disabled = (
			not level_unlocked
			or not has_alliance
		)
		alliance_ops_button.text = (
			"◆ ALLIANCE OPS"
			if level_unlocked
			else "◆ OPS • LV %d" % unlock_level
		)
		alliance_ops_button.tooltip_text = (
			"Unlocks at Airport Level %d" % unlock_level
			if not level_unlocked
			else (
				"Weekly cooperative Alliance airport project"
				if has_alliance
				else "Join or connect an Alliance to unlock Alliance Operations"
			)
		)

	_refresh_contacts()
	_refresh_incoming()
	_refresh_history()


func _refresh_contacts() -> void:
	_clear_list(contacts_list)
	var contacts: Array = snapshot.get("contacts", [])
	if contacts.is_empty():
		_add_empty(
			contacts_list,
			"No social contacts available."
		)
		return

	for contact_variant in contacts:
		var contact: Dictionary = contact_variant
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 112)
		GameUIStyle.apply_panel(panel, "dark")
		contacts_list.add_child(panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var country_id := String(contact.get("country_id", ""))
		var country := CountryCatalog.get_country(country_id)
		var relationship := String(
			contact.get("relationship", "friend")
		)
		var badge := Label.new()
		badge.custom_minimum_size = Vector2(50, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.text = (
			"◆\n%s" % country_id
			if relationship == "alliance"
			else "●\n%s" % country_id
		)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_EVENT
			if relationship == "alliance"
			else GameUIStyle.COLOR_ACCENT
		)
		row.add_child(badge)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)

		var name_label := Label.new()
		name_label.text = "%s • %s" % [
			String(contact.get("display_name", "Friend")),
			String(contact.get("airport_code", "APT"))
		]
		GameUIStyle.heading(name_label, 14)
		details.add_child(name_label)

		var airport_label := Label.new()
		airport_label.text = "%s • %s • %s" % [
			String(contact.get("airport_name", "Airport")),
			String(country.get("name", country_id)),
			"ALLIANCE" if relationship == "alliance" else "FRIEND"
		]
		airport_label.add_theme_font_size_override("font_size", 12)
		GameUIStyle.muted(airport_label)
		details.add_child(airport_label)

		var resources := CountryResourceCatalog.resources_for_country(
			country_id
		)
		var resource_names := PackedStringArray()
		for resource in resources:
			resource_names.append(
				String(resource.get("name", "Resource"))
			)
		var resources_label := Label.new()
		resources_label.text = "Possible imports: %s" % (
			" • ".join(resource_names)
		)
		resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resources_label.add_theme_font_size_override("font_size", 11)
		GameUIStyle.muted(resources_label)
		details.add_child(resources_label)

		var actions := VBoxContainer.new()
		actions.custom_minimum_size = Vector2(126, 0)
		row.add_child(actions)

		var visit_button := Button.new()
		visit_button.text = "REQUEST VISIT"
		visit_button.custom_minimum_size = Vector2(120, 38)
		visit_button.pressed.connect(
			_on_visit_pressed.bind(
				String(contact.get("id", ""))
			)
		)
		GameUIStyle.apply_button(visit_button, "primary", true)
		actions.add_child(visit_button)

		var gift_button := Button.new()
		var can_send := bool(
			contact.get("can_send_gift", false)
		)
		gift_button.text = (
			"GIFT +%d PAX" % PassengerSupportRules.friend_gift_amount()
			if can_send
			else "GIFT SENT ✓"
		)
		gift_button.disabled = not can_send
		gift_button.custom_minimum_size = Vector2(120, 36)
		gift_button.pressed.connect(
			_on_gift_pressed.bind(
				String(contact.get("id", ""))
			)
		)
		GameUIStyle.apply_button(
			gift_button,
			"gold" if can_send else "secondary",
			true
		)
		actions.add_child(gift_button)


func _refresh_incoming() -> void:
	_clear_list(incoming_list)
	var active: Array = snapshot.get("active_visits", [])
	if active.is_empty():
		_add_empty(
			incoming_list,
			"No visiting aircraft right now. Request a visit from a contact."
		)
		return

	for visit_variant in active:
		var visit: Dictionary = visit_variant
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 86)
		GameUIStyle.apply_panel(panel, "dark")
		incoming_list.add_child(panel)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		panel.add_child(box)

		var title := Label.new()
		title.text = "%s • %s" % [
			String(visit.get("airport_code", "APT")),
			String(visit.get("aircraft_name", "Aircraft"))
		]
		GameUIStyle.heading(title, 13)
		box.add_child(title)

		var state := String(
			visit.get("state", "INBOUND")
		).replace("_", " ").capitalize()
		var state_label := Label.new()
		state_label.text = "%s • %s • %s" % [
			state,
			String(visit.get("country_id", "")),
			String(visit.get("relationship", "friend")).capitalize()
		]
		state_label.add_theme_font_size_override("font_size", 12)
		state_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_WARNING
			if state in ["Holding For Arrival", "Hold Short"]
			else GameUIStyle.COLOR_ACCENT
		)
		box.add_child(state_label)

		var hint := Label.new()
		hint.text = "Uses your real runway, stand and ground-service capacity."
		hint.add_theme_font_size_override("font_size", 11)
		GameUIStyle.muted(hint)
		box.add_child(hint)


func _refresh_history() -> void:
	_clear_list(history_list)
	var completed: Array = snapshot.get("recent_completed", [])
	if completed.is_empty():
		_add_empty(
			history_list,
			"No visitor flights serviced yet."
		)
		return

	for item_variant in completed:
		var item: Dictionary = item_variant
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 84)
		GameUIStyle.apply_panel(panel, "dark")
		history_list.add_child(panel)

		var box := VBoxContainer.new()
		panel.add_child(box)

		var title := Label.new()
		title.text = "%s • %s" % [
			String(item.get("airport_name", "Friend Airport")),
			String(item.get("country_id", ""))
		]
		GameUIStyle.heading(title, 13)
		box.add_child(title)

		var reward: Dictionary = item.get(
			"host_reward",
			{}
		)
		var reward_label := Label.new()
		reward_label.text = SocialFlightRules.reward_summary(reward)
		reward_label.add_theme_font_size_override("font_size", 12)
		reward_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_GOLD
		)
		box.add_child(reward_label)

		var owner_reward: Dictionary = item.get(
			"owner_reward",
			{}
		)
		var owner_label := Label.new()
		owner_label.text = "Visitor owner receipt: 🪙 %d • XP %d" % [
			int(owner_reward.get("coins", 0)),
			int(owner_reward.get("xp", 0))
		]
		owner_label.add_theme_font_size_override("font_size", 11)
		GameUIStyle.muted(owner_label)
		box.add_child(owner_label)


func _clear_list(list: VBoxContainer) -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()


func _add_empty(list: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(label)
	list.add_child(label)


func _on_visit_pressed(contact_id: String) -> void:
	if not contact_id.is_empty():
		visit_requested.emit(contact_id)


func _on_gift_pressed(contact_id: String) -> void:
	if not contact_id.is_empty():
		passenger_gift_requested.emit(contact_id)


func _on_close_pressed() -> void:
	close_screen()
	close_requested.emit()


func _on_alliance_ops_pressed() -> void:
	alliance_operations_requested.emit()
