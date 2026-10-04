class_name EventScreen
extends CanvasLayer

signal close_requested
signal quest_claim_requested(quest_id: String)
signal shop_purchase_requested(item_id: String)
signal alliance_claim_requested(milestone_id: String)

var root: Control
var title_label: Label
var timing_label: Label
var currency_label: Label
var quest_list: VBoxContainer
var shop_list: VBoxContainer
var alliance_list: VBoxContainer
var empty_label: Label


func _ready() -> void:
	layer = 42
	_build_ui()
	root.visible = false


func open_event(snapshot: Dictionary) -> void:
	refresh(snapshot)
	root.visible = true


func close_event() -> void:
	root.visible = false
	close_requested.emit()


func is_open() -> bool:
	return root != null and root.visible


func refresh(snapshot: Dictionary) -> void:
	if root == null:
		return

	var active := bool(snapshot.get("active", false))
	empty_label.visible = not active
	if not active:
		title_label.text = "EVENTS"
		timing_label.text = "No event is active."
		currency_label.text = ""
		_clear(quest_list)
		_clear(shop_list)
		_clear(alliance_list)
		return

	title_label.text = String(
		snapshot.get("name", "Event")
	).to_upper()
	timing_label.text = "WEEK %d / 3  •  %d DAYS REMAINING" % [
		int(snapshot.get("week", 1)),
		int(snapshot.get("days_remaining", 0))
	]
	currency_label.text = "🎟 %d  %s" % [
		int(snapshot.get("currency", 0)),
		String(snapshot.get("currency_name", "Event Currency"))
	]

	_refresh_quests(snapshot)
	_refresh_shop(snapshot)
	_refresh_alliance(snapshot)


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
	panel.offset_left = 36
	panel.offset_top = 34
	panel.offset_right = -36
	panel.offset_bottom = -34
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)

	title_label = Label.new()
	title_label.text = "EVENTS"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(title_label)

	timing_label = Label.new()
	timing_label.text = "No event is active."
	timing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_label.add_theme_font_size_override("font_size", 14)
	header.add_child(timing_label)

	currency_label = Label.new()
	currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	currency_label.add_theme_font_size_override("font_size", 16)
	currency_label.add_theme_color_override(
		"font_color",
		Color("f1d27a")
	)
	header.add_child(currency_label)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(130, 42)
	close_button.pressed.connect(close_event)
	header.add_child(close_button)

	empty_label = Label.new()
	empty_label.text = (
		"No seasonal event is active right now.\n"
		+ "Events can be enabled or disabled from EventCatalog."
	)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_label.add_theme_font_size_override("font_size", 20)
	column.add_child(empty_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	column.add_child(columns)

	quest_list = _build_column(columns, "EVENT QUESTS")
	shop_list = _build_column(columns, "EVENT SHOP")
	alliance_list = _build_column(columns, "ALLIANCE EVENT")


func _build_column(
	parent: HBoxContainer,
	heading_text: String
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	wrapper.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrapper.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	return list


func _refresh_quests(snapshot: Dictionary) -> void:
	_clear(quest_list)

	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		var button := Button.new()
		var quest_id := String(quest.get("id", ""))
		var unlocked := bool(quest.get("unlocked", false))
		var complete := bool(quest.get("complete", false))
		var claimed := bool(quest.get("claimed", false))
		var week := int(quest.get("week", 1))
		var progress := int(quest.get("progress", 0))
		var target := int(quest.get("target", 0))
		var reward := int(quest.get("currency_reward", 0))
		var alliance_points := int(
			quest.get("alliance_points", 0)
		)

		var state_text := "CLAIM"
		if claimed:
			state_text = "CLAIMED"
		elif not unlocked:
			state_text = "LOCKED • WEEK %d" % week
		elif not complete:
			state_text = "%d / %d" % [progress, target]

		button.text = (
			"W%d • %s\n"
			+ "%s  •  +%d 🎟  •  +%d Alliance"
		) % [
			week,
			String(quest.get("title", "Event Quest")),
			state_text,
			reward,
			alliance_points
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 62)
		button.disabled = (
			claimed
			or not unlocked
			or not complete
		)
		button.pressed.connect(
			func() -> void:
				quest_claim_requested.emit(quest_id)
		)
		quest_list.add_child(button)


func _refresh_shop(snapshot: Dictionary) -> void:
	_clear(shop_list)

	for item_variant in snapshot.get("shop", []):
		var item: Dictionary = item_variant
		var button := Button.new()
		var item_id := String(item.get("id", ""))
		var item_type := String(item.get("type", ""))
		var remaining := int(item.get("remaining", 0))
		var sold_out := bool(item.get("sold_out", false))
		var can_afford := bool(item.get("can_afford", false))
		var owned := bool(item.get("owned", false))
		var reward_text := "COSMETIC"
		if item_type == "passengers":
			reward_text = "+%d PASSENGERS" % int(
				item.get("passengers", 0)
			)

		var limit_text := "%d LEFT" % remaining
		if sold_out or owned:
			limit_text = "OWNED / SOLD OUT"

		button.text = "%s\n%s  •  %d 🎟  •  %s" % [
			String(item.get("name", "Event Item")),
			reward_text,
			int(item.get("price", 0)),
			limit_text
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 62)
		button.disabled = sold_out or owned or not can_afford
		button.pressed.connect(
			func() -> void:
				shop_purchase_requested.emit(item_id)
		)
		shop_list.add_child(button)


func _refresh_alliance(snapshot: Dictionary) -> void:
	_clear(alliance_list)

	if not bool(snapshot.get("alliance_enabled", false)):
		var disabled := Label.new()
		disabled.text = "No Alliance challenge for this event."
		disabled.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		alliance_list.add_child(disabled)
		return

	var status := Label.new()
	status.text = (
		"Alliance total: %d\n"
		+ "Your contribution: %d\n"
		+ "Quest claims add Alliance points. "
		+ "Server sync can replace the cached total later."
	) % [
		int(snapshot.get("alliance_total", 0)),
		int(snapshot.get("alliance_personal", 0))
	]
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	alliance_list.add_child(status)

	for milestone_variant in snapshot.get(
		"alliance_milestones",
		[]
	):
		var milestone: Dictionary = milestone_variant
		var button := Button.new()
		var milestone_id := String(
			milestone.get("id", "")
		)
		var claimed := bool(milestone.get("claimed", false))
		var reached := bool(milestone.get("reached", false))
		var reward_text := "EVENT REWARD"
		if String(milestone.get("reward_type", "")) == "currency":
			reward_text = "+%d 🎟" % int(
				milestone.get("currency_reward", 0)
			)
		elif String(
			milestone.get("reward_type", "")
		) == "cosmetic":
			reward_text = "ALLIANCE COSMETIC"

		button.text = "%s\n%d POINTS  •  %s" % [
			String(milestone.get("name", "Alliance Milestone")),
			int(milestone.get("target", 0)),
			"CLAIMED" if claimed else reward_text
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 58)
		button.disabled = claimed or not reached
		button.pressed.connect(
			func() -> void:
				alliance_claim_requested.emit(milestone_id)
		)
		alliance_list.add_child(button)


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
