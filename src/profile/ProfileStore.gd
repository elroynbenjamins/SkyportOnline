class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://skyport_profile.cfg"
const PROFILE_VERSION := 1


static func has_airport() -> bool:
	return not load_profile().is_empty()


static func load_profile() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}

	var airport_name := String(config.get_value("profile", "airport_name", ""))
	var country_id := String(config.get_value("profile", "country_id", ""))
	if airport_name.is_empty() or country_id.is_empty():
		return {}

	var inventory := {}
	var stored_inventory = config.get_value("profile", "resource_inventory", {})
	if stored_inventory is Dictionary:
		inventory = stored_inventory.duplicate(true)

	var building_upgrades := {}
	var stored_upgrades = config.get_value("profile", "building_upgrades", {})
	if stored_upgrades is Dictionary:
		building_upgrades = stored_upgrades.duplicate(true)

	var airport_layout: Array = []
	var stored_layout = config.get_value(
		"profile",
		"airport_layout",
		[]
	)
	if stored_layout is Array:
		airport_layout = stored_layout.duplicate(true)

	var owned_parcels: Array = []
	var stored_parcels = config.get_value(
		"profile",
		"owned_parcels",
		[]
	)
	if stored_parcels is Array:
		owned_parcels = stored_parcels.duplicate(true)

	var airport_storage: Array = []
	var stored_airport_storage = config.get_value(
		"profile",
		"airport_storage",
		[]
	)
	if stored_airport_storage is Array:
		airport_storage = stored_airport_storage.duplicate(true)

	var runway_strategies := {}
	var stored_runway_strategies = config.get_value(
		"profile",
		"runway_strategies",
		{}
	)
	if stored_runway_strategies is Dictionary:
		runway_strategies = stored_runway_strategies.duplicate(true)

	var aircraft_mastery := {}
	var stored_mastery = config.get_value("profile", "aircraft_mastery_hours", {})
	if stored_mastery is Dictionary:
		aircraft_mastery = stored_mastery.duplicate(true)

	var economy_stats := {}
	var stored_economy = config.get_value("profile", "economy_stats", {})
	if stored_economy is Dictionary:
		economy_stats = stored_economy.duplicate(true)

	var route_history := {}
	var stored_routes = config.get_value("profile", "route_history", {})
	if stored_routes is Dictionary:
		route_history = stored_routes.duplicate(true)

	var event_states := {}
	var stored_event_states = config.get_value("profile", "event_states", {})
	if stored_event_states is Dictionary:
		event_states = stored_event_states.duplicate(true)

	var owned_cosmetics := {}
	var stored_cosmetics = config.get_value("profile", "owned_cosmetics", {})
	if stored_cosmetics is Dictionary:
		owned_cosmetics = stored_cosmetics.duplicate(true)

	var priority_contract_progress := {}
	var stored_contracts = config.get_value(
		"profile",
		"priority_contract_progress",
		{}
	)
	if stored_contracts is Dictionary:
		priority_contract_progress = stored_contracts.duplicate(true)

	var social_state := {}
	var stored_social_state = config.get_value(
		"profile",
		"social_state",
		{}
	)
	if stored_social_state is Dictionary:
		social_state = stored_social_state.duplicate(true)

	return {
		"version": int(config.get_value("profile", "version", PROFILE_VERSION)),
		"account_type": String(config.get_value("profile", "account_type", "guest")),
		"guest_id": String(config.get_value("profile", "guest_id", "")),
		"linked_provider": String(config.get_value("profile", "linked_provider", "")),
		"linked_account_id": String(config.get_value("profile", "linked_account_id", "")),
		"airport_id": String(config.get_value("profile", "airport_id", "")),
		"airport_name": airport_name,
		"airport_code": String(config.get_value("profile", "airport_code", "APT")),
		"country_id": country_id,
		"created_at_unix": int(config.get_value("profile", "created_at_unix", 0)),
		"resource_inventory": inventory,
		"passenger_balance": int(
			config.get_value("profile", "passenger_balance", 20)
		),
		"building_upgrades": building_upgrades,
		"airport_layout": airport_layout,
		"owned_parcels": owned_parcels,
		"airport_storage": airport_storage,
		"runway_strategies": runway_strategies,
		"aircraft_mastery_hours": aircraft_mastery,
		"economy_stats": economy_stats,
		"route_history": route_history,
		"event_states": event_states,
		"owned_cosmetics": owned_cosmetics,
		"priority_contract_progress": priority_contract_progress,
		"social_state": social_state,
		"passenger_gift_day": String(
			config.get_value("profile", "passenger_gift_day", "")
		),
		"passenger_gifts_received_today": int(
			config.get_value(
				"profile",
				"passenger_gifts_received_today",
				0
			)
		)
	}


