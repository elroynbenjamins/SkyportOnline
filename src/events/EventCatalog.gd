class_name EventCatalog
extends RefCounted

const EVENT_DURATION_DAYS := 21
const SECONDS_PER_DAY := 86400


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "autumn_airbridge_2026",
			"enabled": true,
			"name": "Autumn Airbridge",
			"short_name": "AUTUMN AIRBRIDGE",
			"currency_id": "autumn_voucher",
			"currency_name": "Autumn Vouchers",
			"start_unix": 1790812800,
			"theme": "autumn",
			"featured_destinations": [
				"brussels",
				"london",
				"paris"
			],
			"featured_route_currency": 5,
			"quests": [
				{
					"id": "autumn_w1_flights",
					"week": 1,
					"title": "Opening Airbridge",
					"metric": "flights_completed",
					"target": 5,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "autumn_w1_brussels",
					"week": 1,
					"title": "Brussels Harvest Shuttle",
					"metric": "destination_flights",
					"destination_id": "brussels",
					"target": 3,
					"currency_reward": 45,
					"alliance_points": 12
				},
				{
					"id": "autumn_w1_passengers",
					"week": 1,
					"title": "Autumn Travelers",
					"metric": "passengers_boarded",
					"target": 40,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "autumn_w1_resources",
					"week": 1,
					"title": "Harvest Cargo",
					"metric": "resources_earned",
					"target": 4,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "autumn_w2_london",
					"week": 2,
					"title": "London Leaflift",
					"metric": "destination_flights",
					"destination_id": "london",
					"target": 5,
					"currency_reward": 55,
					"alliance_points": 15
				},
				{
					"id": "autumn_w2_passengers",
					"week": 2,
					"title": "Busy Autumn Terminals",
					"metric": "passengers_boarded",
					"target": 100,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "autumn_w2_coins",
					"week": 2,
					"title": "Golden Routes",
					"metric": "flight_coins",
					"target": 4500,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "autumn_w2_resources",
					"week": 2,
					"title": "Regional Supplies",
					"metric": "resources_earned",
					"target": 9,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "autumn_w3_paris",
					"week": 3,
					"title": "Paris Finale",
					"metric": "destination_flights",
					"destination_id": "paris",
					"target": 6,
					"currency_reward": 70,
					"alliance_points": 20
				},
				{
					"id": "autumn_w3_flights",
					"week": 3,
					"title": "Closing Airshow",
					"metric": "flights_completed",
					"target": 15,
					"currency_reward": 60,
					"alliance_points": 20
				},
				{
					"id": "autumn_w3_passengers",
					"week": 3,
					"title": "Finale Crowds",
					"metric": "passengers_boarded",
					"target": 180,
					"currency_reward": 60,
					"alliance_points": 20
				},
				{
					"id": "autumn_w3_resources",
					"week": 3,
					"title": "Grand Harvest",
					"metric": "resources_earned",
					"target": 14,
					"currency_reward": 60,
					"alliance_points": 20
				}
			],
			"shop": [
				{
					"id": "autumn_airport_border",
					"name": "Autumn Airport Border",
					"type": "cosmetic",
					"cosmetic_id": "event_autumn_airport_border",
					"price": 160,
					"purchase_limit": 1
				},
				{
					"id": "autumn_terminal_skin",
					"name": "Autumn Terminal Skin",
					"type": "cosmetic",
					"cosmetic_id": "event_autumn_terminal_skin",
					"price": 220,
					"purchase_limit": 1
				},
				{
					"id": "autumn_pico_livery",
					"name": "Harvest Pico Livery",
					"type": "cosmetic",
					"cosmetic_id": "event_autumn_pico_livery",
					"price": 260,
					"purchase_limit": 1
				},
				{
					"id": "autumn_alliance_flag",
					"name": "Autumn Alliance Flag",
					"type": "cosmetic",
					"cosmetic_id": "event_autumn_alliance_flag",
					"price": 180,
					"purchase_limit": 1
				},
				{
					"id": "autumn_passengers_25",
					"name": "+25 Passengers",
					"type": "passengers",
					"passengers": 25,
					"price": 25,
					"purchase_limit": 3
				},
				{
					"id": "autumn_passengers_75",
					"name": "+75 Passengers",
					"type": "passengers",
					"passengers": 75,
					"price": 60,
					"purchase_limit": 1
				}
			],
			"alliance": {
				"enabled": true,
				"milestones": [
					{
						"id": "autumn_alliance_150",
						"target": 150,
						"reward_type": "currency",
						"currency_reward": 50,
						"name": "Autumn Warm-Up"
					},
					{
						"id": "autumn_alliance_400",
						"target": 400,
						"reward_type": "cosmetic",
						"cosmetic_id": "event_autumn_alliance_emblem",
						"name": "Autumn Alliance Emblem"
					},
					{
						"id": "autumn_alliance_800",
						"target": 800,
						"reward_type": "currency",
						"currency_reward": 100,
						"name": "Autumn Night Flights"
					},
					{
						"id": "autumn_alliance_1400",
						"target": 1400,
						"reward_type": "currency",
						"currency_reward": 150,
						"name": "Autumn Grand Finale"
					}
				]
			}
		},
		{
			"id": "sky_lantern_festival_2026",
			"enabled": false,
			"name": "Sky Lantern Festival",
			"short_name": "LANTERN FESTIVAL",
			"currency_id": "lantern_ticket",
			"currency_name": "Lantern Tickets",
			"start_unix": 1793491200,
			"theme": "lantern",
			"quests": [
				{
					"id": "w1_flights",
					"week": 1,
					"title": "Opening Routes",
					"metric": "flights_completed",
					"target": 5,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "w1_passengers",
					"week": 1,
					"title": "Festival Arrivals",
					"metric": "passengers_boarded",
					"target": 40,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "w1_resources",
					"week": 1,
					"title": "Regional Decorations",
					"metric": "resources_earned",
					"target": 4,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "w1_coins",
					"week": 1,
					"title": "Opening Weekend",
					"metric": "flight_coins",
					"target": 1500,
					"currency_reward": 40,
					"alliance_points": 10
				},
				{
					"id": "w2_flights",
					"week": 2,
					"title": "Festival Network",
					"metric": "flights_completed",
					"target": 10,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "w2_passengers",
					"week": 2,
					"title": "Crowded Terminals",
					"metric": "passengers_boarded",
					"target": 100,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "w2_resources",
					"week": 2,
					"title": "Festival Supplies",
					"metric": "resources_earned",
					"target": 8,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "w2_coins",
					"week": 2,
					"title": "Busy Skies",
					"metric": "flight_coins",
					"target": 4000,
					"currency_reward": 50,
					"alliance_points": 15
				},
				{
					"id": "w3_flights",
					"week": 3,
					"title": "Closing Airshow",
					"metric": "flights_completed",
					"target": 15,
					"currency_reward": 60,
					"alliance_points": 20
				},
				{
					"id": "w3_passengers",
					"week": 3,
					"title": "Finale Crowds",
					"metric": "passengers_boarded",
					"target": 180,
					"currency_reward": 60,
					"alliance_points": 20
				},
				{
					"id": "w3_resources",
					"week": 3,
					"title": "Grand Decorations",
					"metric": "resources_earned",
					"target": 12,
					"currency_reward": 60,
					"alliance_points": 20
				},
				{
					"id": "w3_coins",
					"week": 3,
					"title": "Festival Finale",
					"metric": "flight_coins",
					"target": 8000,
					"currency_reward": 60,
					"alliance_points": 20
				}
			],
			"shop": [
				{
					"id": "lantern_airport_border",
					"name": "Lantern Airport Border",
					"type": "cosmetic",
					"cosmetic_id": "event_lantern_airport_border",
					"price": 150,
					"purchase_limit": 1
				},
				{
					"id": "lantern_terminal_skin",
					"name": "Lantern Terminal Skin",
					"type": "cosmetic",
					"cosmetic_id": "event_lantern_terminal_skin",
					"price": 220,
					"purchase_limit": 1
				},
				{
					"id": "lantern_pico_livery",
					"name": "Festival Pico Livery",
					"type": "cosmetic",
					"cosmetic_id": "event_lantern_pico_livery",
					"price": 260,
					"purchase_limit": 1
				},
				{
					"id": "lantern_alliance_flag",
					"name": "Lantern Flag",
					"type": "cosmetic",
					"cosmetic_id": "event_lantern_flag",
					"price": 180,
					"purchase_limit": 1
				},
				{
					"id": "passengers_25",
					"name": "+25 Passengers",
					"type": "passengers",
					"passengers": 25,
					"price": 25,
					"purchase_limit": 3
				},
				{
					"id": "passengers_75",
					"name": "+75 Passengers",
					"type": "passengers",
					"passengers": 75,
					"price": 60,
					"purchase_limit": 1
				}
			],
			"alliance": {
				"enabled": true,
				"milestones": [
					{
						"id": "alliance_150",
						"target": 150,
						"reward_type": "currency",
						"currency_reward": 50,
						"name": "Alliance Warm-Up"
					},
					{
						"id": "alliance_400",
						"target": 400,
						"reward_type": "cosmetic",
						"cosmetic_id": "event_lantern_alliance_emblem",
						"name": "Alliance Lantern Emblem"
					},
					{
						"id": "alliance_800",
						"target": 800,
						"reward_type": "currency",
						"currency_reward": 100,
						"name": "Alliance Night Flights"
					},
					{
						"id": "alliance_1400",
						"target": 1400,
						"reward_type": "currency",
						"currency_reward": 150,
						"name": "Alliance Grand Finale"
					}
				]
			}
		}
	]


