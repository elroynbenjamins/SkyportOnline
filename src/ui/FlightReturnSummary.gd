class_name FlightReturnSummary
extends CanvasLayer

var root: Control
var reward_panel: PanelContainer
var result_badge_label: Label
var title_label: Label
var coin_tile_label: Label
var xp_tile_label: Label
var mastery_tile_label: Label
var body_label: Label
var resource_reward_row: HBoxContainer
var collect_button: Button
var reveal_tween: Tween
var queue: Array[Dictionary] = []


func _ready() -> void:
	layer = 40
	_build_ui()
	root.visible = false


func show_reward(
	flight_label: String,
	reward: Dictionary,
	resource_inventory: Dictionary
) -> void:
	queue.append({
		"flight_label": flight_label,
		"reward": reward.duplicate(true),
		"resource_inventory": resource_inventory.duplicate(true)
	})
	if not root.visible:
		_show_next()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("020b10", 0.68)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	reward_panel = PanelContainer.new()
	reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	reward_panel.offset_left = -270
	reward_panel.offset_top = -255
	reward_panel.offset_right = 290
	reward_panel.offset_bottom = 255
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(reward_panel)
	GameUIStyle.apply_panel(reward_panel, "gold")

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 10)
	reward_panel.add_child(wrapper)

	result_badge_label = Label.new()
	result_badge_label.text = "✓  FLIGHT COMPLETE"
	result_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_badge_label.add_theme_font_size_override("font_size", 13)
	result_badge_label.add_theme_color_override("font_color", GameUIStyle.COLOR_SUCCESS)
	wrapper.add_child(result_badge_label)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(title_label, 23)
	title_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	wrapper.add_child(title_label)

	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(reward_row)

	coin_tile_label = _make_reward_tile(
		reward_row,
		"COINS",
		GameUIStyle.COLOR_GOLD
	)
	xp_tile_label = _make_reward_tile(
		reward_row,
		"XP",
		GameUIStyle.COLOR_ACCENT
	)
	mastery_tile_label = _make_reward_tile(
		reward_row,
		"MASTERY",
		Color("d8b9ff")
	)

	var cargo_heading := Label.new()
	cargo_heading.text = "COUNTRY CARGO"
	cargo_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo_heading.add_theme_font_size_override("font_size", 12)
	cargo_heading.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	wrapper.add_child(cargo_heading)

	resource_reward_row = HBoxContainer.new()
	resource_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_reward_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(resource_reward_row)

	body_label = Label.new()
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_TEXT
	)
	wrapper.add_child(body_label)

	collect_button = Button.new()
	collect_button.text = "COLLECT & CONTINUE"
	collect_button.custom_minimum_size = Vector2(0, 54)
	collect_button.add_theme_font_size_override("font_size", 17)
	collect_button.pressed.connect(_on_close_pressed)
	GameUIStyle.apply_button(collect_button, "gold")
	wrapper.add_child(collect_button)