static func create_guest_airport(
	airport_name: String,
	airport_code: String,
	country_id: String
) -> Dictionary:
	if has_airport():
		return load_profile()
	if not bool(validate_airport_name(airport_name).get("valid", false)):
		return {}
	if not bool(validate_airport_code(airport_code).get("valid", false)):
		return {}
	if CountryCatalog.get_country(country_id).is_empty():
		return {}

	var profile := {
		"version": PROFILE_VERSION,
		"account_type": "guest",
		"guest_id": _make_token("guest"),
		"linked_provider": "",
		"linked_account_id": "",
		"airport_id": _make_token("airport"),
		"airport_name": airport_name.strip_edges(),
		"airport_code": airport_code.strip_edges().to_upper(),
		"country_id": country_id,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"resource_inventory": {},
		"passenger_balance": 20,
		"building_upgrades": {},
		"airport_layout": [],
		"owned_parcels": [],
		"airport_storage": [],
		"runway_strategies": {},
		"aircraft_mastery_hours": {},
		"economy_stats": {},
		"route_history": {},
		"event_states": {},
		"owned_cosmetics": {},
		"priority_contract_progress": {},
		"social_state": {},
		"passenger_gift_day": "",
		"passenger_gifts_received_today": 0
	}
	if not _save_profile(profile):
		return {}
	return profile


static func add_resource_drops(drops: Array) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}
	if drops.is_empty():
		return profile

	var inventory: Dictionary = profile.get("resource_inventory", {}).duplicate(true)
	for drop in drops:
		var resource_id := String(drop.get("id", ""))
		if resource_id.is_empty():
			continue
		var amount := maxi(int(drop.get("amount", 1)), 0)
		inventory[resource_id] = int(inventory.get(resource_id, 0)) + amount

	profile["resource_inventory"] = inventory
	if not _save_profile(profile):
		return {}
	return profile




