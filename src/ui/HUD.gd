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
var alliance_cosmetic_badge: Label
var cosmetic_border_rects: Array[ColorRect] = []

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

var current_parcel: Dictionary = {}
var current_level := 1
var current_coins := 0
var current_gems := 0
var active_building_id := ""
var event_nav_button: Button


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	interface_root = Control.new()
	var root := interface_root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_cosmetic_frame(root)

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

	title_label = Label.new()
	title_label.text = "✈ SKYPORT ONLINE"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 21)
	top_row.add_child(title_label)

	alliance_cosmetic_badge = Label.new()
	alliance_cosmetic_badge.visible = false
	alliance_cosmetic_badge.custom_minimum_size = Vector2(62, 0)
	alliance_cosmetic_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alliance_cosmetic_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alliance_cosmetic_badge.add_theme_font_size_override("font_size", 20)
	top_row.add_child(alliance_cosmetic_badge)

	passenger_label = Label.new()
	passenger_label.custom_minimum_size = Vector2(175, 0)
	passenger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	passenger_label.add_theme_font_size_override("font_size", 17)
	passenger_label.text = "👥 0 / 0"
	top_row.add_child(passenger_label)

	coins_label = Label.new()
	coins_label.custom_minimum_size = Vector2(130, 0)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(coins_label)

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
		if tab == "build":
			button.disabled = true
		else:
			button.pressed.connect(_on_navigation_pressed.bind(tab))

		if tab == "event":
			event_nav_button = button
			button.visible = false

		nav_row.add_child(button)


func _build_cosmetic_frame(root: Control) -> void:
	var thickness := 6.0
	var top := ColorRect.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = thickness
	_add_cosmetic_border(root, top)

	var bottom := ColorRect.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -thickness
	_add_cosmetic_border(root, bottom)

	var left := ColorRect.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = thickness
	_add_cosmetic_border(root, left)

	var right := ColorRect.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -thickness
	_add_cosmetic_border(root, right)


func _add_cosmetic_border(root: Control, rect: ColorRect) -> void:
	rect.visible = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 95
	root.add_child(rect)
	cosmetic_border_rects.append(rect)


func set_cosmetic_loadout(loadout: Dictionary) -> void:
	var border_id := String(
		loadout.get(CosmeticCatalog.SLOT_AIRPORT_BORDER, "")
	)
	var has_border := not border_id.is_empty()
	var border_color := CosmeticCatalog.visual_color(border_id)
	border_color.a = 0.95
	for rect in cosmetic_border_rects:
		rect.visible = has_border
		if has_border:
			rect.color = border_color

	if alliance_cosmetic_badge == null:
		return

	var flag_id := String(
		loadout.get(CosmeticCatalog.SLOT_ALLIANCE_FLAG, "")
	)
	var emblem_id := String(
		loadout.get(CosmeticCatalog.SLOT_ALLIANCE_EMBLEM, "")
	)
	var symbols := ""
	var names := PackedStringArray()
	var badge_color := Color.WHITE

	if not flag_id.is_empty():
		symbols += "⚑"
		var flag := CosmeticCatalog.get_cosmetic(flag_id)
		names.append(String(flag.get("name", "Alliance Flag")))
		badge_color = CosmeticCatalog.visual_color(flag_id)

	if not emblem_id.is_empty():
		if not symbols.is_empty():
			symbols += " "
		symbols += "◆"
		var emblem := CosmeticCatalog.get_cosmetic(emblem_id)
		names.append(String(emblem.get("name", "Alliance Emblem")))
		badge_color = CosmeticCatalog.visual_color(emblem_id)

	alliance_cosmetic_badge.visible = not symbols.is_empty()
	alliance_cosmetic_badge.text = symbols
	alliance_cosmetic_badge.tooltip_text = ", ".join(names)
	alliance_cosmetic_badge.add_theme_color_override(
		"font_color",
		badge_color
	)


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
	else:
		event_nav_button.text = "🎉\nEVENT"


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
