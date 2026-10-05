class_name MissionPassCatalog
extends RefCounted

const TIERS := 30
const POINTS_PER_TIER := 100
const DAILY_MISSION_POINTS := 15
const DAILY_COMPLETION_BONUS := 10
const WEEKLY_MISSION_POINTS := 80
const WEEKLY_COMPLETION_BONUS := 100

static func daily_templates() -> Array[Dictionary]:
	return [
		{"id": "daily_flights", "metric": "flights", "title": "Keep Them Flying", "base_target": 3, "min_level": 1},
		{"id": "daily_passengers", "metric": "passengers", "title": "Passenger Push", "base_target": 30, "per_level": 5, "min_level": 1},
		{"id": "daily_countries", "metric": "unique_countries", "title": "International Hop", "base_target": 2, "min_level": 2},
		{"id": "daily_coins", "metric": "coins", "title": "Profitable Routes", "base_target": 600, "per_level": 150, "min_level": 1},
		{"id": "daily_xp", "metric": "xp", "title": "Airport Experience", "base_target": 30, "per_level": 10, "min_level": 1},
		{"id": "daily_passive_passengers", "metric": "passive_passengers", "title": "Fill the Terminal", "base_target": 10, "per_level": 2, "min_level": 1},
		{"id": "daily_npc", "metric": "npc_services", "title": "Welcome a Visitor", "base_target": 1, "min_level": 2},
		{"id": "daily_airtime", "metric": "flight_minutes", "title": "Time in the Air", "base_target": 10, "per_level": 1, "min_level": 1},
		{"id": "daily_distance", "metric": "flight_distance", "title": "Cover Some Ground", "base_target": 700, "per_level": 25, "min_level": 1},
		{"id": "daily_mastery", "metric": "mastery_minutes", "title": "Build Aircraft Mastery", "base_target": 120, "per_level": 10, "min_level": 2}
	]

static func weekly_templates() -> Array[Dictionary]:
	return [
		{"id": "weekly_flights", "metric": "flights", "title": "Busy Flight Board", "base_target": 25, "min_level": 1},
		{"id": "weekly_passengers", "metric": "passengers", "title": "Move the Crowds", "base_target": 250, "per_level": 35, "min_level": 1},
		{"id": "weekly_countries", "metric": "unique_countries", "title": "Route Explorer", "base_target": 4, "min_level": 2},
		{"id": "weekly_coins", "metric": "coins", "title": "Weekly Revenue", "base_target": 4500, "per_level": 900, "min_level": 1},
		{"id": "weekly_xp", "metric": "xp", "title": "Grow the Airport", "base_target": 300, "per_level": 60, "min_level": 1},
		{"id": "weekly_passive_passengers", "metric": "passive_passengers", "title": "Terminal Traffic", "base_target": 120, "per_level": 15, "min_level": 1},
		{"id": "weekly_npc", "metric": "npc_services", "title": "Visitor Week", "base_target": 5, "min_level": 2},
		{"id": "weekly_airtime", "metric": "flight_minutes", "title": "Flight-Hour Week", "base_target": 90, "per_level": 5, "min_level": 1},
		{"id": "weekly_distance", "metric": "flight_distance", "title": "Across the Network", "base_target": 5000, "per_level": 100, "min_level": 1},
		{"id": "weekly_mastery", "metric": "mastery_minutes", "title": "Fleet Familiarity", "base_target": 900, "per_level": 30, "min_level": 2},
		{"id": "weekly_resources", "metric": "resources", "title": "Import Run", "base_target": 6, "min_level": 2}
	]

static func target_for(template: Dictionary, level: int) -> int:
	return maxi(
		int(template.get("base_target", 1))
		+ maxi(level - 1, 0) * int(template.get("per_level", 0)),
		1
	)

static func mission_text(metric: String, target: int) -> String:
	match metric:
		"flights":
			return "Complete %d flights" % target
		"passengers":
			return "Transport %d passengers" % target
		"unique_countries":
			return "Complete flights to %d different countries" % target
		"coins":
			return "Earn %d coins from flights and visitors" % target
		"xp":
			return "Earn %d XP from flights and visitors" % target
		"npc_services":
			return "Successfully service %d NPC visitor%s" % [target, "" if target == 1 else "s"]
		"passive_passengers":
			return "Generate %d passengers from airport buildings" % target
		"flight_minutes":
			return "Complete %d minutes of scheduled flight time" % target
		"flight_distance":
			return "Fly a combined %d km" % target
		"mastery_minutes":
			return "Earn %d minutes toward aircraft Mastery" % target
		"resources":
			return "Bring home %d country resources from flights" % target
		_:
			return "Make progress: %d" % target

static func product_catalog() -> Array[Dictionary]:
	return [
		{"id": "aero_small", "title": "Aero Tokens • Small", "price_eur": 1.99, "price_label": "€1.99", "aero_tokens": 120},
		{"id": "aero_medium", "title": "Aero Tokens • Medium", "price_eur": 4.99, "price_label": "€4.99", "aero_tokens": 350},
		{"id": "aero_large", "title": "Aero Tokens • Large", "price_eur": 9.99, "price_label": "€9.99", "aero_tokens": 800},
		{"id": "airport_pass", "title": "Airport Pass", "price_eur": 4.99, "price_label": "€4.99", "premium_pass": true}
	]

