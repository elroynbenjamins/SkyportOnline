class_name PassengerUpgradePanel
extends CanvasLayer

signal upgrade_requested(building_uid: int)

var root: Control
var title_label: Label
var stats_label: Label
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

	var current_rate := float(current.get("passengers_per_minute", 0.0))
	var current_storage := int(current.get("storage", 0))
	if current_rate <= 0.0:
		stats_label.text = "Current passenger capacity: %d" % current_storage
	else:
		stats_label.text = "Current: +%.1f passengers/min • Storage %d" % [
			current_rate,
			current_storage
		]

	if next.is_empty():
		cost_label.text = "Maximum upgrade level reached."
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
		root.visible = true
		return

	var next_rate := float(next.get("passengers_per_minute", 0.0))
	var next_storage := int(next.get("storage", 0))
	if current_rate <= 0.0 and next_rate <= 0.0:
		stats_label.text += "\nNext passenger capacity: %d" % next_storage
	else:
		stats_label.text += "\nNext: +%.1f passengers/min • Storage %d" % [
			next_rate,
			next_storage
		]

	var coin_cost := int(next.get("coin_cost", 0))
	var resource_cost: Dictionary = next.get(
		"resource_cost",
		{}
	).duplicate(true)
	var can_afford := coins >= coin_cost

	var cost_text := "Upgrade cost: 🪙 %d" % coin_cost
	for resource_id in resource_cost.keys():
		var needed := int(resource_cost[resource_id])
		var owned := int(resource_inventory.get(resource_id, 0))
		var resource := CountryResourceCatalog.get_resource(
			String(resource_id)
		)
		cost_text += "\n%s: %d / %d" % [
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
	title_label.add_theme_font_size_override("font_size", 21)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(46, 42)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 16)
	column.add_child(stats_label)

	var note := Label.new()
	note.text = (
		"Internal upgrades improve production and storage only. "
		+ "The building keeps the same visual."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("a9c6cf"))
	column.add_child(note)

	cost_label = Label.new()
	cost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", 15)
	column.add_child(cost_label)

	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size = Vector2(0, 54)
	upgrade_button.add_theme_font_size_override("font_size", 16)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	column.add_child(upgrade_button)


func _on_upgrade_pressed() -> void:
	if current_building_uid >= 0:
		upgrade_requested.emit(current_building_uid)
