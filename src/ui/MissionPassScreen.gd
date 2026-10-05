class_name MissionPassScreen
extends CanvasLayer

signal reroll_requested(mission_id: String, use_ad: bool)
signal pass_reward_claim_requested(tier_number: int, track: String)
signal claim_all_requested
signal product_purchase_requested(product_id: String)
signal closed

var root: Control
var body: VBoxContainer
var scroll: ScrollContainer
var header: Label
var tabs: Dictionary = {}
var selected_tab := "Daily"
var data: Dictionary = {}
var current_signature := 0

func _ready() -> void:
	layer = 39
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
	top.add_theme_constant_override("separation", 12)
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
	tab_row.add_theme_constant_override("separation", 6)
	column.add_child(tab_row)
	for title in ["Daily", "Weekly", "Airport Pass", "Aero Tokens"]:
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

func open_screen(snapshot: Dictionary, tab: String = "Daily") -> void:
	data = snapshot.duplicate(true)
	selected_tab = tab if tabs.has(tab) else "Daily"
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
	var pass_state: Dictionary = state.get("mission_pass", {})
	var points := int(pass_state.get("points", 0))
	var tier := MissionPassRules.pass_level(state)
	header.text = "MISSIONS  •  PASS %d / %d  •  %d PTS  •  ✦ %d AERO" % [
		tier,
		MissionPassCatalog.TIERS,
		points,
		int(state.get("aero_tokens", state.get("gems", 0)))
	]

	match selected_tab:
		"Daily":
			_daily(state)
		"Weekly":
			_weekly(state)
		"Airport Pass":
			_pass(state)
		"Aero Tokens":
			_store(state)
	scroll.set_deferred("scroll_vertical", position)

func _daily(state: Dictionary) -> void:
	var pass_state: Dictionary = state.get("mission_pass", {})
	var daily: Array = pass_state.get("daily", [])
	var completed := MissionPassRules.completed_daily_count(state)
	var intro := _card()
	_text(intro, "DAILY MISSIONS  •  %d / %d" % [completed, daily.size()], true)
	_text(intro, "Each completed mission awards %d Pass Points. Complete all four for +%d bonus points. Daily missions refresh at the next UTC day." % [
		MissionPassCatalog.DAILY_MISSION_POINTS,
		MissionPassCatalog.DAILY_COMPLETION_BONUS
	])
	var reroll_status := "1 free reroll available"
	if bool(pass_state.get("free_reroll_used", false)):
		reroll_status = "Free reroll used • rewarded-ad reroll available" if not bool(pass_state.get("ad_reroll_used", false)) else "All daily rerolls used"
	_text(intro, reroll_status)

	for mission_variant in daily:
		var mission: Dictionary = mission_variant
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		_text(details, String(mission.get("title", "Mission")), true)
		_text(details, String(mission.get("description", "")))
		_progress(details, int(mission.get("progress", 0)), int(mission.get("target", 1)))
		var done := bool(mission.get("awarded", false))
		_text(details, "COMPLETE • +%d PASS POINTS" % MissionPassCatalog.DAILY_MISSION_POINTS if done else "PROGRESS %d / %d" % [
			int(mission.get("progress", 0)),
			int(mission.get("target", 1))
		])
		if done:
			continue
		var free_used := bool(pass_state.get("free_reroll_used", false))
		var ad_used := bool(pass_state.get("ad_reroll_used", false))
		var button := Button.new()
		if not free_used:
			button.text = "REROLL • FREE"
			button.pressed.connect(_reroll.bind(String(mission.get("id", "")), false))
			GameUIStyle.apply_button(button, "secondary", true)
		elif not ad_used:
			var ad_ready := bool(data.get("rewarded_ad_connected", false))
			button.text = "WATCH AD • REROLL" if ad_ready else "AD REROLL • PROVIDER OFFLINE"
			button.disabled = not ad_ready
			if ad_ready:
				button.pressed.connect(_reroll.bind(String(mission.get("id", "")), true))
			GameUIStyle.apply_button(button, "event" if ad_ready else "secondary", true)
		else:
			button.text = "REROLLS USED"
			button.disabled = true
			GameUIStyle.apply_button(button, "secondary", true)
		button.custom_minimum_size = Vector2(210, 46)
		row.add_child(button)

