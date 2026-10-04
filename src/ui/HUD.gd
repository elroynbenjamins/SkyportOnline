extends CanvasLayer

signal purchase_expansion_requested
signal building_selected(building_id: String)
signal rotate_building_requested
signal confirm_building_requested
signal cancel_building_requested
signal collect_passengers_requested
signal rewarded_passengers_requested
signal friend_passengers_requested
signal passenger_building_upgrade_requested(uid: int)
signal navigation_requested(tab: String)

var level_label: Label
var coins_label: Label
var gems_label: Label
var passenger_label: Label
var passenger_status_label: Label
var collect_passengers_button: Button
var rewarded_passengers_button: Button
var friend_passengers_button: Button
var airside_status_label: Label
var operation_status_label: Label

var parcel_panel: PanelContainer
var parcel_title: Label
var parcel_requirements: Label
var purchase_button: Button

var build_action_panel: PanelContainer
var build_title: Label
var build_status: Label
var rotate_button: Button
var place_button: Button

var passenger_building_panel: PanelContainer
var passenger_building_title: Label
var passenger_building_details: Label
var passenger_building_upgrade_button: Button
var selected_passenger_building_uid := -1

var catalog_buttons: Dictionary = {}
var catalog_definitions: Array[Dictionary] = []

var current_parcel: Dictionary = {}
var current_level := 1
var current_coins := 0
var current_gems := 0
var active_building_id := ""


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 12
	top_panel.offset_top = 12
	top_panel.offset_right = -12
	top_panel.offset_bottom = 72
	root.add_child(top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_panel.add_child(top_row)

	level_label = Label.new()
	level_label.custom_minimum_size = Vector2(90, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	top_row.add_child(level_label)

	var title := Label.new()
	title.text = "✈ SKYPORT ONLINE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	top_row.add_child(title)

	coins_label = Label.new()
	coins_label.custom_minimum_size = Vector2(130, 0)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(coins_label)

	passenger_label = Label.new()
	passenger_label.custom_minimum_size = Vector2(140, 0)
	passenger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	passenger_label.add_theme_font_size_override("font_size", 19)
	passenger_label.text = "👥 0 / 0"
	top_row.add_child(passenger_label)

	gems_label = Label.new()
	gems_label.custom_minimum_size = Vector2(92, 0)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gems_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(gems_label)

	var objective_panel := PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_panel.offset_left = -250
	objective_panel.offset_top = 82
	objective_panel.offset_right = -12
	objective_panel.offset_bottom = 146
	root.add_child(objective_panel)

	var objective := Label.new()
	objective.text = "BUILD YOUR AIRPORT\nPlace infrastructure and expand"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 15)
	objective_panel.add_child(objective)

	var airside_panel := PanelContainer.new()
	airside_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	airside_panel.offset_left = 12
	airside_panel.offset_top = 82
	airside_panel.offset_right = 250
	airside_panel.offset_bottom = 146
	root.add_child(airside_panel)

	airside_status_label = Label.new()
	airside_status_label.text = "AIRFIELD STATUS\nChecking taxiway network..."
	airside_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	airside_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	airside_status_label.add_theme_font_size_override("font_size", 14)
	airside_panel.add_child(airside_status_label)

	var operation_panel := PanelContainer.new()
	operation_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	operation_panel.offset_left = 260
	operation_panel.offset_top = 82
	operation_panel.offset_right = 460
	operation_panel.offset_bottom = 146
	root.add_child(operation_panel)

	operation_status_label = Label.new()
	operation_status_label.text = "GROUND OPS\nPreparing first aircraft..."
	operation_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operation_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	operation_status_label.add_theme_font_size_override("font_size", 13)
	operation_panel.add_child(operation_status_label)

	var passenger_panel := PanelContainer.new()
	passenger_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	passenger_panel.offset_left = 470
	passenger_panel.offset_top = 82
	passenger_panel.offset_right = 1018
	passenger_panel.offset_bottom = 146
	root.add_child(passenger_panel)

	var passenger_row := HBoxContainer.new()
	passenger_row.add_theme_constant_override("separation", 5)
	passenger_panel.add_child(passenger_row)

	passenger_status_label = Label.new()
	passenger_status_label.text = "PASSENGERS\nPreparing terminal..."
	passenger_status_label.custom_minimum_size = Vector2(180, 0)
	passenger_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passenger_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passenger_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passenger_status_label.add_theme_font_size_override("font_size", 12)
	passenger_row.add_child(passenger_status_label)

	collect_passengers_button = Button.new()
	collect_passengers_button.custom_minimum_size = Vector2(90, 52)
	collect_passengers_button.text = "COLLECT"
	collect_passengers_button.pressed.connect(_on_collect_passengers_pressed)
	passenger_row.add_child(collect_passengers_button)

	rewarded_passengers_button = Button.new()
	rewarded_passengers_button.custom_minimum_size = Vector2(94, 52)
	rewarded_passengers_button.text = "📺 +25"
	rewarded_passengers_button.pressed.connect(_on_rewarded_passengers_pressed)
	passenger_row.add_child(rewarded_passengers_button)

	friend_passengers_button = Button.new()
	friend_passengers_button.custom_minimum_size = Vector2(94, 52)
	friend_passengers_button.text = "🎁 +5"
	friend_passengers_button.pressed.connect(_on_friend_passengers_pressed)
	passenger_row.add_child(friend_passengers_button)

	var build_hint := Label.new()
	build_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_hint.offset_left = 18
	build_hint.offset_top = -192
	build_hint.offset_right = 760
	build_hint.offset_bottom = -160
	build_hint.text = "BUILD MODE  •  Tap a building, then tap owned land"
	build_hint.add_theme_font_size_override("font_size", 14)
	root.add_child(build_hint)

	_build_context_panel(root)
	_build_catalog_panel(root)
	_build_bottom_navigation(root)


func _build_context_panel(root: Control) -> void:
	parcel_panel = PanelContainer.new()
	parcel_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	parcel_panel.offset_left = 12
	parcel_panel.offset_top = -154
	parcel_panel.offset_right = -450
	parcel_panel.offset_bottom = -82
	root.add_child(parcel_panel)

	var parcel_row := HBoxContainer.new()
	parcel_row.add_theme_constant_override("separation", 16)
	parcel_panel.add_child(parcel_row)

	var parcel_text := VBoxContainer.new()
	parcel_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parcel_row.add_child(parcel_text)

	parcel_title = Label.new()
	parcel_title.text = "EXPAND LAND"
	parcel_title.add_theme_font_size_override("font_size", 20)
	parcel_text.add_child(parcel_title)

	parcel_requirements = Label.new()
	parcel_requirements.text = "Select an expansion parcel"
	parcel_requirements.add_theme_font_size_override("font_size", 16)
	parcel_text.add_child(parcel_requirements)

	purchase_button = Button.new()
	purchase_button.custom_minimum_size = Vector2(210, 74)
	purchase_button.text = "SELECT LAND"
	purchase_button.disabled = true
	purchase_button.pressed.connect(_on_purchase_pressed)
	parcel_row.add_child(purchase_button)

	build_action_panel = PanelContainer.new()
	build_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	build_action_panel.offset_left = 12
	build_action_panel.offset_top = -154
	build_action_panel.offset_right = -450
	build_action_panel.offset_bottom = -82
	build_action_panel.visible = false
	root.add_child(build_action_panel)

	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 10)
	build_action_panel.add_child(build_row)

	var build_text := VBoxContainer.new()
	build_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_row.add_child(build_text)

	build_title = Label.new()
	build_title.text = "PLACE BUILDING"
	build_title.add_theme_font_size_override("font_size", 19)
	build_text.add_child(build_title)

	build_status = Label.new()
	build_status.text = "Tap owned land to preview placement."
	build_status.add_theme_font_size_override("font_size", 14)
	build_text.add_child(build_status)

	rotate_button = Button.new()
	rotate_button.custom_minimum_size = Vector2(92, 72)
	rotate_button.text = "↻\nROTATE"
	rotate_button.pressed.connect(_on_rotate_pressed)
	build_row.add_child(rotate_button)

	var cancel_button := Button.new()
	cancel_button.custom_minimum_size = Vector2(92, 72)
	cancel_button.text = "✕\nCANCEL"
	cancel_button.pressed.connect(_on_cancel_building_pressed)
	build_row.add_child(cancel_button)

	place_button = Button.new()
	place_button.custom_minimum_size = Vector2(150, 72)
	place_button.text = "PLACE"
	place_button.disabled = true
	place_button.pressed.connect(_on_confirm_building_pressed)
	build_row.add_child(place_button)

	passenger_building_panel = PanelContainer.new()
	passenger_building_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	passenger_building_panel.offset_left = 12
	passenger_building_panel.offset_top = -154
	passenger_building_panel.offset_right = -450
	passenger_building_panel.offset_bottom = -82
	passenger_building_panel.visible = false
	root.add_child(passenger_building_panel)

	var passenger_building_row := HBoxContainer.new()
	passenger_building_row.add_theme_constant_override("separation", 12)
	passenger_building_panel.add_child(passenger_building_row)

	var passenger_building_text := VBoxContainer.new()
	passenger_building_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passenger_building_row.add_child(passenger_building_text)

	passenger_building_title = Label.new()
	passenger_building_title.text = "PASSENGER BUILDING"
	passenger_building_title.add_theme_font_size_override("font_size", 18)
	passenger_building_text.add_child(passenger_building_title)

	passenger_building_details = Label.new()
	passenger_building_details.text = "Select a passenger building."
	passenger_building_details.add_theme_font_size_override("font_size", 13)
	passenger_building_text.add_child(passenger_building_details)

	passenger_building_upgrade_button = Button.new()
	passenger_building_upgrade_button.custom_minimum_size = Vector2(190, 72)
	passenger_building_upgrade_button.text = "UPGRADE"
	passenger_building_upgrade_button.disabled = true
	passenger_building_upgrade_button.pressed.connect(
		_on_passenger_building_upgrade_pressed
	)
	passenger_building_row.add_child(passenger_building_upgrade_button)


