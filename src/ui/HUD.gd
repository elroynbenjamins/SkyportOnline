extends CanvasLayer

signal purchase_expansion_requested
signal building_selected(building_id: String)
signal rotate_building_requested
signal confirm_building_requested
signal cancel_building_requested
signal navigation_requested(tab: String)

var interface_root: Control
var title_label: Label
var level_label: Label
var passenger_label: Label
var coins_label: Label
var gems_label: Label
var airside_status_label: Label
var operation_status_label: Label
var atc_status_label: Label

var airside_status_chip: Button
var operation_status_chip: Button
var atc_status_chip: Button
var status_detail_panel: PanelContainer
var status_detail_title: Label
var status_detail_body: Label
var active_status_chip := ""
var status_details: Dictionary = {}

var parcel_panel: PanelContainer
var parcel_title: Label
var parcel_requirements: Label
var purchase_button: Button

var build_action_panel: PanelContainer
var build_title: Label
var build_status: Label
var rotate_button: Button
var place_button: Button

var catalog_buttons: Dictionary = {}
var catalog_definitions: Array[Dictionary] = []
var catalog_filter_buttons: Dictionary = {}
var selected_catalog_category := "ALL"

var current_parcel: Dictionary = {}
var current_level := 1
var current_coins := 0
var current_gems := 0
var active_building_id := ""
var event_nav_button: Button
var nav_buttons: Dictionary = {}


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
	top_panel.offset_left = 12
	top_panel.offset_top = 12
	top_panel.offset_right = -12
	top_panel.offset_bottom = 72
	root.add_child(top_panel)
	GameUIStyle.apply_panel(top_panel, "top")

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_panel.add_child(top_row)

	level_label = Label.new()
	level_label.custom_minimum_size = Vector2(90, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	top_row.add_child(level_label)

	title_label = Label.new()
	title_label.text = "✈ SKYPORT ONLINE"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_TEXT
	)
	top_row.add_child(title_label)

	passenger_label = Label.new()
	passenger_label.custom_minimum_size = Vector2(175, 0)
	passenger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	passenger_label.add_theme_font_size_override("font_size", 17)
	passenger_label.text = "👥 0 / 0"
	passenger_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	top_row.add_child(passenger_label)

	coins_label = Label.new()
	coins_label.custom_minimum_size = Vector2(130, 0)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 19)
	coins_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	top_row.add_child(coins_label)

	gems_label = Label.new()
	gems_label.custom_minimum_size = Vector2(92, 0)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gems_label.add_theme_font_size_override("font_size", 19)
	gems_label.add_theme_color_override(
		"font_color",
		Color("d8b9ff")
	)
	top_row.add_child(gems_label)

	var objective_panel := PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_panel.offset_left = -250
	objective_panel.offset_top = 82
	objective_panel.offset_right = -12
	objective_panel.offset_bottom = 146
	root.add_child(objective_panel)
	GameUIStyle.apply_panel(objective_panel, "raised")

	var objective := Label.new()
	objective.text = "BUILD YOUR AIRPORT\nPlace infrastructure and expand"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 15)
	objective_panel.add_child(objective)

	var status_strip := HBoxContainer.new()
	status_strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_strip.offset_left = 12
	status_strip.offset_top = 82
	status_strip.offset_right = 680
	status_strip.offset_bottom = 128
	status_strip.add_theme_constant_override("separation", 6)
	root.add_child(status_strip)

	airside_status_chip = Button.new()
	airside_status_chip.text = "🛬 AIRFIELD\nCHECKING..."
	airside_status_chip.custom_minimum_size = Vector2(190, 44)
	GameUIStyle.apply_button(airside_status_chip, "nav", true)
	airside_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("airside")
	)
	status_strip.add_child(airside_status_chip)

	operation_status_chip = Button.new()
	operation_status_chip.text = "🧰 GROUND OPS\nPREPARING..."
	operation_status_chip.custom_minimum_size = Vector2(210, 44)
	GameUIStyle.apply_button(operation_status_chip, "nav", true)
	operation_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("operations")
	)
	status_strip.add_child(operation_status_chip)

	atc_status_chip = Button.new()
	atc_status_chip.text = "🗼 ATC\nCLEAR"
	atc_status_chip.custom_minimum_size = Vector2(230, 44)
	GameUIStyle.apply_button(atc_status_chip, "nav", true)
	atc_status_chip.pressed.connect(
		_on_status_chip_pressed.bind("atc")
	)
	status_strip.add_child(atc_status_chip)

	status_detail_panel = PanelContainer.new()
	status_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_detail_panel.offset_left = 12
	status_detail_panel.offset_top = 134
	status_detail_panel.offset_right = 680
	status_detail_panel.offset_bottom = 216
	status_detail_panel.visible = false
	root.add_child(status_detail_panel)
	GameUIStyle.apply_panel(status_detail_panel, "raised")

	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	status_detail_panel.add_child(detail_row)

	var detail_text := VBoxContainer.new()
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_child(detail_text)

	status_detail_title = Label.new()
	status_detail_title.text = "AIRPORT STATUS"
	GameUIStyle.heading(status_detail_title, 15)
	detail_text.add_child(status_detail_title)

	status_detail_body = Label.new()
	status_detail_body.text = "Select a status chip for details."
	status_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_detail_body.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(status_detail_body)
	detail_text.add_child(status_detail_body)

	var detail_close := Button.new()
	detail_close.text = "✕"
	detail_close.custom_minimum_size = Vector2(44, 44)
	GameUIStyle.apply_button(detail_close, "secondary", true)
	detail_close.pressed.connect(_close_status_detail)
	detail_row.add_child(detail_close)

	# Legacy labels remain as lightweight data sinks for existing setters/tests.
	airside_status_label = Label.new()
	operation_status_label = Label.new()
	atc_status_label = Label.new()

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

	var build_hint := Label.new()
	build_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_hint.offset_left = 18
	build_hint.offset_top = -192
	build_hint.offset_right = 760
	build_hint.offset_bottom = -160
	build_hint.text = "BUILD MODE  •  Tap a building, then tap owned land"
	build_hint.add_theme_font_size_override("font_size", 14)
	build_hint.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_MUTED
	)
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
	GameUIStyle.apply_panel(parcel_panel, "raised")

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
	GameUIStyle.apply_button(purchase_button, "gold")
	parcel_row.add_child(purchase_button)

	build_action_panel = PanelContainer.new()
	build_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	build_action_panel.offset_left = 12
	build_action_panel.offset_top = -154
	build_action_panel.offset_right = -450
	build_action_panel.offset_bottom = -82
	build_action_panel.visible = false
	root.add_child(build_action_panel)
	GameUIStyle.apply_panel(build_action_panel, "raised")

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
	GameUIStyle.apply_button(rotate_button, "secondary", true)
	build_row.add_child(rotate_button)

	var cancel_button := Button.new()
	cancel_button.custom_minimum_size = Vector2(92, 72)
	cancel_button.text = "✕\nCANCEL"
	cancel_button.pressed.connect(_on_cancel_building_pressed)
	GameUIStyle.apply_button(cancel_button, "danger", true)
	build_row.add_child(cancel_button)

	place_button = Button.new()
	place_button.custom_minimum_size = Vector2(150, 72)
	place_button.text = "PLACE"
	place_button.disabled = true
	place_button.pressed.connect(_on_confirm_building_pressed)
	GameUIStyle.apply_button(place_button, "primary")
	build_row.add_child(place_button)


