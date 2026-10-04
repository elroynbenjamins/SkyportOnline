class_name PassengerEconomy
extends Node

signal changed(snapshot: Dictionary)
signal building_changed(uid: int, state: Dictionary)
signal rewarded_ad_claimed(amount: int)
signal friend_gift_claimed(friend_id: String, amount: int)

const STARTING_PASSENGERS := 54
const AD_REWARD := 25
const AD_DAILY_LIMIT := 3
const FRIEND_GIFT_AMOUNT := 5
const FRIEND_RECEIVE_DAILY_CAP := 50

const RATE_MULTIPLIERS := [1.0, 1.15, 1.35, 1.60]
const STORAGE_MULTIPLIERS := [1.0, 1.25, 1.60, 2.10]
const TERMINAL_CAPACITY_MULTIPLIERS := [1.0, 1.45, 2.10, 3.00]

var passengers := STARTING_PASSENGERS
var terminal_capacity := 120

var building_states: Dictionary = {}
var country_resources: Dictionary = {}

var ad_uses_today := 0
var received_friend_passengers_today := 0
var received_friend_ids: Dictionary = {}
var sent_friend_ids: Dictionary = {}
var day_key := ""

var _tick_accumulator := 0.0


func _ready() -> void:
	_reset_daily_state_if_needed()
	set_process(true)


