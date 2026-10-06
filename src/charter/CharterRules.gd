class_name CharterRules
extends RefCounted

const UNLOCK_LEVEL := 22
const OFFER_COUNT := 3
const LOAD_SECONDS_PER_PALLET := 45
const MIN_ROUTE_SECONDS := 300

static func is_unlocked(level: int) -> bool:
	return level >= UNLOCK_LEVEL

static func ensure_state(state: Dictionary, level: int, unix_time: float) -> bool:
	var changed := false
	var charter: Dictionary = state.get("charter", {}).duplicate(true)
	if charter.is_empty():
		charter = {
			"offers": [],
			"active": {},
			"completed": 0,
			"serial": 0,
			"rotation_key": -1
		}
		changed = true
	if is_unlocked(level):
		var rotation_key := int(unix_time / 86400.0)
		if (charter.get("offers", []) as Array).is_empty() and (charter.get("active", {}) as Dictionary).is_empty():
			charter["offers"] = _generate_offers(level, rotation_key, int(charter.get("completed", 0)))
			charter["rotation_key"] = rotation_key
			changed = true
	state["charter"] = charter
	if advance(state, unix_time):
		changed = true
	return changed

static func accept_contract(
	state: Dictionary,
	offer_id: String,
	level: int,
	parcel_ready: bool,
	unix_time: float
) -> Dictionary:
	if not is_unlocked(level) or not parcel_ready or offer_id.is_empty():
		return {}
	var next := state.duplicate(true)
	ensure_state(next, level, unix_time)
	var charter: Dictionary = next.get("charter", {})
	if not (charter.get("active", {}) as Dictionary).is_empty():
		return {}
	var selected: Dictionary = {}
	var remaining: Array = []
	for offer_variant in charter.get("offers", []):
		var offer: Dictionary = offer_variant
		if String(offer.get("id", "")) == offer_id and selected.is_empty():
			selected = offer.duplicate(true)
		else:
			remaining.append(offer.duplicate(true))
	if selected.is_empty():
		return {}
	var serial := int(charter.get("serial", 0)) + 1
	var accepted_at := maxi(int(unix_time), 0)
	var load_seconds := maxi(int(selected.get("load_seconds", 0)), 1)
	var route_seconds := maxi(int(selected.get("route_seconds", 0)), 1)
	selected["contract_serial"] = serial
	selected["phase"] = "LOADING"
	selected["accepted_at"] = accepted_at
	selected["depart_at"] = accepted_at + load_seconds
	selected["complete_at"] = accepted_at + load_seconds + route_seconds
	selected["pallet_count"] = 0
	charter["serial"] = serial
	charter["active"] = selected
	charter["offers"] = remaining
	next["charter"] = charter
	return next

static func advance(state: Dictionary, unix_time: float) -> bool:
	var charter: Dictionary = state.get("charter", {})
	var active: Dictionary = charter.get("active", {})
	if active.is_empty():
		return false
	var now := maxi(int(unix_time), 0)
	var depart_at := int(active.get("depart_at", now))
	var complete_at := int(active.get("complete_at", depart_at))
	var old_phase := String(active.get("phase", "LOADING"))
	var old_pallets := int(active.get("pallet_count", 0))
	var phase := old_phase
	var pallets := old_pallets
	if now >= complete_at:
		phase = "READY"
		pallets = int(active.get("pallets", 1))
	elif now >= depart_at:
		phase = "EN_ROUTE"
		pallets = int(active.get("pallets", 1))
	else:
		phase = "LOADING"
		var accepted_at := int(active.get("accepted_at", now))
		var load_duration := maxi(depart_at - accepted_at, 1)
		var progress := clampf(float(now - accepted_at) / float(load_duration), 0.0, 0.999)
		pallets = clampi(int(floor(progress * float(int(active.get("pallets", 1)) + 1))), 0, int(active.get("pallets", 1)))
	if phase == old_phase and pallets == old_pallets:
		return false
	active["phase"] = phase
	active["pallet_count"] = pallets
	charter["active"] = active
	state["charter"] = charter
	return true