static func get_event(event_id: String) -> Dictionary:
	for event in all():
		if String(event.get("id", "")) == event_id:
			return event.duplicate(true)
	return {}


static func active_events(now_unix: int = -1) -> Array[Dictionary]:
	var current := now_unix
	if current < 0:
		current = int(Time.get_unix_time_from_system())

	var result: Array[Dictionary] = []
	for event in all():
		if is_active(event, current):
			result.append(event.duplicate(true))
	return result


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	var seen_event_ids := {}

	for event in all():
		var event_id := String(event.get("id", ""))
		if event_id.is_empty():
			errors.append("Event is missing an id.")
			continue
		if seen_event_ids.has(event_id):
			errors.append("Duplicate event id: %s" % event_id)
		seen_event_ids[event_id] = true

		var quests: Array = event.get("quests", [])
		var seen_quest_ids := {}
		var weeks := {}
		for quest_variant in quests:
			var quest: Dictionary = quest_variant
			var quest_id := String(quest.get("id", ""))
			if quest_id.is_empty():
				errors.append("%s has a quest without an id." % event_id)
				continue
			if seen_quest_ids.has(quest_id):
				errors.append(
					"%s has duplicate quest id %s."
					% [event_id, quest_id]
				)
			seen_quest_ids[quest_id] = true

			var week := int(quest.get("week", 0))
			if week < 1 or week > 3:
				errors.append(
					"%s quest %s must use week 1, 2 or 3."
					% [event_id, quest_id]
				)
			else:
				weeks[week] = int(weeks.get(week, 0)) + 1

			if int(quest.get("target", 0)) <= 0:
				errors.append(
					"%s quest %s needs a positive target."
					% [event_id, quest_id]
				)
			if int(quest.get("currency_reward", 0)) < 0:
				errors.append(
					"%s quest %s has invalid currency reward."
					% [event_id, quest_id]
				)

		for week in range(1, 4):
			var quest_count := int(weeks.get(week, 0))
			if quest_count != 4:
				errors.append(
					"%s week %d must contain exactly 4 quests; found %d."
					% [event_id, week, quest_count]
				)

		var seen_shop_ids := {}
		var passenger_total := 0
		var passenger_item_count := 0
		var cosmetic_item_count := 0
		for item_variant in event.get("shop", []):
			var item: Dictionary = item_variant
			var item_id := String(item.get("id", ""))
			if item_id.is_empty():
				errors.append("%s has a shop item without an id." % event_id)
				continue
			if seen_shop_ids.has(item_id):
				errors.append(
					"%s has duplicate shop item id %s."
					% [event_id, item_id]
				)
			seen_shop_ids[item_id] = true

			var price := int(item.get("price", -1))
			if price < 0:
				errors.append(
					"%s shop item %s needs a non-negative price."
					% [event_id, item_id]
				)

			var raw_limit := int(item.get("purchase_limit", 0))
			if raw_limit <= 0:
				errors.append(
					"%s shop item %s needs a positive purchase limit."
					% [event_id, item_id]
				)
			var limit := maxi(raw_limit, 1)

			var item_type := String(item.get("type", ""))
			if item_type == "passengers":
				passenger_item_count += 1
				var passenger_amount := int(item.get("passengers", 0))
				if passenger_amount <= 0:
					errors.append(
						"%s passenger item %s needs a positive amount."
						% [event_id, item_id]
					)
				passenger_total += maxi(passenger_amount, 0) * limit
			elif item_type == "cosmetic":
				cosmetic_item_count += 1
				if String(item.get("cosmetic_id", "")).is_empty():
					errors.append(
						"%s cosmetic item %s needs a cosmetic_id."
						% [event_id, item_id]
					)
			else:
				errors.append(
					"%s shop item %s has unsupported type %s."
					% [event_id, item_id, item_type]
				)

		if cosmetic_item_count != 4:
			errors.append(
				"%s must contain exactly 4 event cosmetics; found %d."
				% [event_id, cosmetic_item_count]
			)
		if passenger_item_count != 2:
			errors.append(
				"%s must contain exactly 2 passenger shop items; found %d."
				% [event_id, passenger_item_count]
			)
		if passenger_total > 150:
			errors.append(
				"%s exceeds the standard 150 event-passenger cap."
				% event_id
			)

		var alliance: Dictionary = event.get("alliance", {})
		var last_target := -1
		var seen_milestones := {}
		for milestone_variant in alliance.get("milestones", []):
			var milestone: Dictionary = milestone_variant
			var milestone_id := String(milestone.get("id", ""))
			if milestone_id.is_empty():
				errors.append(
					"%s has an Alliance milestone without an id."
					% event_id
				)
				continue
			if seen_milestones.has(milestone_id):
				errors.append(
					"%s has duplicate Alliance milestone id %s."
					% [event_id, milestone_id]
				)
			seen_milestones[milestone_id] = true

			var target := int(milestone.get("target", 0))
			if target <= last_target:
				errors.append(
					"%s Alliance milestones must increase in target."
					% event_id
				)
			var reward_type := String(
				milestone.get("reward_type", "")
			)
			if reward_type == "currency":
				if int(milestone.get("currency_reward", 0)) <= 0:
					errors.append(
						"%s Alliance currency milestone %s needs a positive reward."
						% [event_id, milestone_id]
					)
			elif reward_type == "cosmetic":
				if String(milestone.get("cosmetic_id", "")).is_empty():
					errors.append(
						"%s Alliance cosmetic milestone %s needs a cosmetic_id."
						% [event_id, milestone_id]
					)
			else:
				errors.append(
					"%s Alliance milestone %s has unsupported reward type %s."
					% [event_id, milestone_id, reward_type]
				)

			last_target = target

		if (
			bool(alliance.get("enabled", false))
			and (alliance.get("milestones", []) as Array).size() != 4
		):
			errors.append(
				"%s enabled Alliance event must contain exactly 4 milestones."
				% event_id
			)

	var enabled_events: Array[Dictionary] = []
	for event in all():
		if bool(event.get("enabled", false)):
			enabled_events.append(event)

	for left_index in range(enabled_events.size()):
		for right_index in range(left_index + 1, enabled_events.size()):
			var left: Dictionary = enabled_events[left_index]
			var right: Dictionary = enabled_events[right_index]
			if _windows_overlap(left, right):
				errors.append(
					"Enabled event windows overlap: %s and %s."
					% [
						String(left.get("id", "")),
						String(right.get("id", ""))
					]
				)

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


