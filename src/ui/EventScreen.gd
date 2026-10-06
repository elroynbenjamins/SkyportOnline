class_name EventScreen
extends CanvasLayer

signal close_requested
signal quest_claim_requested(quest_id: String)
signal shop_purchase_requested(item_id: String)
signal shop_resource_choice_requested(item_id: String, resource_id: String)
signal alliance_claim_requested(milestone_id: String)

var root: Control
var title_label: Label
var timing_label: Label
var currency_label: Label
var phase_label: Label
var phase_progress_label: Label
var featured_routes_label: Label
var quest_list: VBoxContainer
var shop_list: VBoxContainer
var alliance_list: VBoxContainer
var empty_label: Label
var resource_choice_overlay: Control
var resource_choice_list: VBoxContainer
var resource_choice_title: Label
var pending_resource_item_id := ""
var current_resource_inventory: Dictionary = {}


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
	current_resource_inventory = (
		snapshot.get("resource_inventory", {}) as Dictionary
	).duplicate(true)
	empty_label.visible = not active
	if not active:
		title_label.text = "EVENTS"
		timing_label.text = "No event is active."
		currency_label.text = ""
		featured_routes_label.text = ""
		_clear(quest_list)
		_clear(shop_list)
		_clear(alliance_list)
		return

	title_label.text = String(
		snapshot.get("name", "Event")
	).to_upper()
	timing_label.text = "PHASE %d / 3  •  %d DAYS REMAINING" % [
		int(snapshot.get("week", 1)),
		int(snapshot.get("days_remaining", 0))
	]
	phase_label.text = "%s\n%s" % [
		String(snapshot.get("phase_name", "Event Phase")).to_upper(),
		String(snapshot.get("phase_description", ""))
	]
	phase_progress_label.text = "%d / %d PHASE QUESTS COMPLETE%s" % [
		int(snapshot.get("phase_quest_complete", 0)),
		maxi(int(snapshot.get("phase_quest_total", 0)), 1),
		(
			"  •  NEXT: %s" % String(snapshot.get("next_phase_name", "")).to_upper()
			if not String(snapshot.get("next_phase_name", "")).is_empty()
			else "  •  FINAL PHASE"
		)
	]
	currency_label.text = "🎟 %d  %s" % [
		int(snapshot.get("currency", 0)),
		String(snapshot.get("currency_name", "Event Currency"))
	]

	var featured_ids: Array = snapshot.get(
		"phase_featured_destinations",
		[]
	)
	var featured_names: Array[String] = []
	for destination_id in featured_ids:
		var destination := DestinationCatalog.get_destination(
			String(destination_id)
		)
		if not destination.is_empty():
			featured_names.append(
				String(destination.get("city", destination_id))
			)

	if featured_names.is_empty():
		featured_routes_label.text = ""
	else:
		var route_currency := int(
			snapshot.get("featured_route_currency", 0)
		)
		if route_currency > 0:
			featured_routes_label.text = (
				"FEATURED ROUTES  •  %s  •  +%d %s per completed return"
				% [
					" • ".join(featured_names),
					route_currency,
					String(
						snapshot.get(
							"currency_name",
							"Event Currency"
						)
					)
				]
			)
		else:
			featured_routes_label.text = (
				"FEATURED WINTER QUEST ROUTES  •  %s"
				% " • ".join(featured_names)
			)

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
	backdrop.color = Color("07151d", 0.975)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36
	panel.offset_top = 34
	panel.offset_right = -36
	panel.offset_bottom = -34
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "event")

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
	GameUIStyle.heading(title_label, 24)
	title_label.add_theme_color_override(
		"font_color",
		Color("ffd08a")
	)
	header.add_child(title_label)

	timing_label = Label.new()
	timing_label.text = "No event is active."
	timing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_label.add_theme_font_size_override("font_size", 14)
	GameUIStyle.muted(timing_label)
	header.add_child(timing_label)

	currency_label = Label.new()
	currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	currency_label.add_theme_font_size_override("font_size", 16)
	currency_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	header.add_child(currency_label)


	var phase_panel := PanelContainer.new()
	GameUIStyle.apply_panel(phase_panel, "dark")
	column.add_child(phase_panel)

	var phase_box := VBoxContainer.new()
	phase_box.add_theme_constant_override("separation", 3)
	phase_panel.add_child(phase_box)

	phase_label = Label.new()
	phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label.add_theme_font_size_override("font_size", 15)
	phase_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	phase_box.add_child(phase_label)

	phase_progress_label = Label.new()
	phase_progress_label.add_theme_font_size_override("font_size", 11)
	GameUIStyle.muted(phase_progress_label)
	phase_box.add_child(phase_progress_label)

	featured_routes_label = Label.new()
	featured_routes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	featured_routes_label.add_theme_font_size_override("font_size", 13)
	featured_routes_label.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_SUCCESS
	)
	column.add_child(featured_routes_label)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(130, 42)
	close_button.pressed.connect(close_event)
	GameUIStyle.apply_button(close_button, "secondary", true)
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
	GameUIStyle.muted(empty_label)
	column.add_child(empty_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	column.add_child(columns)

	quest_list = _build_column(columns, "EVENT QUESTS")
	shop_list = _build_column(columns, "EVENT SHOP")
	alliance_list = _build_column(columns, "ALLIANCE EVENT")

	_build_resource_choice_overlay()


func _build_column(
	parent: HBoxContainer,
	heading_text: String
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	GameUIStyle.apply_panel(panel, "dark")

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 16)
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

	var current: Array[Dictionary] = []
	var archive: Array[Dictionary] = []
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		match String(quest.get("phase_state", "current")):
			"current":
				current.append(quest)
			"archive":
				archive.append(quest)

	_add_quest_section("CURRENT PHASE", current)
	if not archive.is_empty():
		_add_quest_section("EARLIER PHASES", archive)


func _add_quest_section(
	heading_text: String,
	quests: Array[Dictionary]
) -> void:
	if quests.is_empty():
		return

	var section := Label.new()
	section.text = heading_text
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_font_size_override("font_size", 11)
	section.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_ACCENT
	)
	quest_list.add_child(section)

	for quest in quests:
		var quest_id := String(quest.get("id", ""))
		var unlocked := bool(quest.get("unlocked", false))
		var complete := bool(quest.get("complete", false))
		var claimed := bool(quest.get("claimed", false))
		var week := int(quest.get("week", 1))
		var progress := int(quest.get("progress", 0))
		var target := maxi(int(quest.get("target", 0)), 1)
		var reward := int(quest.get("currency_reward", 0))
		var alliance_points := int(
			quest.get("alliance_points", 0)
		)

		var card := PanelContainer.new()
		GameUIStyle.apply_panel(
			card,
			"gold" if complete and not claimed else "dark"
		)
		quest_list.add_child(card)

		var wrapper := VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", 6)
		card.add_child(wrapper)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		wrapper.add_child(header)

		var title := Label.new()
		title.text = "W%d • %s" % [
			week,
			String(quest.get("title", "Event Quest"))
		]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_TEXT
		)
		header.add_child(title)

		var reward_chip := Label.new()
		reward_chip.text = "+%d 🎟  •  +%d Alliance" % [
			reward,
			alliance_points
		]
		reward_chip.add_theme_font_size_override("font_size", 12)
		reward_chip.add_theme_color_override(
			"font_color",
			GameUIStyle.COLOR_GOLD
		)
		header.add_child(reward_chip)

		var progress_bar := ProgressBar.new()
		progress_bar.min_value = 0.0
		progress_bar.max_value = float(target)
		progress_bar.value = float(mini(progress, target))
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size = Vector2(0, 16)
		GameUIStyle.apply_progress(progress_bar, complete)
		wrapper.add_child(progress_bar)

		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 8)
		wrapper.add_child(footer)

		var progress_label := Label.new()
		progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_label.add_theme_font_size_override("font_size", 12)
		if claimed:
			progress_label.text = "✓ CLAIMED"
			progress_label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_SUCCESS
			)
		elif not unlocked:
			progress_label.text = "🔒 Unlocks in Week %d" % week
			progress_label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_MUTED
			)
		elif complete:
			progress_label.text = "%d / %d • READY" % [
				target,
				target
			]
			progress_label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_GOLD
			)
		else:
			progress_label.text = "%d / %d" % [
				progress,
				target
			]
			progress_label.add_theme_color_override(
				"font_color",
				GameUIStyle.COLOR_MUTED
			)
		footer.add_child(progress_label)

		var claim_button := Button.new()
		claim_button.custom_minimum_size = Vector2(96, 34)
		claim_button.text = (
			"CLAIM"
			if complete and not claimed and unlocked
			else "✓" if claimed
			else "LOCKED" if not unlocked
			else "IN PROGRESS"
		)
		claim_button.disabled = (
			claimed
			or not unlocked
			or not complete
		)
		GameUIStyle.apply_button(
			claim_button,
			"gold"
			if complete and not claimed and unlocked
			else "secondary",
			true
		)
		claim_button.pressed.connect(
			func() -> void:
				quest_claim_requested.emit(quest_id)
		)
		footer.add_child(claim_button)