static func claim_contract(state: Dictionary, level: int, unix_time: float) -> Dictionary:
	var next := state.duplicate(true)
	ensure_state(next, level, unix_time)
	var charter: Dictionary = next.get("charter", {})
	var active: Dictionary = charter.get("active", {})
	if active.is_empty() or String(active.get("phase", "")) != "READY":
		return {}
	var reward := {
		"coins": int(active.get("coin_reward", 0)),
		"xp": int(active.get("xp_reward", 0)),
		"resource_id": String(active.get("resource_id", "")),
		"resource_name": String(active.get("resource_name", "")),
		"resource_amount": int(active.get("resource_amount", 1)),
		"city": String(active.get("city", "")),
		"country_code": String(active.get("country_code", ""))
	}
	next["coins"] = int(next.get("coins", 0)) + int(reward["coins"])
	next["xp"] = int(next.get("xp", 0)) + int(reward["xp"])
	var completed := int(charter.get("completed", 0)) + 1
	var grant_id := "%s:charter:%d" % [String(next.get("airport_id", "airport")), int(active.get("contract_serial", completed))]
	if not String(reward["resource_id"]).is_empty():
		var pending: Array = next.get("pending_resource_grants", []).duplicate(true)
		pending.append({
			"id": grant_id,
			"resource_id": String(reward["resource_id"]),
			"amount": maxi(int(reward["resource_amount"]), 1)
		})
		next["pending_resource_grants"] = pending
	charter["completed"] = completed
	charter["active"] = {}
	charter["offers"] = _generate_offers(level, int(unix_time / 86400.0), completed)
	charter["rotation_key"] = int(unix_time / 86400.0)
	next["charter"] = charter
	return {"state": next, "reward": reward}

static func snapshot(state: Dictionary, level: int, parcel_owned: bool, parcel_ready: bool, unix_time: float) -> Dictionary:
	var copy := state.duplicate(true)
	ensure_state(copy, level, unix_time)
	var charter: Dictionary = copy.get("charter", {})
	var active: Dictionary = (charter.get("active", {}) as Dictionary).duplicate(true)
	var remaining := 0
	if not active.is_empty():
		if String(active.get("phase", "")) == "LOADING":
			remaining = maxi(int(active.get("depart_at", 0)) - int(unix_time), 0)
		elif String(active.get("phase", "")) == "EN_ROUTE":
			remaining = maxi(int(active.get("complete_at", 0)) - int(unix_time), 0)
	active["remaining_seconds"] = remaining
	return {
		"unlocked": is_unlocked(level),
		"unlock_level": UNLOCK_LEVEL,
		"parcel_owned": parcel_owned,
		"parcel_ready": parcel_ready,
		"offers": (charter.get("offers", []) as Array).duplicate(true),
		"active": active,
		"completed": int(charter.get("completed", 0))
	}

static func visual_snapshot(state: Dictionary, level: int, parcel_owned: bool, unix_time: float) -> Dictionary:
	var charter: Dictionary = state.get("charter", {})
	var active: Dictionary = charter.get("active", {})
	var phase := String(active.get("phase", "IDLE"))
	return {
		"unlocked": is_unlocked(level),
		"turnaround_active": parcel_owned and not active.is_empty() and phase == "LOADING",
		"phase": phase,
		"pallet_count": int(active.get("pallet_count", 0)),
		"visual_variant": int(active.get("contract_serial", 0)) % 2
	}

static func _generate_offers(level: int, rotation_key: int, completed: int) -> Array[Dictionary]:
	var destinations := DestinationCatalog.unlocked_for_level(level)
	var result: Array[Dictionary] = []
	if destinations.is_empty():
		return result
	for slot in range(mini(OFFER_COUNT, destinations.size())):
		var destination: Dictionary = destinations[posmod(rotation_key + completed * 2 + slot * 2, destinations.size())]
		var resources := CountryResourceCatalog.resources_for_country(String(destination.get("country_code", "")))
		var resource: Dictionary = {}
		if not resources.is_empty():
			resource = resources[posmod(rotation_key + completed + slot, resources.size())]
		var pallets := 1 + posmod(rotation_key + completed + slot, 4)
		var distance := float(destination.get("distance_km", 200.0))
		var coin_reward := int(round(float(destination.get("coin_reward", 500)) * (1.35 + 0.22 * float(pallets))))
		var xp_reward := int(round(float(destination.get("xp_reward", 40)) * (0.85 + 0.12 * float(pallets))))
		result.append({
			"id": "charter:%d:%d:%s" % [rotation_key, slot, String(destination.get("id", "route"))],
			"destination_id": String(destination.get("id", "")),
			"city": String(destination.get("city", "")),
			"country": String(destination.get("country", "")),
			"country_code": String(destination.get("country_code", "")),
			"resource_id": String(resource.get("id", "")),
			"resource_name": String(resource.get("name", "Cargo")),
			"resource_amount": 1,
			"pallets": pallets,
			"load_seconds": pallets * LOAD_SECONDS_PER_PALLET,
			"route_seconds": maxi(int(round(distance * 1.5)), MIN_ROUTE_SECONDS),
			"coin_reward": coin_reward,
			"xp_reward": xp_reward
		})
	return result
