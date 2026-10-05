class_name BuildingCatalog
extends RefCounted

# Catalog definitions are immutable; return copies so callers cannot alter the cache.
static var _definitions_by_id: Dictionary = {}
const PRODUCTION_BUILDING_ATLAS := "res://assets/production/airport_buildings_v2/skyport_buildings_atlas.webp"


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "short_runway",
			"name": "Short Runway",
			"menu_name": "SHORT RUNWAY",
			"category": "Infrastructure",
			"footprint": Vector2i(7, 2),
			"cost": 10000,
			"level": 1,
			"color": Color("343c42"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Handles small aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/runway_short.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/runway_short.svg", "res://assets/pixel/airport_v1/runway_short_b.svg"]),
			"world_sprite_size": Vector2(310, 145),
			"world_sprite_offsets": [Vector2(0, 34), Vector2(0, 34)],
			"world_sprite_offset": Vector2(0, 34)
		},
		{
			"id": "small_stand",
			"name": "Small Aircraft Stand",
			"menu_name": "SMALL STAND",
			"category": "Infrastructure",
			"footprint": Vector2i(2, 2),
			"cost": 4500,
			"level": 1,
			"color": Color("727f87"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Parking and turnaround for small aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/stand_small.svg",
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(896, 0, 448, 448),
				Rect2(1344, 0, 448, 448)
			],
			"world_sprite_size": Vector2(192, 192),
			"world_sprite_offsets": [
				Vector2(0, -29),
				Vector2(0, -34)
			],
			"world_sprite_offset": Vector2(0, -29)
		},
		{
			"id": "taxiway",
			"name": "Taxiway",
			"menu_name": "TAXIWAY",
			"category": "Infrastructure",
			"footprint": Vector2i(1, 1),
			"cost": 250,
			"level": 1,
			"color": Color("59636a"),
			"rotatable": false,
			"sizes": PackedStringArray(["S", "M", "L"]),
			"description": "Connects runways and stands.",
			"icon_path": "res://assets/pixel/airport_v1/taxiway.svg"
		},
		{
			"id": "service_road",
			"name": "Service Road",
			"menu_name": "SERVICE ROAD",
			"category": "Infrastructure",
			"footprint": Vector2i(1, 1),
			"cost": 150,
			"level": 1,
			"color": Color("7c7368"),
			"rotatable": false,
			"sizes": PackedStringArray(["S", "M", "L"]),
			"description": "Ground vehicles use service roads to reach aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/service_road.svg"
		},
		{
			"id": "small_terminal",
			"name": "Small Terminal",
			"menu_name": "TERMINAL",
			"category": "Passenger",
			"footprint": Vector2i(3, 2),
			"cost": 8000,
			"level": 1,
			"color": Color("bac6c8"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Basic passenger handling.",
			"synergy_provider": "passenger_hub",
			"synergy_radius_tiles": 5.0,
			"synergy_bonus": 0.10,
			"icon_path": "res://assets/pixel/airport_v1/terminal_small.svg",
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 0, 448, 448),
				Rect2(448, 0, 448, 448)
			],
			"world_sprite_size": Vector2(300, 300),
			"world_sprite_offsets": [
				Vector2(0, -55),
				Vector2(0, -60)
			],
			"world_sprite_offset": Vector2(0, -55)
		},
		{
			"id": "shuttle_station",
			"name": "Airport Shuttle Station",
			"menu_name": "SHUTTLE STATION",
			"category": "Passenger",
			"footprint": Vector2i(3, 2),
			"cost": 15000,
			"level": 4,
			"color": Color("4f7f9d"),
			"rotatable": true,
			"sizes": PackedStringArray([]),
			"description": "Higher passenger flow with less storage than a Travel Office.",
			"passenger_generator": true,
			"synergy_receiver": "passenger_hub",
			"passenger_synergy_bonus": 0.15,
			"icon_path": "res://assets/pixel/airport_v1/shuttle_station.svg",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 1344, 448, 448),
				Rect2(448, 1344, 448, 448)
			],
			"world_sprite_size": Vector2(280, 280),
			"world_sprite_offsets": [
				Vector2(0, -56),
				Vector2(0, -64)
			],
			"world_sprite_offset": Vector2(0, -56)
		},
		{
			"id": "travel_office",
			"name": "Travel Office",
			"menu_name": "TRAVEL OFFICE",
			"category": "Passenger",
			"footprint": Vector2i(2, 2),
			"cost": 6500,
			"level": 2,
			"color": Color("4d8f8e"),
			"rotatable": true,
			"sizes": PackedStringArray([]),
			"description": "Slowly attracts passengers and stores them for flights.",
			"passenger_generator": true,
			"synergy_receiver": "passenger_hub",
			"passenger_synergy_bonus": 0.10,
			"icon_path": "res://assets/pixel/airport_v1/travel_office.svg",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(896, 896, 448, 448),
				Rect2(1344, 896, 448, 448)
			],
			"world_sprite_size": Vector2(188, 188),
			"world_sprite_offsets": [
				Vector2(0, -34),
				Vector2(0, -46)
			],
			"world_sprite_offset": Vector2(0, -34)
		},
		{
			"id": "ground_ops_depot",
			"name": "Ground Operations Depot",
			"menu_name": "GROUND OPS",
			"category": "Services",
			"footprint": Vector2i(1, 1),
			"cost": 5500,
			"level": 1,
			"color": Color("5f7f8a"),
			"rotatable": false,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Starter passenger, baggage, cleaning and catering fleets.",
			"local_service_bonus": 0.05,
			"local_service_radius_tiles": 5.0,
			"icon_path": "res://assets/pixel/airport_v1/ground_ops_depot.svg",
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 896, 448, 448),
				Rect2(448, 896, 448, 448)
			],
			"world_sprite_size": Vector2(116, 116),
			"world_sprite_offsets": [
				Vector2(0, -31),
				Vector2(0, -29)
			],
			"world_sprite_offset": Vector2(0, -31),
			"services": {
				"passenger": {"service_speed": 1.0, "vehicle_capacity": 1},
				"cargo": {"service_speed": 1.0, "vehicle_capacity": 1},
				"cleaning": {"service_speed": 1.0, "vehicle_capacity": 1},
				"catering": {"service_speed": 1.0, "vehicle_capacity": 1},
				"pushback": {"service_speed": 1.0, "vehicle_capacity": 1}
			}
		},
		{
			"id": "cleaning_center",
			"name": "Cleaning Center",
			"menu_name": "CLEANING",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 14000,
			"level": 3,
			"color": Color("70a5a0"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two faster cabin-cleaning vans.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"icon_path": "res://assets/pixel/airport_v1/cleaning_center.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/cleaning_center.svg", "res://assets/pixel/airport_v1/cleaning_center_b.svg"]),
			"world_sprite_size": Vector2(188, 157),
			"world_sprite_offsets": [Vector2(0, -16), Vector2(0, -12)],
			"world_sprite_offset": Vector2(0, -16),
			"service": "cleaning",
			"service_speed": 1.35,
			"vehicle_capacity": 2
		},
		{
			"id": "passenger_service_hub",
			"name": "Passenger Service Hub",
			"menu_name": "PAX SERVICE",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 18000,
			"level": 4,
			"color": Color("538eb0"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two faster passenger buses / boarding crews.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"icon_path": "res://assets/pixel/airport_v1/passenger_service_hub.svg",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(896, 1344, 448, 448),
				Rect2(1344, 1344, 448, 448)
			],
			"world_sprite_size": Vector2(188, 188),
			"world_sprite_offsets": [
				Vector2(0, -32),
				Vector2(0, -33)
			],
			"world_sprite_offset": Vector2(0, -32),
			"service": "passenger",
			"service_speed": 1.25,
			"vehicle_capacity": 2
		},
		{
			"id": "baggage_depot",
			"name": "Baggage Depot",
			"menu_name": "BAGGAGE",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 20000,
			"level": 5,
			"color": Color("8b765c"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two faster baggage / cargo tractors.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"icon_path": "res://assets/pixel/airport_v1/baggage_depot.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/baggage_depot.svg", "res://assets/pixel/airport_v1/baggage_depot_b.svg"]),
			"world_sprite_size": Vector2(188, 157),
			"world_sprite_offsets": [Vector2(0, -16), Vector2(0, -12)],
			"world_sprite_offset": Vector2(0, -16),
			"service": "cargo",
			"service_speed": 1.35,
			"vehicle_capacity": 2
		},
		{
			"id": "catering_kitchen",
			"name": "Catering Kitchen",
			"menu_name": "CATERING",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 24000,
			"level": 6,
			"color": Color("b98662"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two faster catering trucks for regional operations.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"icon_path": "res://assets/pixel/airport_v1/catering_kitchen.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/catering_kitchen.svg", "res://assets/pixel/airport_v1/catering_kitchen_b.svg"]),
			"world_sprite_size": Vector2(188, 157),
			"world_sprite_offsets": [Vector2(0, -16), Vector2(0, -12)],
			"world_sprite_offset": Vector2(0, -16),
			"service": "catering",
			"service_speed": 1.30,
			"vehicle_capacity": 2
		},
		{
			"id": "tow_operations",
			"name": "Tow Operations",
			"menu_name": "TOW OPS",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 28000,
			"level": 7,
			"color": Color("667482"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two faster pushback tugs for busy stands.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"icon_path": "res://assets/pixel/airport_v1/tow_operations.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/tow_operations.svg", "res://assets/pixel/airport_v1/tow_operations_b.svg"]),
			"world_sprite_size": Vector2(188, 157),
			"world_sprite_offsets": [Vector2(0, -16), Vector2(0, -12)],
			"world_sprite_offset": Vector2(0, -16),
			"service": "pushback",
			"service_speed": 1.25,
			"vehicle_capacity": 2
		},
		{
			"id": "atc_tower",
			"name": "Air Traffic Control Tower",
			"menu_name": "ATC TOWER",
			"category": "Operations",
			"footprint": Vector2i(2, 2),
			"cost": 55000,
			"level": 9,
			"color": Color("77909a"),
			"rotatable": true,
			"sizes": PackedStringArray([]),
			"description": "Reduces required separation between runway movements.",
			"icon_path": "res://assets/pixel/airport_v1/atc_tower.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/atc_tower.svg", "res://assets/pixel/airport_v1/atc_tower_b.svg"]),
			"world_sprite_size": Vector2(210, 240),
			"world_sprite_offsets": [Vector2(0, -50), Vector2(0, -44)],
			"world_sprite_offset": Vector2(0, -50),
			"air_traffic_control": true
		},
		{
			"id": "small_hangar",
			"name": "Small Hangar",
			"menu_name": "SMALL HANGAR",
			"category": "Operations",
			"footprint": Vector2i(3, 3),
			"cost": 12000,
			"level": 3,
			"color": Color("8094a1"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Stores and maintains small aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/hangar_small.svg",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 448, 448, 448),
				Rect2(448, 448, 448, 448)
			],
			"world_sprite_size": Vector2(292, 292),
			"world_sprite_offsets": [
				Vector2(0, -66),
				Vector2(0, -71)
			],
			"world_sprite_offset": Vector2(0, -66)
		},
		{
			"id": "basic_fuel",
			"name": "Basic Fuel Station",
			"menu_name": "FUEL STATION",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 7500,
			"level": 2,
			"color": Color("c59b43"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "One standard-speed fuel truck.",
			"local_service_bonus": 0.08,
			"local_service_radius_tiles": 6.0,
			"service": "fuel",
			"service_speed": 1.0,
			"vehicle_capacity": 1,
			"icon_path": "res://assets/pixel/airport_v1/fuel_basic.svg",
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_BUILDING_ATLAS,
			"world_sprite_regions": [
				Rect2(896, 448, 448, 448),
				Rect2(1344, 448, 448, 448)
			],
			"world_sprite_size": Vector2(188, 188),
			"world_sprite_offsets": [
				Vector2(0, -35),
				Vector2(0, -45)
			],
			"world_sprite_offset": Vector2(0, -35)
		},
		{
			"id": "rapid_small_fuel",
			"name": "Rapid Small Fuel Station",
			"menu_name": "RAPID S FUEL",
			"category": "Services",
			"footprint": Vector2i(2, 2),
			"cost": 30000,
			"level": 6,
			"color": Color("d7ab4c"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Two faster fuel trucks for small aircraft.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"service": "fuel",
			"service_speed": 1.6,
			"vehicle_capacity": 2,
			"icon_path": "res://assets/pixel/airport_v1/fuel_rapid.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/fuel_rapid.svg", "res://assets/pixel/airport_v1/fuel_rapid_b.svg"]),
			"world_sprite_size": Vector2(224, 187),
			"world_sprite_offsets": [Vector2(0, -25), Vector2(0, -21)],
			"world_sprite_offset": Vector2(0, -25)
		},
		{
			"id": "medium_stand",
			"name": "Medium Aircraft Stand",
			"menu_name": "MEDIUM STAND",
			"category": "Infrastructure",
			"footprint": Vector2i(3, 3),
			"cost": 35000,
			"level": 8,
			"color": Color("6f7c84"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Larger turnaround stand for small and medium aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/stand_small.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/stand_small.svg", "res://assets/pixel/airport_v1/stand_small_b.svg"]),
			"world_sprite_size": Vector2(270, 162),
			"world_sprite_offsets": [Vector2(0, 6), Vector2(0, 2)],
			"world_sprite_offset": Vector2(0, 6)
		},
		{
			"id": "regional_fuel",
			"name": "Regional Fuel Depot",
			"menu_name": "REGIONAL FUEL",
			"category": "Services",
			"footprint": Vector2i(3, 3),
			"cost": 45000,
			"level": 8,
			"color": Color("cfa247"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Two standard-speed trucks for small and medium aircraft.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 7.0,
			"service": "fuel",
			"service_speed": 1.0,
			"vehicle_capacity": 2,
			"icon_path": "res://assets/pixel/airport_v1/fuel_basic.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/fuel_basic.svg", "res://assets/pixel/airport_v1/fuel_basic_b.svg"]),
			"world_sprite_size": Vector2(280, 233),
			"world_sprite_offsets": [Vector2(0, -23), Vector2(0, -18)],
			"world_sprite_offset": Vector2(0, -23)
		},
		{
			"id": "regional_runway",
			"name": "Regional Runway",
			"menu_name": "REGIONAL RUNWAY",
			"category": "Infrastructure",
			"footprint": Vector2i(10, 3),
			"cost": 90000,
			"level": 12,
			"color": Color("2c3338"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Longer runway for small and medium aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/runway_short.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/runway_short.svg", "res://assets/pixel/airport_v1/runway_short_b.svg"]),
			"world_sprite_size": Vector2(430, 202),
			"world_sprite_offsets": [Vector2(0, 51), Vector2(0, 51)],
			"world_sprite_offset": Vector2(0, 51)
		},
		{
			"id": "autumn_event_flag",
			"name": "Autumn Event Flag",
			"menu_name": "AUTUMN FLAG",
			"category": "Decorations",
			"footprint": Vector2i(1, 1),
			"cost": 0,
			"level": 1,
			"color": Color("b45b2a"),
			"rotatable": false,
			"sizes": PackedStringArray([]),
			"description": "Placeable Autumn Airbridge flag cosmetic.",
			"event_decoration": true,
			"required_cosmetic_id": "event_autumn_alliance_flag"
		},
		{
			"id": "autumn_leaf_garden",
			"name": "Autumn Leaf Garden",
			"menu_name": "LEAF GARDEN",
			"category": "Decorations",
			"footprint": Vector2i(2, 1),
			"cost": 0,
			"level": 1,
			"color": Color("8a6333"),
			"rotatable": true,
			"sizes": PackedStringArray([]),
			"description": "Placeable autumn garden unlocked from the seasonal shop.",
			"event_decoration": true,
			"required_cosmetic_id": "event_autumn_leaf_garden"
		},
		{
			"id": "winter_event_flag",
			"name": "Winter Event Flag",
			"menu_name": "WINTER FLAG",
			"category": "Decorations",
			"footprint": Vector2i(1, 1),
			"cost": 0,
			"level": 1,
			"color": Color("b72f3c"),
			"rotatable": false,
			"sizes": PackedStringArray([]),
			"description": "Placeable Winter Airbridge flag cosmetic.",
			"event_decoration": true,
			"required_cosmetic_id": "event_winter_alliance_flag"
		},
		{
			"id": "winter_snow_globe_garden",
			"name": "Snow Globe Garden",
			"menu_name": "SNOW GLOBE",
			"category": "Decorations",
			"footprint": Vector2i(2, 1),
			"cost": 0,
			"level": 1,
			"color": Color("8eb8c8"),
			"rotatable": true,
			"sizes": PackedStringArray([]),
			"description": "Placeable Winter event garden unlocked from the seasonal shop.",
			"event_decoration": true,
			"required_cosmetic_id": "event_winter_snow_globe_garden"
		},
		{
			"id": "rapid_regional_fuel",
			"name": "Regional Rapid Fuel Station",
			"menu_name": "RAPID FUEL",
			"category": "Services",
			"footprint": Vector2i(4, 3),
			"cost": 85000,
			"level": 10,
			"color": Color("d2a64a"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Three faster fuel trucks for regional operations.",
			"local_service_bonus": 0.12,
			"local_service_radius_tiles": 7.0,
			"service": "fuel",
			"service_speed": 1.5,
			"vehicle_capacity": 3,
			"icon_path": "res://assets/pixel/airport_v1/fuel_rapid.svg",
			"world_sprite_paths": PackedStringArray(["res://assets/pixel/airport_v1/fuel_rapid.svg", "res://assets/pixel/airport_v1/fuel_rapid_b.svg"]),
			"world_sprite_size": Vector2(330, 275),
			"world_sprite_offsets": [Vector2(0, -27), Vector2(0, -21)],
			"world_sprite_offset": Vector2(0, -27)
		}
	]


static func get_definition(building_id: String) -> Dictionary:
	if _definitions_by_id.is_empty():
		for definition in all():
			_definitions_by_id[String(definition["id"])] = definition
	if not _definitions_by_id.has(building_id):
		return {}
	return (_definitions_by_id[building_id] as Dictionary).duplicate(true)


static func get_menu_definitions(
	owned_cosmetics: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in all():
		if bool(definition.get("event_decoration", false)):
			var required := String(
				definition.get("required_cosmetic_id", "")
			)
			if required.is_empty() or not bool(
				owned_cosmetics.get(required, false)
			):
				continue
		result.append(definition.duplicate(true))
	return result