func _refresh_shop(snapshot: Dictionary) -> void:
	_clear(shop_list)

	var last_category := ""
	for item_variant in snapshot.get("shop", []):
		var item: Dictionary = item_variant
		var button := Button.new()
		var item_id := String(item.get("id", ""))
		var item_type := String(item.get("type", ""))
		var category := _shop_category_name(item_type)
		if category != last_category:
			_add_shop_category_header(category)
			last_category = category

		var remaining := int(item.get("remaining", 0))
		var sold_out := bool(item.get("sold_out", false))
		var can_afford := bool(item.get("can_afford", false))
		var owned := bool(item.get("owned", false))
		var reward_text := "COSMETIC"
		match item_type:
			"passengers":
				reward_text = "+%d PASSENGERS" % int(
					item.get("passengers", 0)
				)
			"coins":
				reward_text = "+%d COINS" % int(
					item.get("coins", 0)
				)
			"resource_choice":
				reward_text = "CHOOSE 1 COUNTRY RESOURCE"

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
		var shop_kind := "event" if can_afford and not sold_out and not owned else "secondary"
		if owned:
			shop_kind = "selected"
		GameUIStyle.apply_button(button, shop_kind, true)
		button.pressed.connect(
			func() -> void:
				if item_type == "resource_choice":
					_open_resource_choice(item)
				else:
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
	GameUIStyle.muted(status)
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
		var milestone_kind := "gold" if reached and not claimed else "secondary"
		if claimed:
			milestone_kind = "selected"
		GameUIStyle.apply_button(button, milestone_kind, true)
		button.pressed.connect(
			func() -> void:
				alliance_claim_requested.emit(milestone_id)
		)
		alliance_list.add_child(button)


func _build_resource_choice_overlay() -> void:
	resource_choice_overlay = ColorRect.new()
	resource_choice_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	resource_choice_overlay.color = Color("061017", 0.96)
	resource_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	resource_choice_overlay.z_index = 120
	resource_choice_overlay.visible = false
	root.add_child(resource_choice_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 130
	panel.offset_top = 70
	panel.offset_right = -130
	panel.offset_bottom = -70
	resource_choice_overlay.add_child(panel)
	GameUIStyle.apply_panel(panel, "event")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	resource_choice_title = Label.new()
	resource_choice_title.text = "WINTER SUPPLY CRATE"
	resource_choice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(resource_choice_title, 20)
	header.add_child(resource_choice_title)

	var close_button := Button.new()
	close_button.text = "✕  CANCEL"
	close_button.custom_minimum_size = Vector2(120, 40)
	GameUIStyle.apply_button(close_button, "secondary", true)
	close_button.pressed.connect(_close_resource_choice)
	header.add_child(close_button)

	var hint := Label.new()
	hint.text = (
		"Choose one country resource. "
		+ "The event voucher cost is spent only after you choose."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.muted(hint)
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	resource_choice_list = VBoxContainer.new()
	resource_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_choice_list.add_theme_constant_override("separation", 6)
	scroll.add_child(resource_choice_list)


func _open_resource_choice(item: Dictionary) -> void:
	if resource_choice_overlay == null:
		return

	pending_resource_item_id = String(item.get("id", ""))
	resource_choice_title.text = String(
		item.get("name", "Winter Supply Crate")
	).to_upper()
	_clear(resource_choice_list)

	var allowed_codes: Array = item.get(
		"resource_country_codes",
		[]
	)
	for code_variant in allowed_codes:
		var country_code := String(code_variant)
		var country := CountryCatalog.get_country(country_code)
		if country.is_empty():
			continue

		var country_label := Label.new()
		country_label.text = String(
			country.get("name", country_code)
		).to_upper()
		GameUIStyle.heading(country_label, 14)
		resource_choice_list.add_child(country_label)

		for resource in CountryResourceCatalog.resources_for_country(
			country_code
		):
			var resource_id := String(resource.get("id", ""))
			if resource_id.is_empty():
				continue
			var selected_resource_id := resource_id
			var button := Button.new()
			var owned_amount := int(
				current_resource_inventory.get(
					resource_id,
					0
				)
			)
			button.text = "%s  •  Owned %d" % [
				String(
					resource.get(
						"name",
						resource_id
					)
				),
				owned_amount
			]
			button.custom_minimum_size = Vector2(0, 44)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			GameUIStyle.apply_button(button, "secondary", true)
			button.pressed.connect(
				func() -> void:
					var item_id := pending_resource_item_id
					_close_resource_choice()
					shop_resource_choice_requested.emit(
						item_id,
						selected_resource_id
					)
			)
			resource_choice_list.add_child(button)

	resource_choice_overlay.visible = true


func _close_resource_choice() -> void:
	pending_resource_item_id = ""
	if resource_choice_overlay != null:
		resource_choice_overlay.visible = false


func _shop_category_name(item_type: String) -> String:
	match item_type:
		"cosmetic":
			return "COSMETICS"
		"passengers":
			return "PASSENGERS"
		"coins":
			return "AIRPORT COINS"
		"resource_choice":
			return "WINTER SUPPLIES"
		_:
			return "OTHER"


func _add_shop_category_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override(
		"font_size",
		13
	)
	header.add_theme_color_override(
		"font_color",
		GameUIStyle.COLOR_GOLD
	)
	header.custom_minimum_size = Vector2(0, 26)
	shop_list.add_child(header)


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