func _build_catalog_panel(root: Control) -> void:
	var catalog_panel := PanelContainer.new()
	catalog_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	catalog_panel.offset_left = -438
	catalog_panel.offset_top = 158
	catalog_panel.offset_right = -8
	catalog_panel.offset_bottom = -82
	root.add_child(catalog_panel)
	GameUIStyle.apply_panel(catalog_panel, "dark")

	var catalog_wrapper := VBoxContainer.new()
	catalog_wrapper.add_theme_constant_override("separation", 5)
	catalog_panel.add_child(catalog_wrapper)

	var catalog_header := Label.new()
	catalog_header.text = "BUILD TRAY"
	catalog_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(catalog_header, 15)
	catalog_wrapper.add_child(catalog_header)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
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
		chip.custom_minimum_size = Vector2(0, 34)
		var category := String(filter_data[1])
		GameUIStyle.apply_button(
			chip,
			"selected" if category == selected_catalog_category else "nav",
			true
		)
		chip.pressed.connect(
			_on_catalog_filter_pressed.bind(category)
		)
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
	var bottom_nav := PanelContainer.new()
	bottom_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_nav.offset_left = 8
	bottom_nav.offset_top = -72
	bottom_nav.offset_right = -8
	bottom_nav.offset_bottom = -8
	root.add_child(bottom_nav)
	GameUIStyle.apply_panel(bottom_nav, "top")

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 4)
	bottom_nav.add_child(nav_row)

	for item in ["🔨\nBUILD", "✈\nFLEET", "🌍\nWORLD", "🎉\nEVENT", "👥\nALLIANCE", "☰\nMORE"]:
		var button := Button.new()
		button.text = item
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 15)

		var parts: PackedStringArray = item.split("\n")
		var tab: String = String(parts[1]).to_lower()
		GameUIStyle.apply_button(
			button,
			"selected" if tab == "build" else "nav",
			true
		)
		nav_buttons[tab] = button
		if tab == "build":
			button.disabled = true
		else:
			button.pressed.connect(_on_navigation_pressed.bind(tab))

		if tab == "event":
			event_nav_button = button
			button.visible = false

		nav_row.add_child(button)