func _weekly(state: Dictionary) -> void:
	var pass_state: Dictionary = state.get("mission_pass", {})
	var weekly: Array = pass_state.get("weekly", [])
	var intro := _card()
	_text(intro, "WEEKLY MISSIONS", true)
	_text(intro, "Each weekly mission gives %d Pass Points. Finishing all five from a week gives +%d bonus. Unfinished weekly missions stay available until the monthly pass ends." % [
		MissionPassCatalog.WEEKLY_MISSION_POINTS,
		MissionPassCatalog.WEEKLY_COMPLETION_BONUS
	])
	var current_key := String(data.get("week_key", ""))
	var groups: Dictionary = {}
	for mission_variant in weekly:
		var mission: Dictionary = mission_variant
		var key := String(mission.get("period_key", ""))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mission)
	var keys: Array = groups.keys()
	keys.sort()
	keys.reverse()
	for key_variant in keys:
		var key := String(key_variant)
		var missions: Array = groups[key]
		var done_count := 0
		for mission in missions:
			if bool(mission.get("awarded", false)):
				done_count += 1
		var header_card := _card()
		_text(header_card, "%s  •  %d / %d" % [
			"CURRENT WEEK" if key == current_key else "CATCH-UP WEEK",
			done_count,
			missions.size()
		], true)
		var bonus_awarded := bool((pass_state.get("weekly_bonus_awarded", {}) as Dictionary).get(key, false))
		_text(header_card, "Weekly completion bonus claimed automatically." if bonus_awarded else "Complete all five for +%d Pass Points." % MissionPassCatalog.WEEKLY_COMPLETION_BONUS)
		for mission_variant in missions:
			var mission: Dictionary = mission_variant
			var card := _card()
			_text(card, String(mission.get("title", "Mission")), true)
			_text(card, String(mission.get("description", "")))
			_progress(card, int(mission.get("progress", 0)), int(mission.get("target", 1)))
			_text(card, "COMPLETE • +%d PASS POINTS" % MissionPassCatalog.WEEKLY_MISSION_POINTS if bool(mission.get("awarded", false)) else "PROGRESS %d / %d" % [
				int(mission.get("progress", 0)),
				int(mission.get("target", 1))
			])

