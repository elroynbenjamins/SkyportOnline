extends CanvasLayer

signal purchase_expansion_requested
signal building_selected(building_id: String)
signal rotate_building_requested
signal confirm_building_requested
signal cancel_building_requested

var level_label: Label
var coins_label: Label
var gems_label: Label

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
	top_panel.offset_bottom = 84
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

	gems_label = Label.new()
	gems_label.custom_minimum_size = Vector2(92, 0)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gems_label.add_theme_font_size_override("font_size", 19)
	top_row.add_child(gems_label)

	var objective_panel := PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_panel.offset_left = -250
	objective_panel.offset_top = 96
	objective_panel.offset_right = -12
	objective_panel.offset_bottom = 160
	root.add_child(objective_panel)

	var objective := Label.new()
	objective.text = "BUILD YOUR AIRPORT\nPlace infrastructure and expand"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 15)
	objective_panel.add_child(objective)

	var build_hint := Label.new()
	build_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_hint.offset_left = 18
	build_hint.offset_top = -610
	build_hint.offset_right = 520
	build_hint.offset_bottom = -574
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
	parcel_panel.offset_top = -568
	parcel_panel.offset_right = -12
	parcel_panel.offset_bottom = -462
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
	build_action_panel.offset_top = -568
	build_action_panel.offset_right = -12
	build_action_panel.offset_bottom = -462
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
	catalog_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	catalog_panel.offset_left = 8
	catalog_panel.offset_top = -450
	catalog_panel.offset_right = -8
	catalog_panel.offset_bottom = -116
	root.add_child(catalog_panel)

	var catalog_wrapper := VBoxContainer.new()
	catalog_wrapper.add_theme_constant_override("separation", 5)
	catalog_panel.add_child(catalog_wrapper)

	var catalog_header := Label.new()
	catalog_header.text = "AIRPORT BUILDINGS"
	catalog_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_header.add_theme_font_size_override("font_size", 15)
	catalog_wrapper.add_child(catalog_header)

	var grid := GridContainer.new()
	grid.name = "BuildingGrid"
	grid.columns = 5
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	catalog_wrapper.add_child(grid)


func _build_bottom_navigation(root: Control) -> void:
	var bottom_nav := PanelContainer.new()
	bottom_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_nav.offset_left = 8
	bottom_nav.offset_top = -104
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
		button.custom_minimum_size = Vector2(0, 80)
		button.add_theme_font_size_override("font_size", 15)
		if item.begins_with("🔨"):
			button.disabled = true
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
		button.custom_minimum_size = Vector2(124, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		var id := String(definition["id"])
		button.pressed.connect(_on_building_button_pressed.bind(id))
		grid.add_child(button)
		catalog_buttons[id] = button

	_update_catalog_buttons()


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
	place_button.text = "BUILD  🪙 %s" % _format_number(cost)
	place_button.disabled = false


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
