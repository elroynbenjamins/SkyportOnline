class_name BuildingContextCard
extends CanvasLayer

signal primary_action_requested(building: Dictionary)
signal details_requested(building: Dictionary)

var root: Control
var panel: PanelContainer
var building_image: TextureRect
var title_label: Label
var role_label: Label
var status_label: Label
var stat_one_label: Label
var stat_two_label: Label
var description_label: Label
var primary_button: Button
var details_button: Button

var selected_building: Dictionary = {}
var current_summary: Dictionary = {}


func _ready() -> void:
	layer = 23
	_build_ui()
	root.visible = false


func show_building(
	building: Dictionary,
	summary: Dictionary
) -> void:
	if building.is_empty():
		return

	selected_building = building.duplicate(true)
	current_summary = summary.duplicate(true)
	_refresh()
	root.visible = true


func close_card() -> void:
	root.visible = false
	selected_building = {}
	current_summary = {}


func is_open() -> bool:
	return root != null and root.visible and not selected_building.is_empty()


func refresh_summary(summary: Dictionary) -> void:
	current_summary = summary.duplicate(true)
	if is_open():
		_refresh()


func get_selected_building_uid() -> int:
	return int(selected_building.get("uid", -1))


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 14
	panel.offset_top = -326
	panel.offset_right = 440
	panel.offset_bottom = -84
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "raised")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var preview_card := PanelContainer.new()
	preview_card.custom_minimum_size = Vector2(112, 82)
	GameUIStyle.apply_panel(preview_card, "dark")
	header.add_child(preview_card)

	building_image = TextureRect.new()
	building_image.custom_minimum_size = Vector2(108, 78)
	building_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	building_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	building_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_card.add_child(building_image)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_text)

	title_label = Label.new()
	GameUIStyle.heading(title_label, 18)
	header_text.add_child(title_label)

	role_label = Label.new()
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	header_text.add_child(role_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	header_text.add_child(status_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 42)
	GameUIStyle.apply_button(close_button, "secondary", true)
	close_button.pressed.connect(close_card)
	header.add_child(close_button)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	column.add_child(stat_row)

	stat_one_label = _make_stat_card(
		stat_row,
		GameUIStyle.COLOR_GOLD
	)
	stat_two_label = _make_stat_card(
		stat_row,
		GameUIStyle.COLOR_SUCCESS
	)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(description_label)
	column.add_child(description_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	primary_button = Button.new()
	primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_button.custom_minimum_size = Vector2(0, 46)
	GameUIStyle.apply_button(primary_button, "primary")
	primary_button.pressed.connect(_on_primary_pressed)
	actions.add_child(primary_button)

	details_button = Button.new()
	details_button.text = "DETAILS"
	details_button.custom_minimum_size = Vector2(100, 46)
	GameUIStyle.apply_button(details_button, "secondary", true)
	details_button.pressed.connect(_on_details_pressed)
	actions.add_child(details_button)


func _refresh() -> void:
	var definition := BuildingCatalog.get_definition(
		String(selected_building.get("definition_id", ""))
	)
	if definition.is_empty():
		return

	var level := int(selected_building.get("upgrade_level", 1))
	title_label.text = "%s  •  LV %d" % [
		String(definition.get("name", "Airport Building")),
		level
	]
	role_label.text = String(
		current_summary.get(
			"role",
			definition.get("category", "Airport")
		)
	).to_upper()

	status_label.text = String(
		current_summary.get("status", "Operational")
	)
	_apply_status_tone(
		String(current_summary.get("tone", "normal"))
	)

	stat_one_label.text = String(
		current_summary.get("stat_one", "STATUS\n—")
	)
	stat_two_label.text = String(
		current_summary.get("stat_two", "CAPACITY\n—")
	)

	description_label.text = String(
		current_summary.get(
			"description",
			definition.get("description", "")
		)
	)

	var action_label := String(
		current_summary.get("primary_label", "")
	)
	primary_button.visible = not action_label.is_empty()
	primary_button.text = action_label
	if primary_button.visible:
		GameUIStyle.apply_button(
			primary_button,
			String(
				current_summary.get(
					"primary_kind",
					"primary"
				)
			)
		)

	var show_details := bool(
		current_summary.get("show_details", false)
	)
	details_button.visible = show_details

	building_image.texture = _building_texture(definition)


func _make_stat_card(
	parent: HBoxContainer,
	color: Color
) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 58)
	GameUIStyle.apply_panel(card, "dark")
	parent.add_child(card)

	var label := Label.new()
	label.text = "—"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)
	return label


func _apply_status_tone(tone: String) -> void:
	var color := GameUIStyle.COLOR_TEXT
	match tone:
		"success":
			color = GameUIStyle.COLOR_SUCCESS
		"warning":
			color = GameUIStyle.COLOR_WARNING
		"danger":
			color = GameUIStyle.COLOR_DANGER
		"event":
			color = GameUIStyle.COLOR_EVENT
		_:
			color = GameUIStyle.COLOR_TEXT

	status_label.add_theme_color_override(
		"font_color",
		color
	)


func _building_texture(
	definition: Dictionary
) -> Texture2D:
	var path := String(definition.get("icon_path", ""))
	if path.is_empty():
		var variants: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		if not variants.is_empty():
			path = variants[0]

	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var resource := load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _on_primary_pressed() -> void:
	if not selected_building.is_empty():
		primary_action_requested.emit(
			selected_building.duplicate(true)
		)


func _on_details_pressed() -> void:
	if not selected_building.is_empty():
		details_requested.emit(
			selected_building.duplicate(true)
		)