func _build_catalog_panel(root: Control) -> void:
	var catalog_panel := PanelContainer.new()
	catalog_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	catalog_panel.offset_left = -438
	catalog_panel.offset_top = 158
	catalog_panel.offset_right = -8
	catalog_panel.offset_bottom = -82
	root.add_child(catalog_panel)

	var catalog_wrapper := VBoxContainer.new()
	catalog_wrapper.add_theme_constant_override("separation", 5)
	catalog_panel.add_child(catalog_wrapper)

	var catalog_header := Label.new()
	catalog_header.text = "AIRPORT BUILDINGS"
	catalog_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_header.add_theme_font_size_override("font_size", 15)
	catalog_wrapper.add_child(catalog_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var bottom_nav := PanelContainer.new()
	bottom_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_nav.offset_left = 8
	bottom_nav.offset_top = -72
	bottom_nav.offset_right = -8
	bottom_nav.offset_bottom = -8
	root.add_child(bottom_nav)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 4)
	bottom_nav.add_child(nav_row)

	for item in ["🔨\nBUILD", "✈\nFLEET", "🌍\nWORLD", "👥\nALLIANCE", "☰\nMORE"]:
		var button := Button.new()
		button.text = item
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 15)

		var parts := item.split("\n")
		var tab := String(parts[1]).to_lower()
		if tab == "build":
			button.disabled = true
		else:
			button.pressed.connect(_on_navigation_pressed.bind(tab))
		nav_row.add_child(button)


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
		button.custom_minimum_size = Vector2(195, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.tooltip_text = String(definition.get("description", ""))
		var icon := _catalog_icon_for(definition)
		if icon != null:
			button.icon = icon
		var id := String(definition["id"])
		button.pressed.connect(_on_building_button_pressed.bind(id))
		grid.add_child(button)
		catalog_buttons[id] = button

	_update_catalog_buttons()


func _catalog_icon_for(definition: Dictionary) -> Texture2D:
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
	level_label.text = "LV %d" % level
	coins_label.text = "🪙 %s" % _format_number(coins)
	gems_label.text = "◆ %s" % _format_number(gems)
	_update_catalog_buttons()

	if not active_building_id.is_empty():
		var definition := BuildingCatalog.get_definition(active_building_id)
		show_build_preview(definition, {}, current_level, current_coins)
	elif not current_parcel.is_empty():
		show_parcel(current_parcel, current_level, current_coins)


func show_parcel(parcel: Dictionary, player_level: int, player_coins: int) -> void:
	current_parcel = parcel.duplicate(true)
	current_level = player_level
	current_coins = player_coins

	if not active_building_id.is_empty():
		return

	parcel_panel.visible = true
	build_action_panel.visible = false
	passenger_building_panel.visible = false
	selected_passenger_building_uid = -1

	if parcel.is_empty():
		parcel_title.text = "EXPAND LAND"
		parcel_requirements.text = "Select a parcel"
		purchase_button.text = "SELECT LAND"
		purchase_button.disabled = true
		return

	if parcel.get("owned", false):
		parcel_title.text = "YOUR AIRPORT"
		parcel_requirements.text = "Owned land • ready for airport buildings."
		purchase_button.text = "OWNED"
		purchase_button.disabled = true
		return

	var required_level := int(parcel.get("level", 1))
	var cost := int(parcel.get("cost", 0))
	parcel_title.text = "EXPAND LAND"
	parcel_requirements.text = "Unlock: Lv %d   •   Cost: 🪙 %s" % [required_level, _format_number(cost)]

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
	selected_passenger_building_uid = -1
	parcel_panel.visible = false
	passenger_building_panel.visible = false
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
	rotate_button.visible = bool(definition.get("rotatable", false))
	place_button.text = "TAP LAND"
	place_button.disabled = true


func show_passenger_building(
	building: Dictionary,
	definition: Dictionary,
	state: Dictionary
) -> void:
	if building.is_empty() or definition.is_empty() or state.is_empty():
		return

	active_building_id = ""
	selected_passenger_building_uid = int(building.get("uid", -1))
	parcel_panel.visible = false
	build_action_panel.visible = false
	passenger_building_panel.visible = true

	var upgrade_level := int(state.get("upgrade_level", 1))
	passenger_building_title.text = "%s  •  LV %d" % [
		String(definition.get("name", "Passenger Building")).to_upper(),
		upgrade_level
	]

	var detail_parts: Array[String] = []
	var mode := String(definition.get("passenger_mode", ""))
	if not mode.is_empty():
		detail_parts.append(
			"Ready %d/%d" % [
				int(state.get("stored", 0)),
				int(state.get("storage_capacity", 0))
			]
		)

	var terminal_capacity := int(state.get("terminal_capacity", 0))
	if terminal_capacity > 0:
		detail_parts.append("Terminal capacity %d" % terminal_capacity)

	var quote: Dictionary = state.get("upgrade_quote", {})
	if not bool(quote.get("available", false)):
		detail_parts.append("MAX UPGRADE LEVEL")
		passenger_building_upgrade_button.text = "MAX LEVEL"
		passenger_building_upgrade_button.disabled = true
	else:
		var resource_costs: Dictionary = quote.get("resource_costs", {})
		var needs: Array[String] = []
		for resource_id_variant in resource_costs.keys():
			var resource_id := String(resource_id_variant)
			needs.append(
				"%s x%d" % [
					DestinationCatalog.get_resource_name(resource_id),
					int(resource_costs[resource_id])
				]
			)

		if terminal_capacity > 0:
			detail_parts.append(
				"Next: capacity x%.2f" % float(
					quote.get("capacity_multiplier", 1.0)
				)
			)
		else:
			detail_parts.append(
				"Next: production x%.2f • storage x%.2f" % [
					float(quote.get("rate_multiplier", 1.0)),
					float(quote.get("storage_multiplier", 1.0))
				]
			)

		if not needs.is_empty():
			detail_parts.append("Needs: " + " • ".join(needs))

		passenger_building_upgrade_button.text = "UPGRADE  LV %d" % int(
			quote.get("next_level", upgrade_level + 1)
		)
		passenger_building_upgrade_button.disabled = not bool(
			quote.get("can_afford", false)
		)

	passenger_building_details.text = "  |  ".join(detail_parts)


func show_build_preview(definition: Dictionary, status: Dictionary, player_level: int, player_coins: int) -> void:
	if definition.is_empty():
		return

	active_building_id = String(definition["id"])
	current_level = player_level
	current_coins = player_coins
	parcel_panel.visible = false
	build_action_panel.visible = true
	build_title.text = String(definition["name"]).to_upper()
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
	place_button.text = "BUILD  🪙 %s" % _format_number(cost)
	place_button.disabled = false


func set_passenger_status(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	var current := int(snapshot.get("passengers", 0))
	var capacity := int(snapshot.get("capacity", 0))
	var waiting := int(snapshot.get("stored_waiting", 0))
	var producers := int(snapshot.get("producer_count", 0))
	var ad_reward := int(snapshot.get("ad_reward", 25))
	var ad_uses := int(snapshot.get("ad_uses_today", 0))
	var ad_limit := int(snapshot.get("ad_daily_limit", 3))
	var friend_received := int(snapshot.get("friend_received_today", 0))
	var friend_cap := int(snapshot.get("friend_receive_cap", 50))
	var friend_amount := int(snapshot.get("friend_gift_amount", 5))

	if passenger_label != null:
		passenger_label.text = "👥 %s / %s" % [
			_format_number(current),
			_format_number(capacity)
		]

	if passenger_status_label != null:
		passenger_status_label.text = "PASSENGERS\n%s waiting • %d source%s" % [
			_format_number(waiting),
			producers,
			"" if producers == 1 else "s"
		]

	if collect_passengers_button != null:
		collect_passengers_button.text = "COLLECT\n+%s" % _format_number(waiting)
		collect_passengers_button.disabled = waiting <= 0 or current >= capacity

	if rewarded_passengers_button != null:
		rewarded_passengers_button.text = "📺 +%d\n%d/%d" % [
			ad_reward,
			ad_uses,
			ad_limit
		]
		rewarded_passengers_button.disabled = ad_uses >= ad_limit or current >= capacity

	if friend_passengers_button != null:
		friend_passengers_button.text = "🎁 +%d\n%d/%d" % [
			friend_amount,
			friend_received,
			friend_cap
		]
		friend_passengers_button.disabled = friend_received >= friend_cap or current >= capacity


func set_operation_status(text: String, tone: String = "normal") -> void:
	if operation_status_label == null:
		return

	operation_status_label.text = "GROUND OPS\n" + text
	match tone:
		"warning":
			operation_status_label.add_theme_color_override("font_color", Color("ffc266"))
		"success":
			operation_status_label.add_theme_color_override("font_color", Color("9fe3b7"))
		_:
			operation_status_label.add_theme_color_override("font_color", Color("f2f5f4"))


func set_airside_status(status: Dictionary) -> void:
	if airside_status_label == null:
		return

	var stands_total := int(status.get("stands_total", 0))
	var stands_connected := int(status.get("stands_connected", 0))
	var hangars_total := int(status.get("hangars_total", 0))
	var hangars_connected := int(status.get("hangars_connected", 0))
	var runways := int(status.get("runways", 0))

	if stands_connected == stands_total and hangars_connected == hangars_total:
		airside_status_label.text = "AIRFIELD STATUS  ✓\n%d runway%s • %d/%d stands connected" % [
			runways,
			"" if runways == 1 else "s",
			stands_connected,
			stands_total
		]
		airside_status_label.add_theme_color_override("font_color", Color("9fe3b7"))
	else:
		var disconnected := (stands_total - stands_connected) + (hangars_total - hangars_connected)
		airside_status_label.text = "AIRFIELD WARNING  ⚠\n%d airside building%s need taxiway" % [
			disconnected,
			"" if disconnected == 1 else "s"
		]
		airside_status_label.add_theme_color_override("font_color", Color("ffc266"))


func exit_building_mode() -> void:
	active_building_id = ""
	selected_passenger_building_uid = -1
	build_action_panel.visible = false
	passenger_building_panel.visible = false
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
			button.text = "%s\n🔒 LV %d" % [String(definition["menu_name"]), required_level]
			button.disabled = true
		else:
			button.text = "%s\n🪙 %s • %s" % [
				String(definition["menu_name"]),
				_format_number(cost),
				_size_text(definition)
			]
			button.disabled = false


func _service_text(definition: Dictionary) -> String:
	if String(definition.get("service", "")) != "fuel":
		return ""
	var speed := float(definition.get("service_speed", 1.0))
	var vehicles := int(definition.get("vehicle_capacity", 1))
	return " • Fuel x%.1f • %d truck%s" % [
		speed,
		vehicles,
		"" if vehicles == 1 else "s"
	]


func _size_text(definition: Dictionary) -> String:
	var sizes: PackedStringArray = definition["sizes"]
	var result := ""
	for index in range(sizes.size()):
		if index > 0:
			result += "/"
		result += sizes[index]
	return result


func _on_purchase_pressed() -> void:
	purchase_expansion_requested.emit()


func _on_building_button_pressed(building_id: String) -> void:
	building_selected.emit(building_id)


func _on_rotate_pressed() -> void:
	rotate_building_requested.emit()


func _on_confirm_building_pressed() -> void:
	confirm_building_requested.emit()


func _on_cancel_building_pressed() -> void:
	cancel_building_requested.emit()


func _on_collect_passengers_pressed() -> void:
	collect_passengers_requested.emit()


func _on_rewarded_passengers_pressed() -> void:
	rewarded_passengers_requested.emit()


func _on_friend_passengers_pressed() -> void:
	friend_passengers_requested.emit()


func _on_passenger_building_upgrade_pressed() -> void:
	if selected_passenger_building_uid < 0:
		return
	passenger_building_upgrade_requested.emit(selected_passenger_building_uid)


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


func _on_navigation_pressed(tab: String) -> void:
	navigation_requested.emit(tab)
