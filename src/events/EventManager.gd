class_name EventManager
extends Node

signal changed(snapshot: Dictionary)
signal message(text: String, tone: String)

var passenger_economy: PassengerEconomy
var event_definition: Dictionary = {}
var state: Dictionary = {}
var now_override := -1


func configure(
	economy: PassengerEconomy,
	override_event: Dictionary = {}
) -> void:
	passenger_economy = economy
	if not override_event.is_empty():
		event_definition = override_event.duplicate(true)
	else:
		event_definition = EventCatalog.active_event(_now_unix())

	if event_definition.is_empty():
		state = {}
		changed.emit(get_snapshot())
		return

	var event_id := String(event_definition.get("id", ""))
	state = ProfileStore.get_event_state(event_id)
	if state.is_empty():
		state = _default_state()
		_save_state()

	changed.emit(get_snapshot())


func set_now_override(value: int) -> void:
	now_override = value
	if event_definition.is_empty():
		return
	changed.emit(get_snapshot())


func refresh_from_catalog() -> void:
	if now_override >= 0:
		event_definition = EventCatalog.active_event(now_override)
	else:
		event_definition = EventCatalog.active_event()

	if event_definition.is_empty():
		state = {}
		changed.emit(get_snapshot())
		return

	var event_id := String(event_definition.get("id", ""))
	state = ProfileStore.get_event_state(event_id)
	if state.is_empty():
		state = _default_state()
		_save_state()
	changed.emit(get_snapshot())


func has_active_event() -> bool:
	return (
		not event_definition.is_empty()
		and EventCatalog.is_active(event_definition, _now_unix())
	)


func get_event_name() -> String:
	if event_definition.is_empty():
		return ""
	return String(event_definition.get("name", "Event"))


func get_currency() -> int:
	return int(state.get("currency", 0))


func record_metric(metric: String, amount: int) -> void:
	if not has_active_event() or metric.is_empty() or amount <= 0:
		return

	var current_week := EventCatalog.current_week(
		event_definition,
		_now_unix()
	)
	var progress: Dictionary = state.get(
		"quest_progress",
		{}
	).duplicate(true)
	var claimed: Dictionary = state.get("claimed_quests", {})
	var changed_any := false

	for quest_variant in event_definition.get("quests", []):
		var quest: Dictionary = quest_variant
		if String(quest.get("metric", "")) != metric:
			continue
		if int(quest.get("week", 1)) > current_week:
			continue

		var quest_id := String(quest.get("id", ""))
		if quest_id.is_empty() or bool(claimed.get(quest_id, false)):
			continue

		var target := maxi(int(quest.get("target", 0)), 0)
		var before := int(progress.get(quest_id, 0))
		var after := mini(before + amount, target)
		if after != before:
			progress[quest_id] = after
			changed_any = true

	if not changed_any:
		return

	state["quest_progress"] = progress
	_save_state()
	changed.emit(get_snapshot())


