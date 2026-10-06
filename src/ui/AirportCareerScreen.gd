class_name AirportCareerScreen
extends CanvasLayer

signal claim_requested(quest_id: String)
signal guidance_requested(quest: Dictionary)
signal aircraft_purchase_requested(aircraft_id: String)
signal npc_toggle_requested(enabled: bool)
signal activity_requested(mode_id: String)
signal closed

var root: Control
var body: VBoxContainer
var scroll: ScrollContainer
var header: Label
var tabs: Dictionary = {}
var selected_tab := "Career"
var data: Dictionary = {}
var current_signature := 0

func _ready() -> void:
	layer = 38
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = GameUIStyle.COLOR_BG
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	header = Label.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.heading(header, 21)
	top.add_child(header)
	var close_button := Button.new()
	close_button.text = "AIRPORT  ×"
	close_button.custom_minimum_size = Vector2(140, 48)
	GameUIStyle.apply_button(close_button, "secondary", true)
	close_button.pressed.connect(close_screen)
	top.add_child(close_button)
	var tab_row := HBoxContainer.new()
	column.add_child(tab_row)
	for title in ["Career", "Aircraft Orders", "NPC Visitors", "Friendship"]:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(open_tab.bind(title))
		tab_row.add_child(button)
		tabs[title] = button
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	root.visible = false

func open_screen(snapshot: Dictionary, tab: String = "Career") -> void:
	data = snapshot.duplicate(true)
	selected_tab = tab if tabs.has(tab) else "Career"
	root.visible = true
	_refresh()

func open_tab(tab: String) -> void:
	selected_tab = tab
	scroll.scroll_vertical = 0
	_refresh()

func close_screen() -> void:
	root.visible = false
	closed.emit()

func is_open() -> bool:
	return root != null and root.visible

func set_snapshot(snapshot: Dictionary) -> void:
	var signature := hash(snapshot)
	data = snapshot.duplicate(true)
	if is_open() and signature != current_signature:
		_refresh()

func _refresh() -> void:
	if body == null:
		return
	current_signature = hash(data)
	var position := scroll.scroll_vertical
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for title in tabs:
		GameUIStyle.apply_button(tabs[title], "selected" if title == selected_tab else "nav", true)
	var state: Dictionary = data.get("state", {})
	var level := int(data.get("level", 1))
	header.text = "AIRPORT CAREER  •  LV %d  •  XP %d / %d  •  COINS %d" % [
		level, int(state.get("xp", 0)), AirportProgressionRules.xp_for_level(mini(level + 1, 30)), int(state.get("coins", 0))]
	match selected_tab:
		"Career": _career(state, level)
		"Aircraft Orders": _orders(state, level)
		"NPC Visitors": _visitors(state, level)
		"Friendship": _friendships(state)
	scroll.set_deferred("scroll_vertical", position)

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(panel, "raised")
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column

func _text(parent: Node, text: String, large: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if large:
		GameUIStyle.heading(label, 19)
	else:
		label.add_theme_font_size_override("font_size", 14)
		GameUIStyle.muted(label)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, kind: String = "primary") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	GameUIStyle.apply_button(button, kind, true)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _aircraft_image(parent: Node, id: String) -> void:
	var path := "res://assets/pixel/aircraft/%s/%s_se.png" % [id, id]
	if not ResourceLoader.exists(path):
		return
	var image := TextureRect.new()
	image.texture = load(path)
	image.custom_minimum_size = Vector2(112, 76)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(image)

