class_name SocialAirportService
extends Node

signal changed(snapshot: Dictionary)
signal visit_requested(request: Dictionary)
signal passenger_gift_sent(contact_id: String, amount: int)
signal passenger_gift_received(contact_id: String, amount: int)

var contacts: Array[Dictionary] = []
var active_visits: Dictionary = {}
var completed_visits: Array[Dictionary] = []
var provider_connected := false
var local_simulation_enabled := true
var sequence := 0

const MAX_ACTIVE_VISITS := 3


func configure(
	enable_local_simulation: bool = true
) -> void:
	local_simulation_enabled = enable_local_simulation
	if local_simulation_enabled:
		contacts = SocialContactCatalog.development_contacts()
	_emit_changed()


func set_provider_connected(value: bool) -> void:
	provider_connected = value
	_emit_changed()


func set_contacts(value: Array[Dictionary]) -> void:
	contacts = value.duplicate(true)
	_emit_changed()


func get_contact(contact_id: String) -> Dictionary:
	for contact in contacts:
		if String(contact.get("id", "")) == contact_id:
			return contact.duplicate(true)
	return {}


func request_visit(contact_id: String) -> Dictionary:
	var contact := get_contact(contact_id)
	if contact.is_empty():
		return {}
	if active_visits.size() >= MAX_ACTIVE_VISITS:
		return {}
	for entry_variant in active_visits.values():
		var entry: Dictionary = entry_variant
		var request: Dictionary = entry.get("request", {})
		if String(request.get("contact_id", "")) == contact_id:
			return {}
	sequence += 1
	var request := SocialFlightRules.create_visit_request(
		contact,
		sequence
	)
	if request.is_empty():
		return {}
	active_visits[String(request.get("visit_id", ""))] = {
		"request": request.duplicate(true),
		"aircraft": null,
		"status": "REQUESTED",
		"created_at_unix": int(Time.get_unix_time_from_system())
	}
	visit_requested.emit(request.duplicate(true))
	_emit_changed()
	return request


func register_visit_aircraft(
	visit_id: String,
	aircraft: AircraftPrototype
) -> void:
	if visit_id.is_empty() or not active_visits.has(visit_id):
		return
	var entry: Dictionary = active_visits[visit_id]
	entry["aircraft"] = aircraft
	entry["status"] = "INBOUND"
	active_visits[visit_id] = entry
	_emit_changed()


func update_visit_state(
	visit_id: String,
	state: String
) -> void:
	if visit_id.is_empty() or not active_visits.has(visit_id):
		return
	var entry: Dictionary = active_visits[visit_id]
	entry["status"] = state
	active_visits[visit_id] = entry
	_emit_changed()


func complete_visit(
	visit_id: String,
	host_reward: Dictionary,
	owner_reward: Dictionary
) -> void:
	if visit_id.is_empty() or not active_visits.has(visit_id):
		return
	var entry: Dictionary = active_visits[visit_id]
	var request: Dictionary = entry.get("request", {})
	var completed := {
		"visit_id": visit_id,
		"contact_id": String(request.get("contact_id", "")),
		"display_name": String(request.get("display_name", "Friend")),
		"airport_name": String(request.get("airport_name", "Friend Airport")),
		"country_id": String(request.get("country_id", "")),
		"relationship": String(request.get("relationship", "friend")),
		"host_reward": host_reward.duplicate(true),
		"owner_reward": owner_reward.duplicate(true),
		"completed_at_unix": int(Time.get_unix_time_from_system())
	}
	completed_visits.push_front(completed)
	while completed_visits.size() > 5:
		completed_visits.pop_back()
	active_visits.erase(visit_id)
	_emit_changed()


func send_passenger_gift(
	contact_id: String,
	day_key: String = ""
) -> bool:
	var contact := get_contact(contact_id)
	if contact.is_empty():
		return false
	var profile := ProfileStore.record_outgoing_friend_passenger_gift(
		contact_id,
		day_key
	)
	if profile.is_empty():
		return false
	passenger_gift_sent.emit(
		contact_id,
		PassengerSupportRules.friend_gift_amount()
	)
	_emit_changed()
	return true


func receive_passenger_gift(
	contact_id: String,
	economy: PassengerEconomy,
	day_key: String = ""
) -> int:
	if economy == null:
		return 0
	if economy.get_passengers() >= economy.get_capacity():
		return 0
	var profile := ProfileStore.record_friend_passenger_gift(
		day_key
	)
	if profile.is_empty():
		return 0
	var added := PassengerSupportRules.grant_friend_gift(
		economy
	)
	passenger_gift_received.emit(contact_id, added)
	_emit_changed()
	return added


func get_snapshot() -> Dictionary:
	var contact_rows: Array[Dictionary] = []
	for contact in contacts:
		var row := contact.duplicate(true)
		var gift := ProfileStore.get_outgoing_friend_gift_status(
			String(contact.get("id", ""))
		)
		row["gift_sent_today"] = bool(
			gift.get("sent_today", false)
		)
		row["can_send_gift"] = bool(
			gift.get("can_send", false)
		)
		contact_rows.append(row)

	var visits: Array[Dictionary] = []
	for visit_id_variant in active_visits.keys():
		var visit_id := String(visit_id_variant)
		var entry: Dictionary = active_visits[visit_id]
		var row: Dictionary = (
			entry.get("request", {}) as Dictionary
		).duplicate(true)
		var aircraft := entry.get("aircraft") as AircraftPrototype
		var state := String(entry.get("status", "REQUESTED"))
		if aircraft != null and is_instance_valid(aircraft):
			state = aircraft.state
		row["state"] = state
		row["visit_id"] = visit_id
		visits.append(row)

	var incoming_gift_status := ProfileStore.get_passenger_gift_status()
	return {
		"contacts": contact_rows,
		"active_visits": visits,
		"recent_completed": completed_visits.duplicate(true),
		"provider_connected": provider_connected,
		"local_simulation": local_simulation_enabled,
		"incoming_gift_status": incoming_gift_status,
		"social_state": ProfileStore.get_social_state(),
		"max_active_visits": MAX_ACTIVE_VISITS
	}


func _emit_changed() -> void:
	changed.emit(get_snapshot())
