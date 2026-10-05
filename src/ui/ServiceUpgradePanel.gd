class_name ServiceUpgradePanel
extends CanvasLayer

signal upgrade_requested(building_uid: int)

var root: Control
var building_image: TextureRect
var title_label: Label
var stats_label: Label
var current_stats_label: Label
var next_stats_label: Label
var cost_label: Label
var upgrade_button: Button
var current_building_uid := -1


func _ready() -> void:
	layer = 33
	_build_ui()
	root.visible = false


func open_building(
	building: Dictionary,
	resource_inventory: Dictionary,
	coins: int
) -> void:
	current_building_uid = int(building.get("uid", -1))
	var building_id := String(
		building.get("definition_id", "")
	)
	var definition := BuildingCatalog.get_definition(building_id)
	var level := int(building.get("upgrade_level", 1))
	var next := ServiceUpgradeCatalog.get_next_level(
		building_id,
		level
	)

	title_label.text = "%s  •  LV %d" % [
		String(
			definition.get("name", "Service Building")
		).to_upper(),
		level
	]
	building_image.texture = _building_texture(definition)

	current_stats_label.text = _stats_text(
		building_id,
		level,
		"CURRENT"
	)

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

	next_stats_label.text = _stats_text(
		building_id,
		int(next.get("level", level + 1)),
		"NEXT • LV %d" % int(next.get("level", level + 1))
	)
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
		var owned := int(
			resource_inventory.get(resource_id, 0)
		)
		var resource := CountryResourceCatalog.get_resource(
			String(resource_id)
		)
		cost_text += "
%s  •  %d / %d" % [
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


func _stats_text(
	building_id: String,
	level: int,
	prefix: String
) -> String:
	var parts: Array[String] = []
	for service_type in ServiceUpgradeCatalog.service_types(
		building_id
	):
		var stats := ServiceUpgradeCatalog.effective_service_stats(
			building_id,
			service_type,
			level
		)
		if stats.is_empty():
			continue
		parts.append(
			"%s x%.2f • %d vehicle%s" % [
				_service_name(service_type),
				float(stats.get("service_speed", 1.0)),
				int(stats.get("vehicle_capacity", 1)),
				"" if int(
					stats.get("vehicle_capacity", 1)
				) == 1 else "s"
			]
		)

	return "%s:
%s" % [
		prefix,
		"
".join(parts)
	]


func _service_name(service_type: String) -> String:
	match service_type:
		"passenger":
			return "Passenger"
		"cargo":
			return "Baggage"
		"cleaning":
			return "Cleaning"
		"catering":
			return "Catering"
		"pushback":
			return "Pushback"
		_:
			return "Fuel"


func _building_texture(
	definition: Dictionary
) -> Texture2D:
	var atlas_path := String(
		definition.get("world_sprite_atlas_path", "")
	)
	var regions: Array = definition.get(
		"world_sprite_regions",
		[]
	)
	if (
		not atlas_path.is_empty()
		and not regions.is_empty()
		and ResourceLoader.exists(atlas_path)
	):
		var atlas_resource := load(atlas_path)
		var first_region = regions[0]
		if (
			atlas_resource is Texture2D
			and first_region is Rect2
		):
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = atlas_resource as Texture2D
			atlas_texture.region = first_region
			return atlas_texture

	var variants: PackedStringArray = definition.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if not variants.is_empty():
		var world_path := String(variants[0])
		if ResourceLoader.exists(world_path):
			var world_resource := load(world_path)
			if world_resource is Texture2D:
				return world_resource as Texture2D

	var single_world_path := String(
		definition.get("world_sprite_path", "")
	)
	if (
		not single_world_path.is_empty()
		and ResourceLoader.exists(single_world_path)
	):
		var single_world_resource := load(
			single_world_path
		)
		if single_world_resource is Texture2D:
			return single_world_resource as Texture2D

	var icon_path := String(
		definition.get("icon_path", "")
	)
	if (
		icon_path.is_empty()
		or not ResourceLoader.exists(icon_path)
	):
		return null
	var icon_resource := load(icon_path)
	if icon_resource is Texture2D:
		return icon_resource as Texture2D
	return null


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel_node := PanelContainer.new()
	panel_node.set_anchors_preset(
		Control.PRESET_CENTER_RIGHT
	)
	panel_node.offset_left = -430
	panel_node.offset_top = -225
	panel_node.offset_right = -35
	panel_node.offset_bottom = 225
	panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel_node)
	GameUIStyle.apply_panel(panel_node, "raised")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel_node.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var preview_card := PanelContainer.new()
	preview_card.custom_minimum_size = Vector2(86, 70)
	GameUIStyle.apply_panel(preview_card, "context_preview")
	header.add_child(preview_card)

	building_image = TextureRect.new()
	building_image.custom_minimum_size = Vector2(82, 66)
	building_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	building_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	building_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview_card.add_child(building_image)

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
	current_stats_label.custom_minimum_size = Vector2(0, 120)
	current_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_stats_label.add_theme_font_size_override("font_size", 13)
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
	next_stats_label.custom_minimum_size = Vector2(0, 120)
	next_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_stats_label.add_theme_font_size_override("font_size", 13)
	next_card.add_child(next_stats_label)

	stats_label = current_stats_label

	var note := Label.new()
	note.text = (
		"Internal upgrades improve speed and fleet capacity only. "
		+ "The building keeps the same visual."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	GameUIStyle.muted(note)
	column.add_child(note)

	cost_label = Label.new()
	cost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", 13)
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