static func total_personal_currency(event: Dictionary) -> int:
	var total := 0
	for quest_variant in event.get("quests", []):
		var quest: Dictionary = quest_variant
		total += maxi(int(quest.get("currency_reward", 0)), 0)
	return total


static func total_shop_passengers(event: Dictionary) -> int:
	var total := 0
	for item_variant in event.get("shop", []):
		var item: Dictionary = item_variant
		if String(item.get("type", "")) != "passengers":
			continue
		total += (
			maxi(int(item.get("passengers", 0)), 0)
			* maxi(int(item.get("purchase_limit", 1)), 1)
		)
	return total


static func total_alliance_currency(event: Dictionary) -> int:
	var total := 0
	var alliance: Dictionary = event.get("alliance", {})
	for milestone_variant in alliance.get("milestones", []):
		var milestone: Dictionary = milestone_variant
		if String(milestone.get("reward_type", "")) != "currency":
			continue
		total += maxi(
			int(milestone.get("currency_reward", 0)),
			0
		)
	return total


static func _windows_overlap(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_start := int(left.get("start_unix", 0))
	var right_start := int(right.get("start_unix", 0))
	if left_start <= 0 or right_start <= 0:
		return true

	var duration := EVENT_DURATION_DAYS * SECONDS_PER_DAY
	var left_end := left_start + duration
	var right_end := right_start + duration
	return left_start < right_end and right_start < left_end


static func active_event(now_unix: int = -1) -> Dictionary:
	var current := now_unix
	if current < 0:
		current = int(Time.get_unix_time_from_system())

	for event in all():
		if is_active(event, current):
			return event.duplicate(true)
	return {}


static func is_active(event: Dictionary, now_unix: int = -1) -> bool:
	if event.is_empty() or not bool(event.get("enabled", false)):
		return false

	var current := now_unix
	if current < 0:
		current = int(Time.get_unix_time_from_system())

	var start_unix := int(event.get("start_unix", 0))
	if start_unix <= 0:
		return true

	var end_unix := start_unix + EVENT_DURATION_DAYS * SECONDS_PER_DAY
	return current >= start_unix and current < end_unix


static func current_week(event: Dictionary, now_unix: int = -1) -> int:
	if event.is_empty():
		return 0

	var start_unix := int(event.get("start_unix", 0))
	if start_unix <= 0:
		return 1

	var current := now_unix
	if current < 0:
		current = int(Time.get_unix_time_from_system())
	if current < start_unix:
		return 0

	var elapsed_days := (current - start_unix) / SECONDS_PER_DAY
	return clampi(int(elapsed_days / 7) + 1, 1, 3)


static func days_remaining(event: Dictionary, now_unix: int = -1) -> int:
	if event.is_empty():
		return 0

	var start_unix := int(event.get("start_unix", 0))
	if start_unix <= 0:
		return EVENT_DURATION_DAYS

	var current := now_unix
	if current < 0:
		current = int(Time.get_unix_time_from_system())
	var end_unix := start_unix + EVENT_DURATION_DAYS * SECONDS_PER_DAY
	var remaining := maxi(end_unix - current, 0)
	return int(ceil(float(remaining) / float(SECONDS_PER_DAY)))


static func quest_by_id(event: Dictionary, quest_id: String) -> Dictionary:
	for quest in event.get("quests", []):
		if String(quest.get("id", "")) == quest_id:
			return (quest as Dictionary).duplicate(true)
	return {}


static func shop_item_by_id(event: Dictionary, item_id: String) -> Dictionary:
	for item in event.get("shop", []):
		if String(item.get("id", "")) == item_id:
			return (item as Dictionary).duplicate(true)
	return {}


static func alliance_milestone_by_id(
	event: Dictionary,
	milestone_id: String
) -> Dictionary:
	var alliance: Dictionary = event.get("alliance", {})
	for milestone in alliance.get("milestones", []):
		if String(milestone.get("id", "")) == milestone_id:
			return (milestone as Dictionary).duplicate(true)
	return {}
