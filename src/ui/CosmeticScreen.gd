class_name CosmeticScreen
extends CanvasLayer

signal equip_requested(slot: String, cosmetic_id: String)

var root: Control
var slot_lists: Dictionary = {}
var equipped: Dictionary = {}
var owned: Dictionary = {}


func _ready() -> void:
	layer = 44
	_build_ui()
	root.visible = false


func open_customization(
	owned_cosmetics: Dictionary,
	equipped_cosmetics: Dictionary
) -> void:
	owned = owned_cosmetics.duplicate(true)
	equipped = equipped_cosmetics.duplicate(true)
	_refresh()
	root.visible = true


func close_customization() -> void:
	root.visible = false


func refresh(
	owned_cosmetics: Dictionary,
	equipped_cosmetics: Dictionary
) -> void:
	owned = owned_cosmetics.duplicate(true)
	equipped = equipped_cosmetics.duplicate(true)
	if root != null:
		_refresh()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("071923", 0.98)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 56
	panel.offset_top = 38
	panel.offset_right = -56
	panel.offset_bottom = -38
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := Label.new()
	title.text = "CUSTOMIZE AIRPORT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "✕  CLOSE"
	close_button.custom_minimum_size = Vector2(120, 42)
	close_button.pressed.connect(close_customization)
	header.add_child(close_button)

	var hint := Label.new()
	hint.text = (
		"Event cosmetics remain permanently unlocked. "
		+ "Equip one item per cosmetic slot."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("a9c6cf"))
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	for slot in CosmeticCatalog.slots():
		var card := PanelContainer.new()
		content.add_child(card)

		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 6)
		card.add_child(card_box)

		var slot_title := Label.new()
		slot_title.text = CosmeticCatalog.slot_name(slot).to_upper()
		slot_title.add_theme_font_size_override("font_size", 17)
		card_box.add_child(slot_title)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card_box.add_child(row)

		slot_lists[slot] = row


func _refresh() -> void:
	for slot in CosmeticCatalog.slots():
		if not slot_lists.has(slot):
			continue
		var row: HBoxContainer = slot_lists[slot]
		for child in row.get_children():
			child.queue_free()

		var equipped_id := String(equipped.get(slot, ""))

		var default_button := Button.new()
		default_button.text = (
			"✓ DEFAULT" if equipped_id.is_empty() else "DEFAULT"
		)
		default_button.custom_minimum_size = Vector2(150, 54)
		default_button.pressed.connect(
			func() -> void:
				equip_requested.emit(slot, "")
		)
		row.add_child(default_button)

		var any_owned := false
		for cosmetic in CosmeticCatalog.for_slot(slot):
			var cosmetic_id := String(cosmetic.get("id", ""))
			if not bool(owned.get(cosmetic_id, false)):
				continue
			any_owned = true

			var button := Button.new()
			var active := equipped_id == cosmetic_id
			button.text = "%s%s" % [
				"✓ " if active else "",
				String(cosmetic.get("name", "Cosmetic"))
			]
			button.custom_minimum_size = Vector2(205, 54)
			button.tooltip_text = (
				"Equipped" if active else "Tap to equip"
			)
			button.pressed.connect(
				func() -> void:
					equip_requested.emit(slot, cosmetic_id)
			)
			row.add_child(button)

		if not any_owned:
			var locked := Label.new()
			locked.text = "No unlocked cosmetics for this slot yet."
			locked.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			locked.add_theme_color_override(
				"font_color",
				Color("77919a")
			)
			row.add_child(locked)
