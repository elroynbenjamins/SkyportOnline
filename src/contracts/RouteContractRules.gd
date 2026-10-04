class_name RouteContractRules
extends RefCounted

const CONTRACT_WINDOW_SECONDS := 5400
const TARGET_FLIGHTS := 3


static func active_contract(
	player_level: int,
	airport_key: String = "",
	now_unix: int = -1
) -> Dictionary:
	var destinations := DestinationCatalog.unlocked_for_level(player_level)
	if destinations.is_empty():
		return {}

	var timestamp := now_unix
	if timestamp < 0:
		timestamp = int(Time.get_unix_time_from_system())

	var slot := floori(
		float(timestamp) / float(CONTRACT_WINDOW_SECONDS)
	)
	var offset := _stable_offset(airport_key)
	var destination: Dictionary = destinations[
		posmod(slot + offset, destinations.size())
	]

	var starts_at := slot * CONTRACT_WINDOW_SECONDS
	var ends_at := (slot + 1) * CONTRACT_WINDOW_SECONDS
	var destination_id := String(destination.get("id", ""))
	var country_code := String(destination.get("country_code", ""))
	var resources := CountryResourceCatalog.resources_for_country(
		country_code
	)

	var bonus_resources: Array[Dictionary] = []
	for index in range(resources.size()):
		var resource: Dictionary = resources[index]
		bonus_resources.append({
			"id": String(resource.get("id", "")),
			"name": String(resource.get("name", "Resource")),
			"amount": 2 if index == 0 else 1
		})

	return {
		"id": "priority_%d_%s" % [slot, destination_id],
		"slot": slot,
		"destination_id": destination_id,
		"city": String(destination.get("city", "")),
		"country": String(destination.get("country", "")),
		"country_code": country_code,
		"target_flights": TARGET_FLIGHTS,
		"starts_at_unix": starts_at,
		"ends_at_unix": ends_at,
		"remaining_seconds": maxi(ends_at - timestamp, 0),
		"bonus_coins": maxi(
			int(round(
				float(destination.get("coin_reward", 0)) * 2.0
			)),
			500
		),
		"bonus_xp": maxi(
			int(round(
				float(destination.get("xp_reward", 0)) * 2.0
			)),
			50
		),
		"bonus_resources": bonus_resources
	}


static func apply_to_flight_plan(
	flight_plan: Dictionary,
	contract: Dictionary,
	progress_state: Dictionary = {}
) -> Dictionary:
	if flight_plan.is_empty() or contract.is_empty():
		return flight_plan.duplicate(true)

	if String(flight_plan.get("destination_id", "")) != String(
		contract.get("destination_id", "")
	):
		return flight_plan.duplicate(true)

	if bool(progress_state.get("completed", false)):
		return flight_plan.duplicate(true)

	var result := flight_plan.duplicate(true)
	result["priority_contract_id"] = String(contract.get("id", ""))
	result["priority_contract_destination_id"] = String(
		contract.get("destination_id", "")
	)
	result["priority_contract_ends_at_unix"] = int(
		contract.get("ends_at_unix", 0)
	)
	result["priority_contract_target_flights"] = int(
		contract.get("target_flights", TARGET_FLIGHTS)
	)
	result["priority_contract_bonus_coins"] = int(
		contract.get("bonus_coins", 0)
	)
	result["priority_contract_bonus_xp"] = int(
		contract.get("bonus_xp", 0)
	)
	result["priority_contract_bonus_resources"] = (
		contract.get("bonus_resources", []) as Array
	).duplicate(true)
	return result


static func progress_for(
	contract: Dictionary,
	progress_map: Dictionary
) -> Dictionary:
	if contract.is_empty():
		return {}

	var contract_id := String(contract.get("id", ""))
	var saved: Dictionary = progress_map.get(
		contract_id,
		{}
	).duplicate(true)
	var target := int(
		contract.get("target_flights", TARGET_FLIGHTS)
	)
	var progress := clampi(
		int(saved.get("progress", 0)),
		0,
		target
	)
	var completed := bool(
		saved.get("completed", progress >= target)
	)
	return {
		"contract_id": contract_id,
		"progress": progress,
		"target": target,
		"completed": completed
	}


static func is_flight_eligible(
	flight_plan: Dictionary,
	now_unix: int = -1
) -> bool:
	var contract_id := String(
		flight_plan.get("priority_contract_id", "")
	)
	if contract_id.is_empty():
		return false

	var timestamp := now_unix
	if timestamp < 0:
		timestamp = int(Time.get_unix_time_from_system())

	return timestamp <= int(
		flight_plan.get("priority_contract_ends_at_unix", 0)
	)


static func format_resource_bundle(resources: Array) -> String:
	var parts: Array[String] = []
	for resource in resources:
		parts.append("%dx %s" % [
			int(resource.get("amount", 1)),
			String(resource.get("name", "Resource"))
		])
	return " • ".join(parts)


static func _stable_offset(value: String) -> int:
	var total := 0
	for index in range(value.length()):
		total += value.unicode_at(index) * (index + 1)
	return total