func _career(state: Dictionary, level: int) -> void:
	var status := AirportProgressionRules.quest_status(state, data.get("airport", {}), level)
	var quest: Dictionary = status.get("quest", {})
	var card := _card()
	if quest.is_empty():
		_text(card, "V1 CAREER COMPLETE", true)
		_text(card, "Your airport career is complete. Continue building your fleet, hosting visitors, mastering routes and exploring Activities.")
		_add_activity_roadmap(state, level)
		return
	var claimed: Dictionary = state.get("claimed", {})
	_text(card, "%s  •  %d / %d missions completed" % [quest["chapter"], claimed.size(), AirportCareerCatalog.all().size()])
	_text(card, String(quest["title"]), true)
	_text(card, String(quest["mentor"]) + " — " + String(quest["guidance"]))
	var objective: Dictionary = quest.get("objective", {})
	if objective.has("aircraft"):
		_aircraft_image(card, String(objective["aircraft"]))
	var progress := ProgressBar.new()
	progress.max_value = float(status.get("target", 1))
	progress.value = float(status.get("count", 0))
	progress.custom_minimum_size.y = 24
	card.add_child(progress)
	_text(card, "PROGRESS %d / %d  •  REWARD: %d XP%s" % [int(status.get("count", 0)), int(status.get("target", 1)),
		int(quest.get("xp", 0)), " + %d passengers" % int(quest.get("passengers", 0)) if int(quest.get("passengers", 0)) > 0 else ""])
	if bool(status.get("locked", false)):
		_text(card, "Available at airport level %d. Keep flying ordinary routes to earn XP and save for infrastructure; there is no paid skip." % int(quest.get("level", 1)))
	var actions := HBoxContainer.new()
	card.add_child(actions)
	var guide := _button(actions, "SHOW ME WHERE", _guide.bind(quest), "secondary")
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var claim := _button(actions, "CLAIM REWARD" if bool(status.get("ready", false)) else "IN PROGRESS", _claim.bind(String(quest["id"])), "gold")
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim.disabled = not bool(status.get("ready", false))
	var pending := int(state.get("pending_passengers", 0))
	if pending > 0:
		_text(card, "%d earned passengers are reserved. They move into airport storage as space becomes available; none expire." % pending)
	var next_card := _card()
	_text(next_card, "COMING NEXT", true)
	var shown := 0
	for upcoming in AirportCareerCatalog.all():
		if bool(claimed.get(upcoming["id"], false)) or upcoming["id"] == quest["id"]:
			continue
		_text(next_card, "LV %d  •  %s" % [int(upcoming["level"]), String(upcoming["title"])])
		shown += 1
		if shown >= 3:
			break

	_add_activity_roadmap(state, level)

func _add_activity_roadmap(
	state: Dictionary,
	level: int
) -> void:
	var activity_card := _card()
	_text(activity_card, "AIRPORT ACTIVITIES", true)
	_text(
		activity_card,
		"New modes unlock gradually as your airport grows. Activity missions can join Daily/Weekly rotation after the related system becomes available."
	)
	var activities: Dictionary = data.get("activities", {})
	var suggested_mode := ""
	for mode_id in [
		"missions",
		"event",
		"dispatch",
		"challenge",
		"alliance",
		"charter"
	]:
		var activity := ActivityProgressionRules.definition(mode_id)
		var unlock_level := int(activity.get("unlock_level", 1))
		var title := String(activity.get("title", mode_id))
		var status_text := "LV %d" % unlock_level
		var activity_state: Dictionary = activities.get(mode_id, {})
		if level >= unlock_level:
			status_text = (
				"INTRODUCED"
				if ActivityProgressionRules.tutorial_seen(
					state,
					mode_id
				)
				else "NEW"
			)
		if (
			suggested_mode.is_empty()
			and bool(activity_state.get("new", false))
			and bool(activity_state.get("enabled", false))
		):
			suggested_mode = mode_id
		_text(
			activity_card,
			"%s  •  %s" % [status_text, title]
		)
	if not suggested_mode.is_empty():
		var suggested := ActivityProgressionRules.definition(
			suggested_mode
		)
		_button(
			activity_card,
			"INTRODUCE • %s" % String(
				suggested.get("title", suggested_mode)
			).to_upper(),
			func() -> void:
				activity_requested.emit(suggested_mode),
			"gold"
		)