func _process(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < 1.0:
		return
	var elapsed := _tick_accumulator
	_tick_accumulator = 0.0
	advance_time(elapsed)


func configure_from_airport(airport_grid: Node) -> void:
	building_states.clear()
	if airport_grid != null and airport_grid.has_method("get_placed_buildings"):
		for building in airport_grid.get_placed_buildings():
			register_building(
				int(building.get("uid", -1)),
				String(building.get("definition_id", ""))
			)
	_recalculate_terminal_capacity()
	passengers = mini(passengers, terminal_capacity)
	_emit_changed()


func register_building(uid: int, definition_id: String) -> void:
	if uid < 0 or definition_id.is_empty():
		return

	var definition := BuildingCatalog.get_definition(definition_id)
	if definition.is_empty():
		return

	var is_terminal := int(definition.get("passenger_capacity", 0)) > 0
	var is_producer := not String(definition.get("passenger_mode", "")).is_empty()
	if not is_terminal and not is_producer:
		return

	if building_states.has(uid):
		return

	building_states[uid] = {
		"uid": uid,
		"definition_id": definition_id,
		"upgrade_level": 1,
		"stored": 0,
		"progress_seconds": 0.0
	}
	_recalculate_terminal_capacity()
	_emit_changed()


func unregister_building(uid: int) -> void:
	if not building_states.has(uid):
		return
	building_states.erase(uid)
	_recalculate_terminal_capacity()
	passengers = mini(passengers, terminal_capacity)
	_emit_changed()


func advance_time(seconds: float) -> void:
	if seconds <= 0.0:
		return

	_reset_daily_state_if_needed()
	var any_change := false

	for uid_variant in building_states.keys():
		var uid := int(uid_variant)
		var state: Dictionary = building_states[uid]
		var definition := BuildingCatalog.get_definition(String(state["definition_id"]))
		var mode := String(definition.get("passenger_mode", ""))
		if mode.is_empty():
			continue

		var base_cycle := float(definition.get("passenger_cycle_seconds", 0.0))
		var base_yield := int(definition.get("passenger_yield", 0))
		var base_storage := int(definition.get("passenger_storage", 0))
		if base_cycle <= 0.0 or base_yield <= 0 or base_storage <= 0:
			continue

		var level := int(state.get("upgrade_level", 1))
		var rate_multiplier := _rate_multiplier(level)
		var storage_cap := maxi(
			1,
			roundi(float(base_storage) * _storage_multiplier(level))
		)
		var cycle := base_cycle / rate_multiplier
		var stored := int(state.get("stored", 0))
		var progress := float(state.get("progress_seconds", 0.0)) + seconds

		if stored >= storage_cap:
			progress = minf(progress, cycle)
		else:
			while progress >= cycle and stored < storage_cap:
				progress -= cycle
				stored = mini(storage_cap, stored + base_yield)
				any_change = true

		state["stored"] = stored
		state["progress_seconds"] = progress
		building_states[uid] = state

		if any_change:
			building_changed.emit(uid, get_building_state(uid))

	if any_change:
		_emit_changed()


func collect_from_building(uid: int) -> int:
	if not building_states.has(uid):
		return 0
	if passengers >= terminal_capacity:
		return 0

	var state: Dictionary = building_states[uid]
	var stored := int(state.get("stored", 0))
	if stored <= 0:
		return 0

	var amount := mini(stored, terminal_capacity - passengers)
	passengers += amount
	state["stored"] = stored - amount
	building_states[uid] = state
	building_changed.emit(uid, get_building_state(uid))
	_emit_changed()
	return amount


func collect_all() -> int:
	var total := 0
	for uid_variant in building_states.keys():
		if passengers >= terminal_capacity:
			break
		total += collect_from_building(int(uid_variant))
	return total


func can_spend_passengers(amount: int) -> bool:
	return amount >= 0 and passengers >= amount


func try_spend_passengers(amount: int) -> bool:
	if amount <= 0:
		return true
	if passengers < amount:
		return false
	passengers -= amount
	_emit_changed()
	return true


func add_passengers(amount: int) -> int:
	if amount <= 0 or passengers >= terminal_capacity:
		return 0
	var granted := mini(amount, terminal_capacity - passengers)
	passengers += granted
	_emit_changed()
	return granted


func claim_rewarded_ad() -> int:
	_reset_daily_state_if_needed()
	if ad_uses_today >= AD_DAILY_LIMIT:
		return 0
	if passengers >= terminal_capacity:
		return 0

	ad_uses_today += 1
	var granted := add_passengers(AD_REWARD)
	rewarded_ad_claimed.emit(granted)
	_emit_changed()
	return granted


func claim_friend_gift(friend_id: String) -> int:
	_reset_daily_state_if_needed()
	var clean_id := friend_id.strip_edges()
	if clean_id.is_empty():
		return 0
	if received_friend_ids.has(clean_id):
		return 0
	if received_friend_passengers_today >= FRIEND_RECEIVE_DAILY_CAP:
		return 0
	if passengers >= terminal_capacity:
		return 0

	var remaining_daily := FRIEND_RECEIVE_DAILY_CAP - received_friend_passengers_today
	var wanted := mini(FRIEND_GIFT_AMOUNT, remaining_daily)
	var granted := add_passengers(wanted)
	if granted <= 0:
		return 0

	received_friend_ids[clean_id] = true
	received_friend_passengers_today += granted
	friend_gift_claimed.emit(clean_id, granted)
	_emit_changed()
	return granted


func can_send_friend_gift(friend_id: String) -> bool:
	_reset_daily_state_if_needed()
	var clean_id := friend_id.strip_edges()
	return not clean_id.is_empty() and not sent_friend_ids.has(clean_id)


func mark_friend_gift_sent(friend_id: String) -> bool:
	if not can_send_friend_gift(friend_id):
		return false
	sent_friend_ids[friend_id.strip_edges()] = true
	_emit_changed()
	return true


func grant_country_resource(resource_id: String, amount: int) -> void:
	if resource_id.is_empty() or amount <= 0:
		return
	country_resources[resource_id] = int(country_resources.get(resource_id, 0)) + amount
	_emit_changed()


func get_country_resource_amount(resource_id: String) -> int:
	return int(country_resources.get(resource_id, 0))


func get_upgrade_quote(uid: int) -> Dictionary:
	if not building_states.has(uid):
		return {}

	var state: Dictionary = building_states[uid]
	var definition := BuildingCatalog.get_definition(String(state["definition_id"]))
	var current_level := int(state.get("upgrade_level", 1))
	var costs: Array = definition.get("passenger_upgrade_costs", [])
	if current_level >= RATE_MULTIPLIERS.size() or current_level >= costs.size() + 1:
		return {
			"uid": uid,
			"current_level": current_level,
			"max_level": current_level,
			"available": false,
			"reason": "MAX LEVEL"
		}

	var cost_index := current_level - 1
	if cost_index < 0 or cost_index >= costs.size():
		return {
			"uid": uid,
			"current_level": current_level,
			"available": false,
			"reason": "NO UPGRADE DATA"
		}

	var resource_costs: Dictionary = costs[cost_index]
	var can_afford := true
	for resource_id in resource_costs.keys():
		if get_country_resource_amount(String(resource_id)) < int(resource_costs[resource_id]):
			can_afford = false

	var next_level := current_level + 1
	var result := {
		"uid": uid,
		"definition_id": String(state["definition_id"]),
		"current_level": current_level,
		"next_level": next_level,
		"available": true,
		"can_afford": can_afford,
		"resource_costs": resource_costs.duplicate(true),
		"rate_multiplier": _rate_multiplier(next_level),
		"storage_multiplier": _storage_multiplier(next_level)
	}

	if int(definition.get("passenger_capacity", 0)) > 0:
		result["capacity_multiplier"] = _terminal_capacity_multiplier(next_level)
	return result


func try_upgrade_building(uid: int) -> bool:
	var quote := get_upgrade_quote(uid)
	if quote.is_empty() or not bool(quote.get("available", false)):
		return false
	if not bool(quote.get("can_afford", false)):
		return false

	var resource_costs: Dictionary = quote.get("resource_costs", {})
	for resource_id in resource_costs.keys():
		var id := String(resource_id)
		country_resources[id] = get_country_resource_amount(id) - int(resource_costs[resource_id])

	var state: Dictionary = building_states[uid]
	state["upgrade_level"] = int(quote["next_level"])
	building_states[uid] = state
	_recalculate_terminal_capacity()
	building_changed.emit(uid, get_building_state(uid))
	_emit_changed()
	return true


func get_building_state(uid: int) -> Dictionary:
	if not building_states.has(uid):
		return {}

	var state: Dictionary = building_states[uid].duplicate(true)
	var definition := BuildingCatalog.get_definition(String(state["definition_id"]))
	var level := int(state.get("upgrade_level", 1))
	var base_storage := int(definition.get("passenger_storage", 0))
	state["storage_capacity"] = roundi(float(base_storage) * _storage_multiplier(level))
	state["rate_multiplier"] = _rate_multiplier(level)
	state["upgrade_quote"] = get_upgrade_quote(uid)
	return state


func get_snapshot() -> Dictionary:
	_reset_daily_state_if_needed()
	var stored_total := 0
	var producers := 0
	for state_variant in building_states.values():
		var state: Dictionary = state_variant
		var definition := BuildingCatalog.get_definition(String(state["definition_id"]))
		if not String(definition.get("passenger_mode", "")).is_empty():
			producers += 1
			stored_total += int(state.get("stored", 0))

	return {
		"passengers": passengers,
		"capacity": terminal_capacity,
		"stored_waiting": stored_total,
		"producer_count": producers,
		"ad_reward": AD_REWARD,
		"ad_uses_today": ad_uses_today,
		"ad_daily_limit": AD_DAILY_LIMIT,
		"friend_gift_amount": FRIEND_GIFT_AMOUNT,
		"friend_received_today": received_friend_passengers_today,
		"friend_receive_cap": FRIEND_RECEIVE_DAILY_CAP,
		"country_resources": country_resources.duplicate(true)
	}


func _recalculate_terminal_capacity() -> void:
	var total := 0
	for state_variant in building_states.values():
		var state: Dictionary = state_variant
		var definition := BuildingCatalog.get_definition(String(state["definition_id"]))
		var base_capacity := int(definition.get("passenger_capacity", 0))
		if base_capacity <= 0:
			continue
		var level := int(state.get("upgrade_level", 1))
		total += roundi(float(base_capacity) * _terminal_capacity_multiplier(level))

	terminal_capacity = maxi(50, total if total > 0 else 120)


func _rate_multiplier(level: int) -> float:
	var index := clampi(level - 1, 0, RATE_MULTIPLIERS.size() - 1)
	return float(RATE_MULTIPLIERS[index])


func _storage_multiplier(level: int) -> float:
	var index := clampi(level - 1, 0, STORAGE_MULTIPLIERS.size() - 1)
	return float(STORAGE_MULTIPLIERS[index])


func _terminal_capacity_multiplier(level: int) -> float:
	var index := clampi(level - 1, 0, TERMINAL_CAPACITY_MULTIPLIERS.size() - 1)
	return float(TERMINAL_CAPACITY_MULTIPLIERS[index])


func _reset_daily_state_if_needed() -> void:
	var today := Time.get_date_string_from_system(false)
	if day_key == today:
		return

	day_key = today
	ad_uses_today = 0
	received_friend_passengers_today = 0
	received_friend_ids.clear()
	sent_friend_ids.clear()


func _emit_changed() -> void:
	changed.emit(get_snapshot())
