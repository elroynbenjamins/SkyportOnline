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