func _orders(state: Dictionary, level: int) -> void:
	_text(body, "Aircraft are bought with ordinary coins, not quest rewards. A purchased plane waits in reserve until a connected, fully serviced stand is free.", true)
	var active: Array = data.get("active_owned", [])
	for profile in AircraftCatalog.all():
		var id := String(profile["id"])
		var owned := 0
		var deployed := 0
		for entry in state.get("owned_aircraft", []):
			if String(entry.get("type", "")) == id:
				owned += 1
				if active.has(entry.get("uid", "")):
					deployed += 1
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		_aircraft_image(row, id)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		_text(details, "%s  •  %s  •  LV %d" % [profile["name"], profile["size"], int(profile["unlock_level"])], true)
		_text(details, "%d owned • %d deployed • %d in reserve | %d seats • %d km range" % [owned, deployed, owned - deployed, int(profile["passengers"]), int(profile["range_km"])])
		var cost := int(AirportProgressionRules.AIRCRAFT_PRICES[id])
		var label := "BUY • %d COINS" % cost
		if level < int(profile["unlock_level"]):
			label = "UNLOCKS AT LV %d" % int(profile["unlock_level"])
		elif int(state.get("coins", 0)) < cost:
			label = "NEED %d MORE COINS" % (cost - int(state.get("coins", 0)))
		var button := _button(details, label, _purchase.bind(id))
		button.disabled = level < int(profile["unlock_level"]) or int(state.get("coins", 0)) < cost or (state.get("owned_aircraft", []) as Array).size() >= AirportProgressionRules.MAX_OWNED_AIRCRAFT
		if profile["size"] == "M" and not bool((data.get("airport", {}) as Dictionary).get("medium_ready", false)):
			_text(details, "Reserve only until a Regional Runway (LV 12), medium stand and connected services are ready.")

func _visitors(state: Dictionary, level: int) -> void:
	var intro := _card()
	_text(intro, "OCCASIONAL NPC TRAFFIC", true)
	_text(intro, "These are fictional computer-controlled pilots, not online friends. After the first visit, an arrival opportunity occurs roughly every 3–6 minutes of active play. Busy airports defer arrivals; offline time never creates a queue flood.")
	var enabled := bool(data.get("npc_enabled", true))
	_button(intro, "PAUSE NEW NPC ARRIVALS" if enabled else "RESUME NPC ARRIVALS", _toggle.bind(not enabled), "secondary")
	var discovered: Dictionary = state.get("npc_seen", {})
	for contact in NpcTrafficDirector.catalog():
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		_aircraft_image(row, String(contact["aircraft_type_id"]))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var profile := AircraftCatalog.get_profile(String(contact["aircraft_type_id"]))
		_text(details, "%s  •  %s" % [contact["display_name"], profile.get("name", "Aircraft")], true)
		var seen := int(discovered.get(contact["id"], 0))
		_text(details, "%s • %s | LV %d • %s | %d successful visits" % [contact["airport_name"], contact["country_id"], int(contact["unlock_level"]), contact["size"], seen])
		if level < int(contact["unlock_level"]):
			_text(details, "Available later as your airport levels up.")
		elif contact["size"] == "M" and not bool((data.get("airport", {}) as Dictionary).get("medium_ready", false)):
			_text(details, "Your level qualifies; compatible medium infrastructure is still required.")
		else:
			_text(details, "Eligible when a compatible connected stand and ground services are available.")

func _friendships(state: Dictionary) -> void:
	var intro := _card()
	_text(intro, "ROUTE FRIENDSHIP", true)
	_text(intro, "Five ranks at 0 / 10 / 30 / 75 / 150 successful visits. Earn at most five friendship points per contact per UTC day. NPC visits never count. Coin bonuses rise gradually to 2%; no paid boosts.")
	var ledger: Dictionary = state.get("friendships", {})
	if ledger.is_empty():
		_text(intro, "Service a friend or alliance visit to start. The current Social network is still a local test network, not live multiplayer.")
	for contact_id in ledger:
		var entry: Dictionary = ledger[contact_id]
		var rank := FriendshipRules.status(entry)
		var card := _card()
		_text(card, "%s  •  %s  •  RANK %d / 5" % [entry.get("name", contact_id), rank["name"], rank["rank"]], true)
		_text(card, "%d / %d friendship points • +%.1f%% host coins%s" % [rank["points"], rank["next"], float(rank["coin_bonus"]) * 100.0,
			" • LOCAL TEST CONTACT" if bool(entry.get("local_test", false)) else ""])

func _claim(id: String) -> void:
	claim_requested.emit(id)

func _guide(quest: Dictionary) -> void:
	guidance_requested.emit(quest)

func _purchase(id: String) -> void:
	aircraft_purchase_requested.emit(id)

func _toggle(enabled: bool) -> void:
	npc_toggle_requested.emit(enabled)