static func product(product_id: String) -> Dictionary:
	for item in product_catalog():
		if String(item.get("id", "")) == product_id:
			return item.duplicate(true)
	return {}

static func pass_tiers() -> Array[Dictionary]:
	return [
		_tier(1, _reward("25 Passengers", {"passengers": 25}), _reward("50 Passengers", {"passengers": 50})),
		_tier(2, _reward("1,000 Coins", {"coins": 1000}), _reward("2,000 Coins", {"coins": 2000})),
		_tier(3, _reward("50 XP", {"xp": 50}), _reward("Ground Crew Booster", {"booster_ground_crew": 1})),
		_tier(4, _reward("Ground Crew Booster", {"booster_ground_crew": 1}), _reward("50 Passengers", {"passengers": 50})),
		_tier(5, _reward("2 Aero Tokens", {"aero_tokens": 2}), _reward("10 Aero Tokens", {"aero_tokens": 10})),
		_tier(6, _reward("35 Passengers", {"passengers": 35}), _reward("100 XP", {"xp": 100})),
		_tier(7, _reward("1,500 Coins", {"coins": 1500}), _reward("55 Passengers", {"passengers": 55})),
		_tier(8, _reward("Country Resource Crate", {"resource_crates": 1}), _reward("2 Country Resource Crates", {"resource_crates": 2})),
		_tier(9, _reward("75 XP", {"xp": 75}), _reward("Tailwind Booster", {"booster_tailwind": 1})),
		_tier(10, _reward("3 Aero Tokens", {"aero_tokens": 3}), _reward("60 Passengers + 10 Aero", {"passengers": 60, "aero_tokens": 10})),
		_tier(11, _reward("40 Passengers", {"passengers": 40}), _reward("3,000 Coins", {"coins": 3000})),
		_tier(12, _reward("2,000 Coins", {"coins": 2000}), _reward("Golden Routes Booster", {"booster_gold": 1})),
		_tier(13, _reward("Golden Routes Booster", {"booster_gold": 1}), _reward("60 Passengers", {"passengers": 60})),
		_tier(14, _reward("100 XP", {"xp": 100}), _reward("150 XP", {"xp": 150})),
		_tier(15, _reward("3 Aero Tokens", {"aero_tokens": 3}), _reward("10 Aero Tokens", {"aero_tokens": 10})),
		_tier(16, _reward("45 Passengers", {"passengers": 45}), _reward("65 Passengers", {"passengers": 65})),
		_tier(17, _reward("2,500 Coins", {"coins": 2500}), _reward("2 Country Resource Crates", {"resource_crates": 2})),
		_tier(18, _reward("Country Resource Crate", {"resource_crates": 1}), _reward("Flight School Booster", {"booster_xp": 1})),
		_tier(19, _reward("125 XP", {"xp": 125}), _reward("65 Passengers", {"passengers": 65})),
		_tier(20, _reward("4 Aero Tokens", {"aero_tokens": 4}), _reward("10 Aero + Tourism Rush", {"aero_tokens": 10, "booster_passengers": 1})),
		_tier(21, _reward("50 Passengers", {"passengers": 50}), _reward("5,000 Coins", {"coins": 5000})),
		_tier(22, _reward("3,000 Coins", {"coins": 3000}), _reward("70 Passengers", {"passengers": 70})),
		_tier(23, _reward("Flight School Booster", {"booster_xp": 1}), _reward("Ground Crew Booster", {"booster_ground_crew": 1})),
		_tier(24, _reward("Country Resource Crate", {"resource_crates": 1}), _reward("2 Country Resource Crates", {"resource_crates": 2})),
		_tier(25, _reward("5 Aero Tokens", {"aero_tokens": 5}), _reward("10 Aero Tokens", {"aero_tokens": 10})),
		_tier(26, _reward("55 Passengers", {"passengers": 55}), _reward("75 Passengers", {"passengers": 75})),
		_tier(27, _reward("4,000 Coins", {"coins": 4000}), _reward("Tailwind Booster", {"booster_tailwind": 1})),
		_tier(28, _reward("Ground Crew Booster", {"booster_ground_crew": 1}), _reward("75 Passengers", {"passengers": 75})),
		_tier(29, _reward("5 Aero Tokens", {"aero_tokens": 5}), _reward("10 Aero Tokens", {"aero_tokens": 10})),
		_tier(30, _reward("75 Passengers + Seasonal Decoration", {"passengers": 75, "cosmetic_free": 1}),
			_reward("75 Passengers + Premium Seasonal Set", {"passengers": 75, "cosmetic_premium": 1}))
	]

static func tier(tier_number: int) -> Dictionary:
	if tier_number < 1 or tier_number > TIERS:
		return {}
	return pass_tiers()[tier_number - 1].duplicate(true)

static func _tier(number: int, free_reward: Dictionary, premium_reward: Dictionary) -> Dictionary:
	return {"tier": number, "points": number * POINTS_PER_TIER, "free": free_reward, "premium": premium_reward}

static func _reward(label: String, grants: Dictionary) -> Dictionary:
	return {"label": label, "grants": grants}