func set_event_available(
	value: bool,
	event_name: String = ""
) -> void:
	if event_nav_button == null:
		return
	event_nav_button.visible = value
	if value:
		event_nav_button.tooltip_text = event_name
	else:
		event_nav_button.tooltip_text = ""


func set_event_attention(claimable: bool) -> void:
	if event_nav_button == null:
		return
	if claimable:
		event_nav_button.text = "🎉 •\nEVENT"
		GameUIStyle.apply_button(event_nav_button, "event", true)
	else:
		event_nav_button.text = "🎉\nEVENT"
		GameUIStyle.apply_button(event_nav_button, "nav", true)


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

	title_label.text = "✈ %s  •  %s  •  %s" % [
		airport_name.to_upper(),
		airport_code.to_upper(),
		country_name
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
		button.custom_minimum_size = Vector2(195, 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.tooltip_text = String(definition.get("description", ""))
		GameUIStyle.apply_button(button, "secondary", true)
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
	for definition in catalog_definitions:
		var id := String(definition.get("id", ""))
		if not catalog_buttons.has(id):
			continue
		var button: Button = catalog_buttons[id]
		var category := String(
			definition.get("category", "")
		)
		button.visible = (
			selected_catalog_category == "ALL"
			or category == selected_catalog_category
		)


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




func set_passenger_data(
	passengers: int,
	capacity: int,
	per_minute: float
) -> void:
	if passenger_label == null:
		return
	passenger_label.text = "👥 %d / %d  +%.1f/m" % [
		passengers,
		capacity,
		per_minute
	]


func show_parcel(parcel: Dictionary, player_level: int, player_coins: int) -> void:
	current_parcel = parcel.duplicate(true)
	current_level = player_level
	current_coins = player_coins

	if not active_building_id.is_empty():
		return

	parcel_panel.visible = true
	build_action_panel.visible = false

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
	rotate_button.visible = bool(definition.get("rotatable", false))
	place_button.text = "TAP LAND"
	place_button.disabled = true


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


func set_operation_status(text: String, tone: String = "normal") -> void:
	if operation_status_label != null:
		operation_status_label.text = "GROUND OPS\n" + text

	_set_status_chip(
		"operations",
		operation_status_chip,
		"GROUND OPS",
		_compact_status(text),
		text,
		tone
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
		if atc_status_label != null:
			atc_status_label.text = "RUNWAY CONTROL\n" + empty_text
		_set_status_chip(
			"atc",
			atc_status_chip,
			"RUNWAY CONTROL",
			"✓ CLEAR",
			empty_text,
			"success"
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
		chip.text = "%s\n%s" % [
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
			return "🛬 AIRFIELD"
		"operations":
			return "🧰 GROUND OPS"
		_:
			return "🗼 ATC"


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
	if compact.length() > 28:
		compact = compact.substr(0, 25) + "..."
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
	build_action_panel.visible = false
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
			GameUIStyle.apply_button(button, "secondary", true)
			button.text = "%s\n🔒 LV %d" % [
				String(definition["menu_name"]),
				required_level
			]
			button.disabled = true
		else:
			GameUIStyle.apply_button(
				button,
				"selected" if id == active_building_id else "secondary",
				true
			)
			button.text = "%s\n🪙 %s • %s" % [
				String(definition["menu_name"]),
				_format_number(cost),
				_size_text(definition)
			]
			button.disabled = false


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
