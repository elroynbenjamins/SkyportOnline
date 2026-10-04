class_name FlightReturnSummary
extends CanvasLayer

var root: Control
var title_label: Label
var body_label: Label
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

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_top = -190
	panel.offset_right = 260
	panel.offset_bottom = 190
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 12)
	panel.add_child(wrapper)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 23)
	wrapper.add_child(title_label)

	body_label = Label.new()
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 16)
	wrapper.add_child(body_label)

	var close_button := Button.new()
	close_button.text = "COLLECT"
	close_button.custom_minimum_size = Vector2(0, 52)
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.pressed.connect(_on_close_pressed)
	wrapper.add_child(close_button)


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

	var text := "🪙 +%d    XP +%d\n" % [
		int(reward.get("coins", 0)),
		int(reward.get("xp", 0))
	]
	text += "Country resource chance: %.1f%% each\n" % (
		float(reward.get("resource_chance", 0.0)) * 100.0
	)

	if reward.has("mastery_hours_after"):
		var mastery_stars := int(
			reward.get("mastery_stars_after", 0)
		)
		text += "Mastery: %s • %.1f flight hours\n" % [
			AircraftMastery.format_stars(mastery_stars),
			float(reward.get("mastery_hours_after", 0.0))
		]
		if bool(reward.get("mastery_star_up", false)):
			text += "★ NEW MASTERY STAR UNLOCKED!\n"

	text += "\n"

	var rolls: Array = reward.get("resource_rolls", [])
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
	root.visible = true


func _on_close_pressed() -> void:
	if queue.is_empty():
		root.visible = false
	else:
		_show_next()