func _pass(state: Dictionary) -> void:
	var pass_state: Dictionary = state.get("mission_pass", {})
	var points := int(pass_state.get("points", 0))
	var premium := bool(pass_state.get("premium", false))
	var intro := _card()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	intro.add_child(top)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text_box)
	_text(text_box, "MONTHLY AIRPORT PASS  •  %s" % String(pass_state.get("month_key", "")), true)
	_text(text_box, "%d / %d points • Tier %d / %d" % [
		points,
		MissionPassCatalog.TIERS * MissionPassCatalog.POINTS_PER_TIER,
		MissionPassRules.pass_level(state),
		MissionPassCatalog.TIERS
	])
	_text(text_box, "Free track is always active. Premium adds extra rewards and retroactively unlocks earned premium tiers.")
	var claimable := MissionPassRules.claimable_count(state)
	var claim_all := Button.new()
	claim_all.text = "CLAIM ALL (%d)" % claimable
	claim_all.disabled = claimable <= 0
	claim_all.custom_minimum_size = Vector2(170, 48)
	GameUIStyle.apply_button(claim_all, "gold" if claimable > 0 else "secondary", true)
	if claimable > 0:
		claim_all.pressed.connect(_claim_all)
	top.add_child(claim_all)
	if not premium:
		var buy := Button.new()
		buy.text = "GET PREMIUM • €4.99"
		buy.custom_minimum_size = Vector2(210, 48)
		GameUIStyle.apply_button(buy, "gold", true)
		buy.pressed.connect(_purchase.bind("airport_pass"))
		top.add_child(buy)
	else:
		var owned := Label.new()
		owned.text = "PREMIUM ACTIVE"
		owned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		owned.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD)
		top.add_child(owned)

	var inventory := _card()
	_text(inventory, "PASS REWARD INVENTORY", true)
	var boosters: Dictionary = state.get("booster_inventory", {})
	_text(inventory, "Ground Crew %d  •  Tailwind %d  •  Tourism %d  •  Gold %d  •  XP %d  •  Country crates %d" % [
		int(boosters.get("booster_ground_crew", 0)),
		int(boosters.get("booster_tailwind", 0)),
		int(boosters.get("booster_passengers", 0)),
		int(boosters.get("booster_gold", 0)),
		int(boosters.get("booster_xp", 0)),
		int(state.get("resource_choice_crates", 0))
	])

	var track_panel := PanelContainer.new()
	track_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(track_panel, "dark")
	body.add_child(track_panel)
	var track_scroll := ScrollContainer.new()
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.custom_minimum_size.y = 250
	track_panel.add_child(track_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	track_scroll.add_child(row)

	var claimed_free: Dictionary = pass_state.get("claimed_free", {})
	var claimed_premium: Dictionary = pass_state.get("claimed_premium", {})
	for tier_variant in MissionPassCatalog.pass_tiers():
		var tier: Dictionary = tier_variant
		var number := int(tier.get("tier", 0))
		var unlocked := points >= int(tier.get("points", 0))
		var tier_card := PanelContainer.new()
		tier_card.custom_minimum_size = Vector2(220, 225)
		GameUIStyle.apply_panel(tier_card, "gold" if unlocked else "raised")
		row.add_child(tier_card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 7)
		tier_card.add_child(column)
		_text(column, "TIER %02d  •  %d PTS" % [number, int(tier.get("points", 0))], true)
		_reward_row(column, number, "free", tier.get("free", {}), unlocked, bool(claimed_free.get(str(number), false)), true)
		_reward_row(column, number, "premium", tier.get("premium", {}), unlocked, bool(claimed_premium.get(str(number), false)), premium)

func _store(state: Dictionary) -> void:
	var intro := _card()
	_text(intro, "AERO TOKENS  •  ✦ %d" % int(state.get("aero_tokens", state.get("gems", 0))), true)
	_text(intro, "Aero Tokens are the premium currency. They can also be earned slowly through gameplay and the free Airport Pass. Store purchases are capped at €9.99.")
	_text(intro, "Purchases are granted only after the platform billing provider confirms payment. This screen never grants currency locally from the buy button.")
	for product_variant in MissionPassCatalog.product_catalog():
		var product: Dictionary = product_variant
		if bool(product.get("premium_pass", false)):
			continue
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		_text(details, String(product.get("title", "Aero Tokens")), true)
		_text(details, "✦ %d Aero Tokens" % int(product.get("aero_tokens", 0)))
		var button := Button.new()
		button.text = String(product.get("price_label", ""))
		button.custom_minimum_size = Vector2(150, 48)
		GameUIStyle.apply_button(button, "gold", true)
		button.pressed.connect(_purchase.bind(String(product.get("id", ""))))
		row.add_child(button)

func _reward_row(
	parent: Node,
	tier_number: int,
	track: String,
	reward: Dictionary,
	unlocked: bool,
	claimed: bool,
	track_enabled: bool
) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	var name := "FREE" if track == "free" else "PREMIUM"
	var label := Label.new()
	label.text = "%s • %s" % [name, String(reward.get("label", "Reward"))]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GameUIStyle.COLOR_GOLD if track == "premium" else GameUIStyle.COLOR_TEXT)
	section.add_child(label)
	var button := Button.new()
	button.custom_minimum_size.y = 36
	if claimed:
		button.text = "CLAIMED"
		button.disabled = true
	elif track == "premium" and not track_enabled:
		button.text = "PREMIUM LOCKED"
		button.disabled = true
	elif not unlocked:
		button.text = "LOCKED"
		button.disabled = true
	else:
		button.text = "CLAIM"
		button.pressed.connect(_claim_reward.bind(tier_number, track))
	GameUIStyle.apply_button(button, "gold" if unlocked and track_enabled and not claimed else "secondary", true)
	section.add_child(button)

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_panel(panel, "raised")
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column

func _text(parent: Node, value: String, large: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if large:
		GameUIStyle.heading(label, 18)
	else:
		label.add_theme_font_size_override("font_size", 14)
		GameUIStyle.muted(label)
	parent.add_child(label)
	return label

func _progress(parent: Node, value: int, maximum: int) -> void:
	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = maxf(float(maximum), 1.0)
	progress.value = clampf(float(value), 0.0, progress.max_value)
	progress.custom_minimum_size.y = 22
	progress.show_percentage = false
	GameUIStyle.apply_progress(progress)
	parent.add_child(progress)

func _reroll(mission_id: String, use_ad: bool) -> void:
	reroll_requested.emit(mission_id, use_ad)

func _claim_reward(tier_number: int, track: String) -> void:
	pass_reward_claim_requested.emit(tier_number, track)

func _claim_all() -> void:
	claim_all_requested.emit()

func _purchase(product_id: String) -> void:
	product_purchase_requested.emit(product_id)