func record_destination_flight(destination_id: String) -> void:
	if (
		not has_active_event()
		or destination_id.is_empty()
	):
		return

	var current_week := EventCatalog.current_week(
		event_definition,
		_now_unix()
	)
	var progress: Dictionary = state.get(
		"quest_progress",
		{}
	).duplicate(true)
	var claimed: Dictionary = state.get(
		"claimed_quests",
		{}
	)
	var changed_any := false

	for quest_variant in event_definition.get("quests", []):
		var quest: Dictionary = quest_variant
		if String(
			quest.get("metric", "")
		) != "destination_flights":
			continue
		if String(
			quest.get("destination_id", "")
		) != destination_id:
			continue
		if int(quest.get("week", 1)) > current_week:
			continue

		var quest_id := String(quest.get("id", ""))
		if (
			quest_id.is_empty()
			or bool(claimed.get(quest_id, false))
		):
			continue

		var target := maxi(
			int(quest.get("target", 0)),
			0
		)
		var before := int(
			progress.get(quest_id, 0)
		)
		var after := mini(before + 1, target)
		if after != before:
			progress[quest_id] = after
			changed_any = true

	var featured: Array = event_definition.get(
		"featured_destinations",
		[]
	)
	var featured_bonus := maxi(
		int(
			event_definition.get(
				"featured_route_currency",
				0
			)
		),
		0
	)
	var featured_match := featured.has(
		destination_id
	)
	if featured_match and featured_bonus > 0:
		state["currency"] = (
			int(state.get("currency", 0))
			+ featured_bonus
		)
		var featured_counts: Dictionary = state.get(
			"featured_route_flights",
			{}
		).duplicate(true)
		featured_counts[destination_id] = (
			int(
				featured_counts.get(
					destination_id,
					0
				)
			)
			+ 1
		)
		state["featured_route_flights"] = (
			featured_counts
		)
		changed_any = true
		message.emit(
			"Featured event route • +%d %s"
			% [
				featured_bonus,
				String(
					event_definition.get(
						"currency_name",
						"event currency"
					)
				)
			],
			"success"
		)

	if not changed_any:
		return

	state["quest_progress"] = progress
	_save_state()
	changed.emit(get_snapshot())


func claim_quest(quest_id: String) -> Dictionary:
	if not has_active_event():
		return _result(false, "No active event.")

	var quest := EventCatalog.quest_by_id(
		event_definition,
		quest_id
	)
	if quest.is_empty():
		return _result(false, "Quest not found.")

	var current_week := EventCatalog.current_week(
		event_definition,
		_now_unix()
	)
	if int(quest.get("week", 1)) > current_week:
		return _result(false, "This quest week is still locked.")

	var claimed: Dictionary = state.get(
		"claimed_quests",
		{}
	).duplicate(true)
	if bool(claimed.get(quest_id, false)):
		return _result(false, "Quest reward already claimed.")

	var progress: Dictionary = state.get("quest_progress", {})
	var target := maxi(int(quest.get("target", 0)), 0)
	if int(progress.get(quest_id, 0)) < target:
		return _result(false, "Quest is not complete yet.")

	claimed[quest_id] = true
	state["claimed_quests"] = claimed
	state["currency"] = (
		int(state.get("currency", 0))
		+ maxi(int(quest.get("currency_reward", 0)), 0)
	)

	var alliance_points := maxi(
		int(quest.get("alliance_points", 0)),
		0
	)
	if alliance_points > 0:
		state["alliance_personal"] = (
			int(state.get("alliance_personal", 0))
			+ alliance_points
		)
		state["alliance_total"] = (
			int(state.get("alliance_total", 0))
			+ alliance_points
		)

	_save_state()
	var reward := int(quest.get("currency_reward", 0))
	message.emit(
		"Quest complete • +%d %s" % [
			reward,
			String(
				event_definition.get(
					"currency_name",
					"event currency"
				)
			)
		],
		"success"
	)
	changed.emit(get_snapshot())
	return _result(true, "Quest reward claimed.")


func purchase_shop_item(item_id: String) -> Dictionary:
	if not has_active_event():
		return _result(false, "No active event.")

	var item := EventCatalog.shop_item_by_id(
		event_definition,
		item_id
	)
	if item.is_empty():
		return _result(false, "Shop item not found.")

	var purchases: Dictionary = state.get(
		"shop_purchases",
		{}
	).duplicate(true)
	var bought := int(purchases.get(item_id, 0))
	var limit := maxi(int(item.get("purchase_limit", 1)), 1)
	if bought >= limit:
		return _result(false, "Purchase limit reached.")

	var price := maxi(int(item.get("price", 0)), 0)
	if get_currency() < price:
		return _result(false, "Not enough event currency.")

	var item_type := String(item.get("type", ""))
	if item_type == "passengers":
		if passenger_economy == null:
			return _result(false, "Passenger system unavailable.")
		var amount := maxi(int(item.get("passengers", 0)), 0)
		var free_space := (
			passenger_economy.get_capacity()
			- passenger_economy.get_passengers()
		)
		if amount <= 0 or free_space < amount:
			return _result(
				false,
				"Need %d free passenger storage." % amount
			)

	state["currency"] = get_currency() - price
	purchases[item_id] = bought + 1
	state["shop_purchases"] = purchases
	if not _save_state():
		return _result(false, "Could not save event purchase.")

	if item_type == "passengers":
		var passenger_amount := int(item.get("passengers", 0))
		passenger_economy.add_passengers(passenger_amount)
		message.emit(
			"Event shop • +%d passengers" % passenger_amount,
			"success"
		)
	elif item_type == "cosmetic":
		var cosmetic_id := String(item.get("cosmetic_id", ""))
		if cosmetic_id.is_empty():
			return _result(false, "Cosmetic is not configured.")
		ProfileStore.add_owned_cosmetic(cosmetic_id)
		message.emit(
			"Cosmetic unlocked • %s" % String(
				item.get("name", "Event cosmetic")
			),
			"success"
		)

	changed.emit(get_snapshot())
	return _result(true, "Purchase complete.")


