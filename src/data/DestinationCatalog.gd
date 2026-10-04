class_name DestinationCatalog
extends RefCounted

# Development origin only. The airport-creation flow will replace this with
# the player's selected home country / airport.
const DEVELOPMENT_HOME_NAME := "Amsterdam"

const COUNTRY_RESOURCES := {
	"BE": [
		{"id": "be_composite_panels", "name": "Composite Panels", "drop_chance": 0.40},
		{"id": "be_glass_fittings", "name": "Glass Fittings", "drop_chance": 0.40},
		{"id": "be_logistics_tags", "name": "Logistics Tags", "drop_chance": 0.40}
	],
	"GB": [
		{"id": "gb_terminal_signage", "name": "Terminal Signage", "drop_chance": 0.40},
		{"id": "gb_service_parts", "name": "Service Parts", "drop_chance": 0.40},
		{"id": "gb_aviation_textiles", "name": "Aviation Textiles", "drop_chance": 0.40}
	],
	"DE": [
		{"id": "de_precision_gears", "name": "Precision Gears", "drop_chance": 0.40},
		{"id": "de_steel_fasteners", "name": "Steel Fasteners", "drop_chance": 0.40},
		{"id": "de_control_relays", "name": "Control Relays", "drop_chance": 0.40}
	],
	"FR": [
		{"id": "fr_hospitality_linen", "name": "Hospitality Linen", "drop_chance": 0.40},
		{"id": "fr_glass_panels", "name": "Glass Panels", "drop_chance": 0.40},
		{"id": "fr_design_fixtures", "name": "Design Fixtures", "drop_chance": 0.40}
	],
	"DK": [
		{"id": "dk_timber_panels", "name": "Timber Panels", "drop_chance": 0.40},
		{"id": "dk_led_modules", "name": "LED Modules", "drop_chance": 0.40},
		{"id": "dk_modular_fittings", "name": "Modular Fittings", "drop_chance": 0.40}
	]
}


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "brussels",
			"city": "Brussels",
			"country": "Belgium",
			"country_code": "BE",
			"distance_km": 175.0,
			"unlock_level": 1,
			"coin_reward": 420,
			"xp_reward": 32,
			"map_position": Vector2(0.43, 0.59)
		},
		{
			"id": "london",
			"city": "London",
			"country": "United Kingdom",
			"country_code": "GB",
			"distance_km": 360.0,
			"unlock_level": 1,
			"coin_reward": 760,
			"xp_reward": 48,
			"map_position": Vector2(0.28, 0.48)
		},
		{
			"id": "frankfurt",
			"city": "Frankfurt",
			"country": "Germany",
			"country_code": "DE",
			"distance_km": 365.0,
			"unlock_level": 2,
			"coin_reward": 790,
			"xp_reward": 50,
			"map_position": Vector2(0.56, 0.59)
		},
		{
			"id": "paris",
			"city": "Paris",
			"country": "France",
			"country_code": "FR",
			"distance_km": 430.0,
			"unlock_level": 2,
			"coin_reward": 900,
			"xp_reward": 58,
			"map_position": Vector2(0.39, 0.70)
		},
		{
			"id": "berlin",
			"city": "Berlin",
			"country": "Germany",
			"country_code": "DE",
			"distance_km": 575.0,
			"unlock_level": 4,
			"coin_reward": 1180,
			"xp_reward": 72,
			"map_position": Vector2(0.68, 0.48)
		},
		{
			"id": "copenhagen",
			"city": "Copenhagen",
			"country": "Denmark",
			"country_code": "DK",
			"distance_km": 620.0,
			"unlock_level": 5,
			"coin_reward": 1280,
			"xp_reward": 78,
			"map_position": Vector2(0.61, 0.30)
		}
	]


static func get_destination(destination_id: String) -> Dictionary:
	for destination in all():
		if String(destination["id"]) == destination_id:
			return destination.duplicate(true)
	return {}


static func unlocked_for_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination in all():
		if level >= int(destination.get("unlock_level", 1)):
			result.append(destination.duplicate(true))
	return result


static func resources_for_country(country_code: String) -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	var entries: Array = COUNTRY_RESOURCES.get(country_code.to_upper(), [])
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		resources.append(entry.duplicate(true))
	return resources


static func resources_for_destination(destination_id: String) -> Array[Dictionary]:
	var destination := get_destination(destination_id)
	if destination.is_empty():
		return []
	return resources_for_country(String(destination.get("country_code", "")))


static func get_resource_name(resource_id: String) -> String:
	for country_code in COUNTRY_RESOURCES.keys():
		for entry_variant in COUNTRY_RESOURCES[country_code]:
			var entry: Dictionary = entry_variant
			if String(entry.get("id", "")) == resource_id:
				return String(entry.get("name", resource_id))
	return resource_id


static func roll_country_resources(
	destination_id: String,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var resources := resources_for_destination(destination_id)
	if resources.is_empty():
		return {}

	var roller := rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()

	var drops: Dictionary = {}
	for resource in resources:
		var chance := clampf(float(resource.get("drop_chance", 0.40)), 0.0, 1.0)
		if roller.randf() <= chance:
			var resource_id := String(resource.get("id", ""))
			if not resource_id.is_empty():
				drops[resource_id] = int(drops.get(resource_id, 0)) + 1
	return drops
