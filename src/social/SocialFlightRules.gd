class_name SocialFlightRules
extends RefCounted

const RESOURCE_CHANCE := 0.40
const FRIEND_COIN_MULTIPLIER := 1.0
const ALLIANCE_COIN_MULTIPLIER := 1.10
const FRIEND_XP_MULTIPLIER := 1.0
const ALLIANCE_XP_MULTIPLIER := 1.10


static func create_visit_request(
	contact: Dictionary,
	sequence: int = 0
) -> Dictionary:
	if contact.is_empty():
		return {}
	var aircraft_type_id := String(
		contact.get("aircraft_type_id", "pico_p8")
	)
	var profile := AircraftCatalog.get_profile(aircraft_type_id)
	if profile.is_empty():
		return {}

	var contact_id := String(contact.get("id", ""))
	if contact_id.is_empty():
		return {}

	return {
		"visit_id": "visit-%s-%d-%d" % [
			contact_id,
			int(Time.get_unix_time_from_system()),
			maxi(sequence, 0)
		],
		"contact_id": contact_id,
		"display_name": String(
			contact.get("display_name", "Friend")
		),
		"airport_name": String(
			contact.get("airport_name", "Friend Airport")
		),
		"airport_code": String(
			contact.get("airport_code", "FRD")
		),
		"country_id": String(contact.get("country_id", "")),
		"relationship": String(
			contact.get("relationship", "friend")
		),
		"alliance_tag": String(
			contact.get("alliance_tag", "")
		),
		"aircraft_type_id": aircraft_type_id,
		"aircraft_name": String(
			profile.get("name", aircraft_type_id)
		),
		"size": String(profile.get("size", "S")),
		"system_contact": bool(
			contact.get("system_contact", false)
		)
	}


static func create_social_flight_plan(
	request: Dictionary
) -> Dictionary:
	if request.is_empty():
		return {}
	var country_id := String(request.get("country_id", ""))
	var country := CountryCatalog.get_country(country_id)
	var airport_name := String(
		request.get("airport_name", "Friend Airport")
	)
	return {
		"destination_id": "social_return_%s" % String(
			request.get("contact_id", "")
		),
		"city": airport_name,
		"country": String(
			country.get("name", country_id)
		),
		"country_code": country_id,
		"duration_seconds": 60.0,
		"flight_hours": 0.0,
		"coin_reward": 0,
		"xp_reward": 0,
		"social_visit": true,
		"social_return": true,
		"social_contact_id": String(
			request.get("contact_id", "")
		),
		"social_visit_id": String(
			request.get("visit_id", "")
		)
	}


static func create_host_reward(
	aircraft_profile: Dictionary,
	request: Dictionary,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if aircraft_profile.is_empty() or request.is_empty():
		return {}

	var seats := maxi(
		int(aircraft_profile.get("passengers", 8)),
		1
	)
	var relationship := String(
		request.get("relationship", "friend")
	)
	var coin_multiplier := (
		ALLIANCE_COIN_MULTIPLIER
		if relationship == "alliance"
		else FRIEND_COIN_MULTIPLIER
	)
	var xp_multiplier := (
		ALLIANCE_XP_MULTIPLIER
		if relationship == "alliance"
		else FRIEND_XP_MULTIPLIER
	)
	var coins := int(round(
		float(90 + seats * 5) * coin_multiplier
	))
	var xp := int(round(
		float(8 + ceili(float(seats) / 10.0) * 2)
		* xp_multiplier
	))

	var country_id := String(request.get("country_id", ""))
	var rolls: Array[Dictionary] = []
	var resources_won: Array[Dictionary] = []
	if CountryResourceCatalog.resources_for_country(
		country_id
	).size() == 3:
		var active_rng := rng
		if active_rng == null:
			active_rng = RandomNumberGenerator.new()
			active_rng.randomize()
		var raw_rolls: Array[float] = []
		for _index in range(3):
			raw_rolls.append(active_rng.randf())
		rolls = ResourceDropRules.evaluate_resources(
			country_id,
			raw_rolls,
			RESOURCE_CHANCE
		)
		for result in rolls:
			if bool(result.get("success", false)):
				resources_won.append({
					"id": String(result.get("id", "")),
					"name": String(result.get("name", "")),
					"amount": int(result.get("amount", 1))
				})

	return {
		"coins": coins,
		"xp": xp,
		"country_id": country_id,
		"resource_chance": RESOURCE_CHANCE,
		"resource_rolls": rolls,
		"resources_won": resources_won,
		"relationship": relationship
	}


static func create_owner_reward(
	aircraft_profile: Dictionary,
	request: Dictionary
) -> Dictionary:
	if aircraft_profile.is_empty() or request.is_empty():
		return {}
	var seats := maxi(
		int(aircraft_profile.get("passengers", 8)),
		1
	)
	var relationship := String(
		request.get("relationship", "friend")
	)
	var multiplier := 1.10 if relationship == "alliance" else 1.0
	return {
		"coins": int(round(float(60 + seats * 4) * multiplier)),
		"xp": int(round(float(6 + ceili(float(seats) / 12.0) * 2) * multiplier)),
		"relationship": relationship
	}


static func reward_summary(reward: Dictionary) -> String:
	if reward.is_empty():
		return "No reward"
	var resources: Array = reward.get("resources_won", [])
	return "🪙 %d • XP %d • %d resource%s" % [
		int(reward.get("coins", 0)),
		int(reward.get("xp", 0)),
		resources.size(),
		"" if resources.size() == 1 else "s"
	]
