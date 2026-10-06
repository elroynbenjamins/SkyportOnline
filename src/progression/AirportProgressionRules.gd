class_name AirportProgressionRules
extends RefCounted

const MAX_LEVEL := 30
const MAX_OWNED_AIRCRAFT := 16
const AIRCRAFT_PRICES := {
	"pico_p8": 1500, "swift_s14": 3500, "comet_c22": 8000,
	"voyager_v32": 16000, "nimbus_n40": 32000, "arrow_a52": 44000,
	"atlas_a64": 60000, "falcon_f72": 85000, "horizon_h88": 120000
}

static func xp_for_level(level: int) -> int:
	var bounded := clampi(level, 1, MAX_LEVEL)
	return 50 * bounded * (bounded - 1)

static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level

static func new_state(airport_id: String, legacy_level: int = 1) -> Dictionary:
	return {
		"version": 1, "airport_id": airport_id, "coins": 18420,
		"xp": xp_for_level(legacy_level), "gems": 0, "aero_tokens": 0, "passenger_balance": 20.0,
		"booster_inventory": {}, "active_boosters": {}, "resource_choice_crates": 0, "pass_cosmetics": {},
		"activity_tutorials_seen": {}, "activity_mission_enabled": {},
		"claimed": {}, "progress": {}, "seen_events": {}, "tour_countries": {},
		"pending_passengers": 0, "npc_seen": {}, "npc_serviced": 0,
		"friendships": {}, "npc_remaining": 90.0, "npc_last": "",
		"serial": 2, "flight_sequence": 0,
		"owned_aircraft": [
			{"uid": "owned-1", "type": "pico_p8"},
			{"uid": "owned-2", "type": "pico_p8"}
		]
	}

static func active_quest(state: Dictionary) -> Dictionary:
	return AirportCareerCatalog.current(state.get("claimed", {}))

static func record_event(state: Dictionary, event: Dictionary, level: int) -> bool:
	# Only internal successful-return/departure events may reach this function.
	var event_id := String(event.get("id", ""))
	var kind := String(event.get("kind", ""))
	if event_id.is_empty() or kind not in ["flight_return", "npc_service"]:
		return false
	var seen: Dictionary = state.get("seen_events", {})
	if seen.has(event_id):
		return false
	seen[event_id] = true
	# Active runtime flight tokens are never recycled; retain a bounded local audit window.
	while seen.size() > 2048:
		seen.erase(seen.keys()[0])
	state["seen_events"] = seen
	if kind == "npc_service":
		state["npc_serviced"] = int(state.get("npc_serviced", 0)) + 1
		var npc_seen: Dictionary = state.get("npc_seen", {})
		var npc_id := String(event.get("npc_id", ""))
		if not npc_id.is_empty():
			npc_seen[npc_id] = int(npc_seen.get(npc_id, 0)) + 1
		state["npc_seen"] = npc_seen

	var quest := active_quest(state)
	if quest.is_empty() or level < int(quest.get("level", 1)):
		return true
	var objective: Dictionary = quest.get("objective", {})
	var objective_kind := String(objective.get("kind", ""))
	var matches := false
	if kind == "npc_service" and objective_kind == "npc_service":
		matches = not objective.has("size") or String(event.get("size", "")) == String(objective["size"])
	elif kind == "flight_return" and objective_kind in ["flight", "countries"]:
		if bool(event.get("visitor", false)):
			return true
		var country := String(event.get("country", ""))
		var aircraft := String(event.get("aircraft", ""))
		if CountryCatalog.get_country(country).is_empty() or AircraftCatalog.get_profile(aircraft).is_empty():
			return true
		matches = aircraft == String(objective.get("aircraft", ""))
		if objective_kind == "flight":
			matches = matches and country == String(objective.get("country", ""))
		elif matches:
			var tours: Dictionary = state.get("tour_countries", {})
			var countries: Dictionary = tours.get(quest["id"], {})
			matches = not countries.has(country)
			countries[country] = true
			tours[quest["id"]] = countries
			state["tour_countries"] = tours
	if matches:
		var progress: Dictionary = state.get("progress", {})
		progress[quest["id"]] = mini(int(progress.get(quest["id"], 0)) + 1, int(objective.get("target", 1)))
		state["progress"] = progress
	return true

static func quest_status(state: Dictionary, airport: Dictionary, level: int) -> Dictionary:
	var quest := active_quest(state)
	if quest.is_empty():
		return {"complete": true, "ready": false, "quest": {}}
	var objective: Dictionary = quest.get("objective", {})
	var target := maxi(int(objective.get("target", 1)), 1)
	var count := int((state.get("progress", {}) as Dictionary).get(quest["id"], 0))
	match String(objective.get("kind", "")):
		"own_aircraft":
			count = 0
			for entry in state.get("owned_aircraft", []):
				if String(entry.get("type", "")) == String(objective.get("aircraft", "")):
					count += 1
		"building":
			count = 0
			for building in airport.get("buildings", []):
				if String(building.get("definition_id", "")) == String(objective.get("building", "")):
					if int(building.get("upgrade_level", 1)) >= int(objective.get("upgrade_level", 1)):
						count += 1
		"parcel":
			count = 1 if (airport.get("parcels", []) as Array).has(String(objective.get("parcel", ""))) else 0
		"regional_ready":
			count = 1 if bool(airport.get("medium_ready", false)) else 0
	return {"complete": false, "quest": quest, "count": mini(count, target), "target": target,
		"locked": level < int(quest.get("level", 1)),
		"ready": count >= target and level >= int(quest.get("level", 1))}

static func claim(state: Dictionary, quest_id: String, airport: Dictionary, level: int) -> Dictionary:
	var status := quest_status(state, airport, level)
	var quest: Dictionary = status.get("quest", {})
	if quest.is_empty() or String(quest.get("id", "")) != quest_id or not bool(status.get("ready", false)):
		return {}
	var next := state.duplicate(true)
	var claimed: Dictionary = next.get("claimed", {})
	if bool(claimed.get(quest_id, false)):
		return {}
	claimed[quest_id] = true
	next["claimed"] = claimed
	next["xp"] = int(next.get("xp", 0)) + maxi(int(quest.get("xp", 0)), 0)
	# Passenger rewards are never discarded when storage is full.
	next["pending_passengers"] = int(next.get("pending_passengers", 0)) + maxi(int(quest.get("passengers", 0)), 0)
	return next

static func purchase_aircraft(state: Dictionary, aircraft_id: String, level: int) -> Dictionary:
	var profile := AircraftCatalog.get_profile(aircraft_id)
	if profile.is_empty() or not AIRCRAFT_PRICES.has(aircraft_id):
		return {}
	if level < int(profile.get("unlock_level", 1)):
		return {}
	var fleet: Array = state.get("owned_aircraft", [])
	var cost := int(AIRCRAFT_PRICES[aircraft_id])
	if fleet.size() >= MAX_OWNED_AIRCRAFT or int(state.get("coins", 0)) < cost:
		return {}
	var next := state.duplicate(true)
	var serial := int(next.get("serial", 2)) + 1
	var next_fleet: Array = next.get("owned_aircraft", [])
	next_fleet.append({"uid": "owned-%d" % serial, "type": aircraft_id})
	next["owned_aircraft"] = next_fleet
	next["serial"] = serial
	next["coins"] = int(next.get("coins", 0)) - cost
	return next
