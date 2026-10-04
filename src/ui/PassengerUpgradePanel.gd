class_name PassengerUpgradePanel
extends CanvasLayer

signal upgrade_requested(building_uid: int)

var root: Control
var title_label: Label
var stats_label: Label
var current_stats_label: Label
var next_stats_label: Label
var cost_label: Label
var upgrade_button: Button
var current_building_uid := -1


func _ready() -> void:
	layer = 32
	_build_ui()
	root.visible = false


func open_building(
	building: Dictionary,
	resource_inventory: Dictionary,
	coins: int
) -> void:
	current_building_uid = int(building.get("uid", -1))
	var building_id := String(building.get("definition_id", ""))
	var definition := BuildingCatalog.get_definition(building_id)
	var level := int(building.get("upgrade_level", 1))
	var current := PassengerUpgradeCatalog.get_level(building_id, level)
	var next := PassengerUpgradeCatalog.get_next_level(building_id, level)

	title_label.text = "%s  •  LV %d" % [
		String(definition.get("name", "Passenger Building")).to_upper(),
		level
	]

	current_stats_label.text = (
		"CURRENT\n"
		+ "+%.1f passengers/min\nStorage %d"
	) % [
		float(current.get("passengers_per_minute", 0.0)),
		int(current.get("storage", 0))
	]

	if next.is_empty():
		next_stats_label.text = "MAX LEVEL\nNo further upgrades"
		next_stats_label.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_GOLD
		)
		cost_label.text = "All upgrades complete."
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
		root.visible = true
		return

	var production_delta := (
		float(next.get("passengers_per_minute", 0.0))
		- float(current.get("passengers_per_minute", 0.0))
	)
	var storage_delta := (
		int(next.get("storage", 0))
		- int(current.get("storage", 0))
	)
	next_stats_label.text = (
		"NEXT • LV %d\n"
		+ "+%.1f passengers/min  (%+.1f)\n"
		+ "Storage %d  (%+d)"
	) % [
		int(next.get("level", level + 1)),
		float(next.get("passengers_per_minute", 0.0)),
		production_delta,
		int(next.get("storage", 0)),
		storage_delta
	]
	next_stats_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_SUCCESS
	)

	var coin_cost := int(next.get("coin_cost", 0))
	var resource_cost: Dictionary = next.get(
		"resource_cost",
		{}
	).duplicate(true)
	var can_afford := coins >= coin_cost

	var cost_text := "REQUIREMENTS\n🪙 %d coins" % coin_cost
	for resource_id in resource_cost.keys():
		var needed := int(resource_cost[resource_id])
		var owned := int(resource_inventory.get(resource_id, 0))
		var resource := CountryResourceCatalog.get_resource(
			String(resource_id)
		)
		cost_text += "\n%s  •  %d / %d" % [
			String(resource.get("name", resource_id)),
			owned,
			needed
		]
		if owned < needed:
			can_afford = false

	cost_label.text = cost_text
	upgrade_button.text = "UPGRADE TO LV %d" % int(
		next.get("level", level + 1)
	)
	upgrade_button.disabled = not can_afford
	root.visible = true


func close_panel() -> void:
	root.visible = false
	current_building_uid = -1


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -430
	panel.offset_top = -180
	panel.offset_right = -35
	panel.offset_bottom = 180
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "raised")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title_label, 21)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(46, 42)
	close_button.pressed.connect(close_panel)
	GameUIStyle.apply_button(close_button, "secondary", true)
	header.add_child(close_button)

	var compare_row := HBoxContainer.new()
	compare_row.add_theme_constant_override("separation", 10)
	column.add_child(compare_row)

	var current_card := PanelContainer.new()
	current_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(current_card, "dark")
	compare_row.add_child(current_card)

	current_stats_label = Label.new()
	current_stats_label.custom_minimum_size = Vector2(0, 86)
	current_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_stats_label.add_theme_font_size_override("font_size", 14)
	current_card.add_child(current_stats_label)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(34, 0)
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	compare_row.add_child(arrow)

	var next_card := PanelContainer.new()
	next_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(next_card, "raised")
	compare_row.add_child(next_card)

	next_stats_label = Label.new()
	next_stats_label.custom_minimum_size = Vector2(0, 86)
	next_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_stats_label.add_theme_font_size_override("font_size", 14)
	next_card.add_child(next_stats_label)

	# Legacy alias kept for compatibility with any external UI checks.
	stats_label = current_stats_label

	var note := Label.new()
	note.text = (
		"Internal upgrades improve production and storage only. "
		+ "The building keeps the same visual."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(note)
	column.add_child(note)

	cost_label = Label.new()
	cost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	column.add_child(cost_label)

	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size = Vector2(0, 54)
	upgrade_button.add_theme_font_size_override("font_size", 16)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	GameUIStyle.apply_button(upgrade_button, "primary")
	column.add_child(upgrade_button)


func _on_upgrade_pressed() -> void:
	if current_building_uid >= 0:
		upgrade_requested.emit(current_building_uid)
