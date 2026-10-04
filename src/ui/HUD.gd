extends CanvasLayer

signal purchase_expansion_requested

var level_label: Label
var coins_label: Label
var gems_label: Label
var parcel_title: Label
var parcel_requirements: Label
var purchase_button: Button
var current_parcel: Dictionary = {}
var current_level := 1
var current_coins := 0


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
	objective.text = "BUILD YOUR AIRPORT\nExpand your first land parcel"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 15)
	objective_panel.add_child(objective)

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

	var parcel_panel := PanelContainer.new()
	parcel_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	parcel_panel.offset_left = 12
	parcel_panel.offset_top = -226
	parcel_panel.offset_right = -12
	parcel_panel.offset_bottom = -116
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

	var build_hint := Label.new()
	build_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_hint.offset_left = 18
	build_hint.offset_top = -276
	build_hint.offset_right = 390
	build_hint.offset_bottom = -238
	build_hint.text = "BUILD MODE  •  Drag to pan  •  Pinch / wheel to zoom"
	build_hint.add_theme_font_size_override("font_size", 14)
	root.add_child(build_hint)


func set_player_data(level: int, coins: int, gems: int) -> void:
	current_level = level
	current_coins = coins
	level_label.text = "LV %d" % level
	coins_label.text = "🪙 %s" % _format_number(coins)
	gems_label.text = "◆ %s" % _format_number(gems)
	if not current_parcel.is_empty():
		show_parcel(current_parcel, current_level, current_coins)


func show_parcel(parcel: Dictionary, player_level: int, player_coins: int) -> void:
	current_parcel = parcel.duplicate(true)
	current_level = player_level
	current_coins = player_coins

	if parcel.is_empty():
		parcel_title.text = "EXPAND LAND"
		parcel_requirements.text = "Select a parcel"
		purchase_button.text = "SELECT LAND"
		purchase_button.disabled = true
		return

	if parcel.get("owned", false):
		parcel_title.text = "YOUR AIRPORT"
		parcel_requirements.text = "This parcel is already owned."
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


func _on_purchase_pressed() -> void:
	purchase_expansion_requested.emit()


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
