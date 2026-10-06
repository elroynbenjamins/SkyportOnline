class_name CharterScreen
extends CanvasLayer

signal close_requested
signal accept_requested(offer_id: String)
signal claim_requested

var root: Control
var status_label: Label
var active_panel: VBoxContainer
var offers_list: VBoxContainer
var snapshot: Dictionary = {}

func _ready() -> void:
	layer = 38
	_build_ui()
	root.visible = false

func open_screen(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	_refresh()
	root.visible = true

func close_screen() -> void:
	if root != null:
		root.visible = false
	close_requested.emit()

func is_open() -> bool:
	return root != null and root.visible

func set_snapshot(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	if is_open():
		_refresh()

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
	panel.offset_left = 32
	panel.offset_top = 28
	panel.offset_right = -32
	panel.offset_bottom = -28
	root.add_child(panel)
	GameUIStyle.apply_panel(panel, "raised")

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
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	var title := Label.new()
	title.text = "CARGO CHARTER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(title, 24)
	title.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "LOGISTICS DISTRICT • TARGETED COUNTRY RESOURCES"
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	GameUIStyle.muted(subtitle)
	header.add_child(subtitle)

	var close_button := Button.new()
	close_button.text = "✕  AIRPORT"
	close_button.custom_minimum_size = Vector2(132, 42)
	close_button.pressed.connect(close_screen)
	GameUIStyle.apply_button(close_button, "secondary", true)
	header.add_child(close_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(status_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	column.add_child(columns)

	active_panel = _build_column(columns, "ACTIVE CHARTER", 0.42)
	offers_list = _build_column(columns, "AVAILABLE CONTRACTS", 0.58)

func _build_column(parent: HBoxContainer, title_text: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	GameUIStyle.apply_panel(panel, "dark")
	parent.add_child(panel)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	panel.add_child(wrapper)

	var heading := Label.new()
	heading.text = title_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.heading(heading, 16)
	wrapper.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrapper.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	return list

func _refresh() -> void:
	_clear(active_panel)
	_clear(offers_list)

	var unlocked := bool(snapshot.get("unlocked", false))
	var parcel_owned := bool(snapshot.get("parcel_owned", false))
	var parcel_ready := bool(snapshot.get("parcel_ready", false))
	if not unlocked:
		status_label.text = "Cargo Charter unlocks at Airport Level %d." % int(snapshot.get("unlock_level", CharterRules.UNLOCK_LEVEL))
		_add_empty(active_panel, "Mode locked.")
		_add_empty(offers_list, "Keep growing the airport.")
		return
	if not parcel_owned:
		status_label.text = "Cargo Charter unlocked • purchase the Logistics District to begin operations."
	elif not parcel_ready:
		status_label.text = "Logistics District is owned, but the Charter footprint is occupied. Move conflicting buildings first."
	else:
		var rotation_seconds := int(snapshot.get("board_rotation_seconds", 0))
		status_label.text = (
			"Dedicated cargo aircraft • one Charter at a time • board refreshes in %s"
			% _format_time(rotation_seconds)
			if rotation_seconds > 0
			else "Dedicated cargo aircraft • no passenger stock required • one Charter contract can run at a time."
		)

	var active: Dictionary = snapshot.get("active", {})
	if active.is_empty():
		_add_empty(active_panel, "No active Charter.
Choose a contract to start loading.")
	else:
		_add_active(active)

	var offers: Array = snapshot.get("offers", [])
	if offers.is_empty():
		_add_empty(offers_list, "No contracts available while a Charter is active.")
	else:
		for offer_variant in offers:
			_add_offer(offer_variant, parcel_ready and active.is_empty())

func _add_active(active: Dictionary) -> void:
	var card := PanelContainer.new()
	GameUIStyle.apply_panel(card, "raised")
	active_panel.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title := Label.new()
	title.text = "%s • %s" % [
		String(active.get("contract_type_name", "Standard Freight")).to_upper(),
		String(active.get("city", "Destination")).to_upper()
	]
	GameUIStyle.heading(title, 17)
	box.add_child(title)

	var cargo := Label.new()
	cargo.text = "%s • %s" % [
		String(active.get("contract_type_badge", "BALANCED")),
		String(active.get("resource_name", "Cargo"))
	]
	cargo.add_theme_font_size_override("font_size", 12)
	cargo.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	box.add_child(cargo)

	var phase := String(active.get("phase", "LOADING"))
	var remaining := int(active.get("remaining_seconds", 0))
	var phase_label := Label.new()
	phase_label.text = "%s • %s remaining" % [phase.replace("_", " ").capitalize(), _format_time(remaining)] if phase != "READY" else "RETURN COMPLETE • REWARD READY"
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.add_theme_color_override("font_color", GameUIStyle.COLOR_SUCCESS if phase == "READY" else GameUIStyle.COLOR_ACCENT)
	box.add_child(phase_label)

	var detail := Label.new()
	detail.text = "%d pallets • 🪙 %d • %d XP • +%d %s" % [
		int(active.get("pallets", 1)),
		int(active.get("coin_reward", 0)),
		int(active.get("xp_reward", 0)),
		int(active.get("resource_amount", 1)),
		String(active.get("resource_name", "resource"))
	]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 13)
	box.add_child(detail)

	if phase == "LOADING":
		var loaded := int(active.get("pallet_count", 0))
		var progress := ProgressBar.new()
		progress.min_value = 0
		progress.max_value = maxi(int(active.get("pallets", 1)), 1)
		progress.value = loaded
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(0, 12)
		GameUIStyle.apply_progress(progress, true)
		box.add_child(progress)
		var load_label := Label.new()
		load_label.text = "%d / %d pallets staged at the aircraft" % [loaded, int(active.get("pallets", 1))]
		GameUIStyle.muted(load_label)
		box.add_child(load_label)

	if phase == "READY":
		var claim := Button.new()
		claim.text = "CLAIM CHARTER REWARD"
		claim.custom_minimum_size = Vector2(0, 48)
		GameUIStyle.apply_button(claim, "gold")
		claim.pressed.connect(func() -> void: claim_requested.emit())
		box.add_child(claim)

func _add_offer(offer: Dictionary, enabled: bool) -> void:
	var card := PanelContainer.new()
	GameUIStyle.apply_panel(card, "context")
	offers_list.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var title := Label.new()
	title.text = "%s • %s" % [
		String(offer.get("contract_type_name", "Standard Freight")).to_upper(),
		String(offer.get("city", "Route")).to_upper()
	]
	GameUIStyle.heading(title, 15)
	box.add_child(title)

	var type_line := Label.new()
	type_line.text = "%s • %s" % [
		String(offer.get("contract_type_badge", "BALANCED")),
		String(offer.get("contract_type_description", "Balanced loading and rewards."))
	]
	type_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	type_line.add_theme_font_size_override("font_size", 11)
	type_line.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
	box.add_child(type_line)

	var detail := Label.new()
	detail.text = "%s • %d pallets • loading %s • flight %s
🪙 %d • %d XP • guaranteed +%d %s" % [
		String(offer.get("resource_name", "Cargo")),
		int(offer.get("pallets", 1)),
		_format_time(int(offer.get("load_seconds", 0))),
		_format_time(int(offer.get("route_seconds", 0))),
		int(offer.get("coin_reward", 0)),
		int(offer.get("xp_reward", 0)),
		int(offer.get("resource_amount", 1)),
		String(offer.get("resource_name", "country resource"))
	]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	box.add_child(detail)

	var accept := Button.new()
	accept.text = "ACCEPT CHARTER"
	accept.disabled = not enabled
	accept.custom_minimum_size = Vector2(0, 42)
	GameUIStyle.apply_button(accept, "primary" if enabled else "secondary")
	accept.pressed.connect(func() -> void: accept_requested.emit(String(offer.get("id", ""))))
	box.add_child(accept)

func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()

func _add_empty(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	GameUIStyle.muted(label)
	list.add_child(label)

func _format_time(seconds: int) -> String:
	var total := maxi(seconds, 0)
	if total >= 3600:
		return "%dh %02dm" % [int(total / 3600), int((total % 3600) / 60)]
	if total >= 60:
		return "%dm %02ds" % [int(total / 60), total % 60]
	return "%ds" % total