func set_alliance_total_from_server(total: int) -> void:
	if not has_active_event():
		return

	state["alliance_total"] = maxi(
		total,
		int(state.get("alliance_personal", 0))
	)
	_save_state()
	changed.emit(get_snapshot())


func claim_alliance_milestone(milestone_id: String) -> Dictionary:
	if not has_active_event():
		return _result(false, "No active event.")

	var milestone := EventCatalog.alliance_milestone_by_id(
		event_definition,
		milestone_id
	)
	if milestone.is_empty():
		return _result(false, "Alliance milestone not found.")

	var claimed: Dictionary = state.get(
		"claimed_alliance_milestones",
		{}
	).duplicate(true)
	if bool(claimed.get(milestone_id, false)):
		return _result(false, "Alliance reward already claimed.")

	var target := maxi(int(milestone.get("target", 0)), 0)
	if int(state.get("alliance_total", 0)) < target:
		return _result(false, "Alliance milestone not reached.")

	claimed[milestone_id] = true
	state["claimed_alliance_milestones"] = claimed

	var reward_type := String(
		milestone.get("reward_type", "currency")
	)
	if reward_type == "currency":
		state["currency"] = (
			get_currency()
			+ maxi(int(milestone.get("currency_reward", 0)), 0)
		)

	if not _save_state():
		return _result(false, "Could not save alliance reward.")

	if reward_type == "cosmetic":
		var cosmetic_id := String(
			milestone.get("cosmetic_id", "")
		)
		if not cosmetic_id.is_empty():
			ProfileStore.add_owned_cosmetic(cosmetic_id)

	message.emit(
		"Alliance milestone claimed • %s" % String(
			milestone.get("name", "Alliance reward")
		),
		"success"
	)
	changed.emit(get_snapshot())
	return _result(true, "Alliance reward claimed.")