static func save_airport_layout(
	layout: Array,
	owned_parcels: Array,
	airport_storage: Array = []
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	profile["airport_layout"] = layout.duplicate(true)
	profile["owned_parcels"] = owned_parcels.duplicate(true)
	profile["airport_storage"] = airport_storage.duplicate(true)
	if not _save_profile(profile):
		return {}
	return profile


static func save_passenger_balance(value: int) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	profile["passenger_balance"] = maxi(value, 0)
	if not _save_profile(profile):
		return {}
	return profile


static func set_runway_strategy(
	building_key: String,
	strategy: String
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or building_key.is_empty():
		return {}

	var normalized := RunwayStrategyRules.normalize(strategy)
	var strategies: Dictionary = profile.get(
		"runway_strategies",
		{}
	).duplicate(true)
	if normalized == RunwayStrategyRules.AUTO:
		strategies.erase(building_key)
	else:
		strategies[building_key] = normalized

	profile["runway_strategies"] = strategies
	if not _save_profile(profile):
		return {}
	return profile


static func get_runway_strategies() -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var stored: Dictionary = profile.get(
		"runway_strategies",
		{}
	)
	var result: Dictionary = {}
	for building_key in stored.keys():
		var strategy := RunwayStrategyRules.normalize(
			String(stored[building_key])
		)
		if strategy != RunwayStrategyRules.AUTO:
			result[String(building_key)] = strategy
	return result


static func apply_building_upgrade(
	building_key: String,
	next_level: int,
	resource_cost: Dictionary
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or building_key.is_empty():
		return {}

	var inventory: Dictionary = profile.get(
		"resource_inventory",
		{}
	).duplicate(true)

	for resource_id in resource_cost.keys():
		var needed := maxi(int(resource_cost[resource_id]), 0)
		if int(inventory.get(resource_id, 0)) < needed:
			return {}

	for resource_id in resource_cost.keys():
		var needed := maxi(int(resource_cost[resource_id]), 0)
		inventory[resource_id] = (
			int(inventory.get(resource_id, 0)) - needed
		)

	var upgrades: Dictionary = profile.get(
		"building_upgrades",
		{}
	).duplicate(true)
	upgrades[building_key] = maxi(next_level, 1)

	profile["resource_inventory"] = inventory
	profile["building_upgrades"] = upgrades
	if not _save_profile(profile):
		return {}
	return profile






static func add_economy_stats(delta: Dictionary) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var stats: Dictionary = profile.get(
		"economy_stats",
		{}
	).duplicate(true)

	for key in delta.keys():
		var amount := int(delta[key])
		if amount <= 0:
			continue
		stats[key] = int(stats.get(key, 0)) + amount

	profile["economy_stats"] = stats
	if not _save_profile(profile):
		return {}
	return profile




static func record_route_completion(
	destination_id: String,
	passengers_boarded: int,
	coins_earned: int,
	xp_earned: int,
	resources_earned: int,
	condition_id: String = "normal"
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or destination_id.is_empty():
		return {}

	var history: Dictionary = profile.get(
		"route_history",
		{}
	).duplicate(true)
	var entry: Dictionary = history.get(
		destination_id,
		{}
	).duplicate(true)

	entry["flights_completed"] = int(
		entry.get("flights_completed", 0)
	) + 1
	entry["passengers_boarded"] = int(
		entry.get("passengers_boarded", 0)
	) + maxi(passengers_boarded, 0)
	entry["coins_earned"] = int(
		entry.get("coins_earned", 0)
	) + maxi(coins_earned, 0)
	entry["xp_earned"] = int(
		entry.get("xp_earned", 0)
	) + maxi(xp_earned, 0)
	entry["resources_earned"] = int(
		entry.get("resources_earned", 0)
	) + maxi(resources_earned, 0)

	var condition_counts: Dictionary = entry.get(
		"condition_counts",
		{}
	).duplicate(true)
	var key := condition_id if not condition_id.is_empty() else "normal"
	condition_counts[key] = int(condition_counts.get(key, 0)) + 1
	entry["condition_counts"] = condition_counts

	history[destination_id] = entry
	profile["route_history"] = history
	if not _save_profile(profile):
		return {}
	return profile




static func get_priority_contract_state(
	contract_id: String
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or contract_id.is_empty():
		return {}

	var progress_map: Dictionary = profile.get(
		"priority_contract_progress",
		{}
	)
	return (
		progress_map.get(contract_id, {}) as Dictionary
	).duplicate(true)


static func record_priority_contract_return(
	flight_plan: Dictionary,
	now_unix: int = -1
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var contract_id := String(
		flight_plan.get("priority_contract_id", "")
	)
	if contract_id.is_empty():
		return {
			"profile": profile,
			"eligible": false,
			"completed_now": false
		}

	if not RouteContractRules.is_flight_eligible(
		flight_plan,
		now_unix
	):
		return {
			"profile": profile,
			"eligible": false,
			"expired": true,
			"completed_now": false
		}

	var target := maxi(
		int(
			flight_plan.get(
				"priority_contract_target_flights",
				RouteContractRules.TARGET_FLIGHTS
			)
		),
		1
	)
	var progress_map: Dictionary = profile.get(
		"priority_contract_progress",
		{}
	).duplicate(true)
	var state: Dictionary = progress_map.get(
		contract_id,
		{}
	).duplicate(true)

	var progress := clampi(
		int(state.get("progress", 0)),
		0,
		target
	)
	var already_completed := bool(
		state.get("completed", progress >= target)
	)
	if already_completed:
		return {
			"profile": profile,
			"eligible": true,
			"progress": progress,
			"target": target,
			"completed": true,
			"completed_now": false
		}

	progress = mini(progress + 1, target)
	var completed_now := progress >= target

	state["destination_id"] = String(
		flight_plan.get(
			"priority_contract_destination_id",
			flight_plan.get("destination_id", "")
		)
	)
	state["progress"] = progress
	state["target"] = target
	state["completed"] = completed_now
	state["ends_at_unix"] = int(
		flight_plan.get("priority_contract_ends_at_unix", 0)
	)
	if completed_now:
		var timestamp := now_unix
		if timestamp < 0:
			timestamp = int(Time.get_unix_time_from_system())
		state["completed_at_unix"] = timestamp

	progress_map[contract_id] = state
	profile["priority_contract_progress"] = progress_map
	if not _save_profile(profile):
		return {}

	return {
		"profile": profile,
		"eligible": true,
		"progress": progress,
		"target": target,
		"completed": completed_now,
		"completed_now": completed_now
	}


static func add_aircraft_mastery_hours(
	aircraft_type_id: String,
	hours: float
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or aircraft_type_id.is_empty():
		return {}

	var mastery: Dictionary = profile.get(
		"aircraft_mastery_hours",
		{}
	).duplicate(true)
	mastery[aircraft_type_id] = maxf(
		float(mastery.get(aircraft_type_id, 0.0)) + maxf(hours, 0.0),
		0.0
	)

	profile["aircraft_mastery_hours"] = mastery
	if not _save_profile(profile):
		return {}
	return profile


static func get_aircraft_mastery_hours(
	aircraft_type_id: String
) -> float:
	var profile := load_profile()
	if profile.is_empty():
		return 0.0

	var mastery: Dictionary = profile.get(
		"aircraft_mastery_hours",
		{}
	)
	return maxf(
		float(mastery.get(aircraft_type_id, 0.0)),
		0.0
	)




static func get_passenger_gift_status(
	day_key: String = ""
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var today := day_key
	if today.is_empty():
		today = Time.get_date_string_from_system()

	var stored_day := String(
		profile.get("passenger_gift_day", "")
	)
	var received := int(
		profile.get("passenger_gifts_received_today", 0)
	)
	if stored_day != today:
		received = 0

	return {
		"day": today,
		"received": received,
		"cap": PassengerSupportRules.DAILY_INCOMING_FRIEND_GIFT_CAP,
		"can_receive": (
			received
			< PassengerSupportRules.DAILY_INCOMING_FRIEND_GIFT_CAP
		)
	}


static func record_friend_passenger_gift(
	day_key: String = ""
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var status := get_passenger_gift_status(day_key)
	if status.is_empty() or not bool(status.get("can_receive", false)):
		return {}

	var today := String(status.get("day", day_key))
	var received := int(status.get("received", 0)) + 1

	profile["passenger_gift_day"] = today
	profile["passenger_gifts_received_today"] = received
	if not _save_profile(profile):
		return {}
	return profile


static func get_social_state() -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}
	var state = profile.get("social_state", {})
	if state is Dictionary:
		return (state as Dictionary).duplicate(true)
	return {}


static func get_outgoing_friend_gift_status(
	contact_id: String,
	day_key: String = ""
) -> Dictionary:
	if contact_id.is_empty():
		return {}
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var today := day_key
	if today.is_empty():
		today = Time.get_date_string_from_system()
	var state: Dictionary = profile.get(
		"social_state",
		{}
	).duplicate(true)
	var sent: Dictionary = state.get(
		"sent_passenger_gifts",
		{}
	).duplicate(true)
	var last_day := String(sent.get(contact_id, ""))
	return {
		"contact_id": contact_id,
		"day": today,
		"sent_today": last_day == today,
		"can_send": last_day != today
	}


static func record_outgoing_friend_passenger_gift(
	contact_id: String,
	day_key: String = ""
) -> Dictionary:
	if contact_id.is_empty():
		return {}
	var profile := load_profile()
	if profile.is_empty():
		return {}

	var status := get_outgoing_friend_gift_status(
		contact_id,
		day_key
	)
	if status.is_empty() or not bool(
		status.get("can_send", false)
	):
		return {}

	var state: Dictionary = profile.get(
		"social_state",
		{}
	).duplicate(true)
	var sent: Dictionary = state.get(
		"sent_passenger_gifts",
		{}
	).duplicate(true)
	sent[contact_id] = String(status.get("day", day_key))
	state["sent_passenger_gifts"] = sent
	state["gifts_sent_total"] = int(
		state.get("gifts_sent_total", 0)
	) + 1
	var action_outbox: Array = state.get(
		"social_action_outbox",
		[]
	).duplicate(true)
	action_outbox.append({
		"action": "passenger_gift",
		"contact_id": contact_id,
		"amount": PassengerSupportRules.friend_gift_amount(),
		"day": String(status.get("day", day_key)),
		"created_at_unix": int(Time.get_unix_time_from_system())
	})
	while action_outbox.size() > 50:
		action_outbox.remove_at(0)
	state["social_action_outbox"] = action_outbox
	profile["social_state"] = state
	if not _save_profile(profile):
		return {}
	return profile


static func record_social_service(
	contact_id: String,
	source_type: String,
	country_id: String,
	coins_earned: int,
	xp_earned: int,
	resources_earned: int
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or contact_id.is_empty():
		return {}

	var state: Dictionary = profile.get(
		"social_state",
		{}
	).duplicate(true)
	state["visits_serviced_total"] = int(
		state.get("visits_serviced_total", 0)
	) + 1
	state["social_coins_earned"] = int(
		state.get("social_coins_earned", 0)
	) + maxi(coins_earned, 0)
	state["social_xp_earned"] = int(
		state.get("social_xp_earned", 0)
	) + maxi(xp_earned, 0)
	state["social_resources_earned"] = int(
		state.get("social_resources_earned", 0)
	) + maxi(resources_earned, 0)

	var by_contact: Dictionary = state.get(
		"visits_by_contact",
		{}
	).duplicate(true)
	by_contact[contact_id] = int(
		by_contact.get(contact_id, 0)
	) + 1
	state["visits_by_contact"] = by_contact

	if not country_id.is_empty():
		var by_country: Dictionary = state.get(
			"visits_by_country",
			{}
		).duplicate(true)
		by_country[country_id] = int(
			by_country.get(country_id, 0)
		) + 1
		state["visits_by_country"] = by_country

	if source_type == "alliance":
		state["alliance_visits_serviced"] = int(
			state.get("alliance_visits_serviced", 0)
		) + 1
	else:
		state["friend_visits_serviced"] = int(
			state.get("friend_visits_serviced", 0)
		) + 1

	profile["social_state"] = state
	if not _save_profile(profile):
		return {}
	return profile


static func enqueue_social_reward_receipt(
	contact_id: String,
	reward: Dictionary,
	visit_id: String = ""
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty() or contact_id.is_empty():
		return {}

	var state: Dictionary = profile.get(
		"social_state",
		{}
	).duplicate(true)
	var outbox: Array = state.get(
		"reward_receipt_outbox",
		[]
	).duplicate(true)
	outbox.append({
		"contact_id": contact_id,
		"visit_id": visit_id,
		"reward": reward.duplicate(true),
		"created_at_unix": int(
			Time.get_unix_time_from_system()
		)
	})
	while outbox.size() > 50:
		outbox.remove_at(0)
	state["reward_receipt_outbox"] = outbox
	profile["social_state"] = state
	if not _save_profile(profile):
		return {}
	return profile


static func get_event_state(event_id: String) -> Dictionary:
	if event_id.is_empty():
		return {}

	var profile := load_profile()
	if profile.is_empty():
		return {}

	var states: Dictionary = profile.get("event_states", {})
	if not states.has(event_id):
		return {}
	var stored = states[event_id]
	if stored is Dictionary:
		return stored.duplicate(true)
	return {}


static func save_event_state(
	event_id: String,
	state: Dictionary
) -> Dictionary:
	if event_id.is_empty():
		return {}

	var profile := load_profile()
	if profile.is_empty():
		return {}

	var states: Dictionary = profile.get(
		"event_states",
		{}
	).duplicate(true)
	states[event_id] = state.duplicate(true)
	profile["event_states"] = states
	if not _save_profile(profile):
		return {}
	return profile


static func add_owned_cosmetic(cosmetic_id: String) -> Dictionary:
	if cosmetic_id.is_empty():
		return {}

	var profile := load_profile()
	if profile.is_empty():
		return {}

	var cosmetics: Dictionary = profile.get(
		"owned_cosmetics",
		{}
	).duplicate(true)
	cosmetics[cosmetic_id] = true
	profile["owned_cosmetics"] = cosmetics
	if not _save_profile(profile):
		return {}
	return profile


static func owns_cosmetic(cosmetic_id: String) -> bool:
	if cosmetic_id.is_empty():
		return false

	var profile := load_profile()
	if profile.is_empty():
		return false

	var cosmetics: Dictionary = profile.get("owned_cosmetics", {})
	return bool(cosmetics.get(cosmetic_id, false))


static func attach_linked_account(
	provider: String,
	external_account_id: String
) -> Dictionary:
	var profile := load_profile()
	if profile.is_empty():
		return {}
	if provider.strip_edges().is_empty() or external_account_id.strip_edges().is_empty():
		return {}

	profile["account_type"] = "linked"
	profile["linked_provider"] = provider.strip_edges()
	profile["linked_account_id"] = external_account_id.strip_edges()
	if not _save_profile(profile):
		return {}
	return profile


static func validate_airport_name(value: String) -> Dictionary:
	var cleaned := value.strip_edges()
	if cleaned.length() < 3:
		return {"valid": false, "message": "Airport name needs at least 3 characters."}
	if cleaned.length() > 24:
		return {"valid": false, "message": "Airport name can be at most 24 characters."}
	if cleaned.contains("\n") or cleaned.contains("\r") or cleaned.contains("\t"):
		return {"valid": false, "message": "Airport name contains unsupported characters."}
	if cleaned.begins_with("-") or cleaned.ends_with("-"):
		return {"valid": false, "message": "Airport name cannot start or end with a dash."}
	return {"valid": true, "message": "Airport name ready."}


static func validate_airport_code(value: String) -> Dictionary:
	var cleaned := value.strip_edges().to_upper()
	if cleaned.length() != 3:
		return {"valid": false, "message": "Airport code must contain exactly 3 letters or numbers."}

	var matcher := RegEx.new()
	matcher.compile("^[A-Z0-9]{3}$")
	if matcher.search(cleaned) == null:
		return {"valid": false, "message": "Airport code can only use A-Z and 0-9."}
	return {"valid": true, "message": "Airport code ready."}


static func suggest_airport_code(airport_name: String) -> String:
	var matcher := RegEx.new()
	matcher.compile("[A-Za-z0-9]")
	var code := ""
	var offset := 0
	while code.length() < 3:
		var result := matcher.search(airport_name, offset)
		if result == null:
			break
		code += result.get_string().to_upper()
		offset = result.get_end()
	while code.length() < 3:
		code += "X"
	return code.left(3)


static func _save_profile(profile: Dictionary) -> bool:
	var config := ConfigFile.new()
	for key in profile.keys():
		config.set_value("profile", String(key), profile[key])
	return config.save(SAVE_PATH) == OK


static func _make_token(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s-%d-%d" % [
		prefix,
		int(Time.get_unix_time_from_system()),
		rng.randi()
	]