func _show_next() -> void:
	if queue.is_empty():
		root.visible = false
		return

	var item: Dictionary = queue.pop_front()
	var reward: Dictionary = item["reward"]
	var inventory: Dictionary = item["resource_inventory"]
	var flight_label := String(item["flight_label"])

	title_label.text = "%s RETURNED FROM %s" % [
		flight_label,
		String(reward.get("city", "FLIGHT")).to_upper()
	]

	coin_tile_label.text = "COINS\n+%d" % int(
		reward.get("coins", 0)
	)
	xp_tile_label.text = "XP\n+%d" % int(
		reward.get("xp", 0)
	)

	var text := "Regional resource chance: %.1f%% each\n" % (
		float(reward.get("resource_chance", 0.0)) * 100.0
	)

	if reward.has("mastery_hours_after"):
		var mastery_stars := int(
			reward.get("mastery_stars_after", 0)
		)
		mastery_tile_label.text = "MASTERY\n%s" % (
			AircraftMastery.format_stars(mastery_stars)
		)
		text += "%.1f total flight hours" % float(
			reward.get("mastery_hours_after", 0.0)
		)
		if bool(reward.get("mastery_star_up", false)):
			text += "  •  ★ NEW STAR!"
			mastery_tile_label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_GOLD
			)
		else:
			mastery_tile_label.add_theme_color_override(
				"font_color",
				Color("d8b9ff")
			)
		text += "\n"
	else:
		mastery_tile_label.text = "MASTERY\n—"

	text += "\n"

	var contract_bonus: Dictionary = reward.get(
		"priority_contract_bonus",
		{}
	)
	if not contract_bonus.is_empty():
		result_badge_label.text = "★  PRIORITY CONTRACT COMPLETE"
		result_badge_label.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	elif bool(reward.get("mastery_star_up", false)):
		result_badge_label.text = "★  MASTERY STAR EARNED"
		result_badge_label.add_theme_color_override("font_color", Color("d8b9ff"))
	else:
		result_badge_label.text = "✓  FLIGHT COMPLETE"
		result_badge_label.add_theme_color_override("font_color", GameUIStyle.COLOR_SUCCESS)
	if not contract_bonus.is_empty():
		text += "★ PRIORITY CONTRACT COMPLETE!\n"
		text += "Bonus: 🪙 +%d    XP +%d\n" % [
			int(contract_bonus.get("coins", 0)),
			int(contract_bonus.get("xp", 0))
		]
		var contract_resources: Array = contract_bonus.get(
			"resources",
			[]
		)
		if not contract_resources.is_empty():
			text += "Bundle: %s\n" % (
				RouteContractRules.format_resource_bundle(
					contract_resources
				)
			)
		text += "\n"

	var rolls: Array = reward.get("resource_rolls", [])
	_refresh_resource_reward_icons(rolls, inventory)
	for result in rolls:
		var resource_id := String(result.get("id", ""))
		var resource_name := String(result.get("name", "Resource"))
		var success := bool(result.get("success", false))
		var owned := int(inventory.get(resource_id, 0))
		text += "%s %s" % [
			"✓" if success else "✕",
			resource_name
		]
		if success:
			text += "  +1  •  Owned %d" % owned
		text += "\n"

	if rolls.is_empty():
		text += "No regional resources configured for this destination.\n"

	body_label.text = text
	if collect_button != null:
		collect_button.text = (
			"COLLECT & NEXT  •  %d QUEUED" % queue.size()
			if not queue.is_empty()
			else "COLLECT & CONTINUE"
		)
	root.visible = true
	_animate_reward_panel()



func _refresh_resource_reward_icons(
	rolls: Array,
	inventory: Dictionary
) -> void:
	if resource_reward_row == null:
		return
	for child in resource_reward_row.get_children():
		child.queue_free()

	for result in rolls:
		var resource_id := String(result.get("id", ""))
		if resource_id.is_empty():
			continue

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(150, 86)
		GameUIStyle.apply_panel(card, "reward_tile")
		card.modulate = Color(1, 1, 1, 1.0 if bool(result.get("success", false)) else 0.48)
		resource_reward_row.add_child(card)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CountryResourceVisuals.texture_for(resource_id)
		row.add_child(icon)

		var label := Label.new()
		label.custom_minimum_size = Vector2(78, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s\n%s" % [
			String(result.get("name", "Resource")),
			"+1 • %d owned" % int(inventory.get(resource_id, 0))
			if bool(result.get("success", false))
			else "Not found"
		]
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)


func _animate_reward_panel() -> void:
	if reward_panel == null:
		return
	if reveal_tween != null and reveal_tween.is_valid():
		reveal_tween.kill()
	reward_panel.pivot_offset = reward_panel.size * 0.5
	reward_panel.scale = Vector2(0.94, 0.94)
	reward_panel.modulate.a = 0.0
	reveal_tween = create_tween()
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(
		reward_panel,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(
		reward_panel,
		"modulate:a",
		1.0,
		0.12
	)


func _make_reward_tile(
	parent: HBoxContainer,
	title: String,
	color: Color
) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 68)
	GameUIStyle.apply_panel(card, "reward_tile")
	parent.add_child(card)

	var label := Label.new()
	label.text = title + "\n—"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)
	return label


func _on_close_pressed() -> void:
	if queue.is_empty():
		root.visible = false
	else:
		_show_next()