func get_snapshot() -> Dictionary:
	if event_definition.is_empty() or not has_active_event():
		return {
			"active": false
		}

	var event_id := String(event_definition.get("id", ""))
	var current_week := EventCatalog.current_week(
		event_definition,
		_now_unix()
	)
	var progress: Dictionary = state.get("quest_progress", {})
	var claimed: Dictionary = state.get("claimed_quests", {})
	var purchases: Dictionary = state.get("shop_purchases", {})
	var claimed_alliance: Dictionary = state.get(
		"claimed_alliance_milestones",
		{}
	)
	var profile := ProfileStore.load_profile()
	var owned_cosmetics: Dictionary = profile.get(
		"owned_cosmetics",
		{}
	)

	var quests: Array[Dictionary] = []
	for quest_variant in event_definition.get("quests", []):
		var quest: Dictionary = (
			quest_variant as Dictionary
		).duplicate(true)
		var quest_id := String(quest.get("id", ""))
		var target := maxi(int(quest.get("target", 0)), 0)
		var quest_progress := mini(
			int(progress.get(quest_id, 0)),
			target
		)
		quest["progress"] = quest_progress
		quest["claimed"] = bool(claimed.get(quest_id, false))
		quest["unlocked"] = int(quest.get("week", 1)) <= current_week
		quest["complete"] = quest_progress >= target
		quests.append(quest)

	var shop: Array[Dictionary] = []
	for item_variant in event_definition.get("shop", []):
		var item: Dictionary = (
			item_variant as Dictionary
		).duplicate(true)
		var item_id := String(item.get("id", ""))
		var bought := int(purchases.get(item_id, 0))
		var limit := maxi(int(item.get("purchase_limit", 1)), 1)
		item["purchased"] = bought
		item["remaining"] = maxi(limit - bought, 0)
		item["sold_out"] = bought >= limit
		item["can_afford"] = get_currency() >= int(item.get("price", 0))
		if String(item.get("type", "")) == "cosmetic":
			item["owned"] = bool(
				owned_cosmetics.get(
					String(item.get("cosmetic_id", "")),
					false
				)
			)
		else:
			item["owned"] = false
		shop.append(item)

	var alliance_entries: Array[Dictionary] = []
	var alliance: Dictionary = event_definition.get("alliance", {})
	for milestone_variant in alliance.get("milestones", []):
		var milestone: Dictionary = (
			milestone_variant as Dictionary
		).duplicate(true)
		var milestone_id := String(milestone.get("id", ""))
		milestone["claimed"] = bool(
			claimed_alliance.get(milestone_id, false)
		)
		milestone["reached"] = (
			int(state.get("alliance_total", 0))
			>= int(milestone.get("target", 0))
		)
		alliance_entries.append(milestone)

	return {
		"active": true,
		"id": event_id,
		"name": String(event_definition.get("name", "Event")),
		"short_name": String(
			event_definition.get("short_name", "EVENT")
		),
		"theme": String(
			event_definition.get("theme", "")
		),
		"pico_livery_cosmetic_id": String(
			event_definition.get(
				"pico_livery_cosmetic_id",
				""
			)
		),
		"featured_marker_text": String(
			event_definition.get(
				"featured_marker_text",
				""
			)
		),
		"currency_name": String(
			event_definition.get("currency_name", "Event Currency")
		),
		"currency": get_currency(),
		"week": current_week,
		"days_remaining": EventCatalog.days_remaining(
			event_definition,
			_now_unix()
		),
		"quests": quests,
		"shop": shop,
		"alliance_enabled": bool(alliance.get("enabled", false)),
		"alliance_personal": int(
			state.get("alliance_personal", 0)
		),
		"alliance_total": int(state.get("alliance_total", 0)),
		"alliance_milestones": alliance_entries,
		"featured_destinations": (
			event_definition.get(
				"featured_destinations",
				[]
			) as Array
		).duplicate(true),
		"featured_route_currency": int(
			event_definition.get(
				"featured_route_currency",
				0
			)
		),
		"featured_route_flights": (
			state.get(
				"featured_route_flights",
				{}
			) as Dictionary
		).duplicate(true)
	}


func _default_state() -> Dictionary:
	return {
		"currency": 0,
		"quest_progress": {},
		"claimed_quests": {},
		"shop_purchases": {},
		"featured_route_flights": {},
		"alliance_personal": 0,
		"alliance_total": 0,
		"claimed_alliance_milestones": {}
	}


func _save_state() -> bool:
	if event_definition.is_empty():
		return false

	var event_id := String(event_definition.get("id", ""))
	var updated := ProfileStore.save_event_state(
		event_id,
		state
	)
	if updated.is_empty():
		return false

	var states: Dictionary = updated.get("event_states", {})
	if states.has(event_id) and states[event_id] is Dictionary:
		state = (states[event_id] as Dictionary).duplicate(true)
	return true


func _now_unix() -> int:
	if now_override >= 0:
		return now_override
	return int(Time.get_unix_time_from_system())


func _result(success: bool, text: String) -> Dictionary:
	return {
		"success": success,
		"message": text
	}
