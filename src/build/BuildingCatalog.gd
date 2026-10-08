class_name BuildingCatalog
extends RefCounted

# Catalog definitions are immutable; return copies so callers cannot alter the cache.
static var _definitions_by_id: Dictionary = {}
const PRODUCTION_BUILDING_ATLAS := "res://assets/production/airport_buildings_v2/skyport_buildings_atlas.webp"
const PRODUCTION_SERVICE_BUILDING_ATLAS_A := "res://assets/production/service_buildings_v2/service_buildings_v2a.webp"
const PRODUCTION_SERVICE_BUILDING_ATLAS_B := "res://assets/production/service_buildings_v2/service_buildings_v2b_stylized.svg"
const PRODUCTION_SEASONAL_DECOR_ATLAS := "res://assets/production/seasonal_decor_v2/seasonal_decor_atlas_v2.svg"
const PRODUCTION_REGIONAL_FACILITIES_ATLAS := "res://assets/production/regional_facilities_v2/regional_facilities_v2.svg"


static func _raw_definitions() -> Array[Dictionary]:
	return [
		{
			"id": "short_runway",
			"name": "Short Runway",
			"menu_name": "SHORT RUNWAY",
			"category": "Infrastructure",
			"footprint": Vector2i(5, 2),
			"cost": 7500,
			"level": 1,
			"color": Color("343c42"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Handles small aircraft.",
			"icon_path": "res://assets/production/airfield_v2/runway_icon_v2.svg",
			"art_tier": "grid_native_v3",
			"surface_art": "short_runway_s_5x2_v3",
			"visual_contract": "square_grid_iso_v1",
			"grid_native_surface_paths": PackedStringArray([
				"res://assets/production/airfield_v3/short_runway_s_0.svg",
				"res://assets/production/airfield_v3/short_runway_s_90.svg"
			]),
			"grid_native_surface_size": Vector2i(224, 112),
			"grid_native_surface_runtime_scale": Vector2.ONE,
			"runway_direction_policy": "origin_to_long_axis_end",
			"runway_taxi_exit_policy": "rollout_end_four",
			"runway_taxi_lane_count": 2,
			"runway_max_active_taxi_connections": 2,
			"runway_max_active_taxi_connections_per_lane": 1
		},
		{
			"id": "small_stand",
			"name": "Small Aircraft Stand",
			"menu_name": "SMALL STAND",
			"category": "Infrastructure",
			"footprint": Vector2i(2, 2),
			"cost": 3000,
			"level": 1,
			"color": Color("727f87"),
			"rotatable": true,
			"sizes": PackedStringArray(["S"]),
			"description": "Parking and turnaround for small aircraft.",
			"icon_path": "res://assets/pixel/airport_v1/stand_small.svg",
			"art_tier": "canonical_v2",
			"world_art_has_integrated_base": true,
			"world_sprite_grid_fit": true,
			"world_sprite_auto_ground": true,
			"world_sprite_visible_width_scale": 0.96,
			"world_sprite_max_width_scale": 1.20,
			"world_sprite_ground_align": true,
			"world_ground_pad": false,
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
			"cost": 125,
			"level": 1,
			"color": Color("59636a"),
			"rotatable": false,
			"sizes": PackedStringArray(["S", "M", "L"]),
			"description": "Connects runways and stands.",
			"icon_path": "res://assets/production/airfield_v2/taxiway_icon_v2.svg",
			"art_tier": "grid_native_v3",
			"surface_art": "taxiway_1x1_v3",
			"visual_contract": "square_grid_iso_v1",
			"grid_native_surface_paths": PackedStringArray([
				"res://assets/production/airfield_v3/taxiway_1x1.svg"
			]),
			"grid_native_surface_size": Vector2i(64, 32),
			"grid_native_surface_runtime_scale": Vector2.ONE,
			"grid_native_autotile_atlas_path": "res://assets/production/airfield_v3/taxiway_autotile_atlas.svg",
			"grid_native_autotile_tile_size": Vector2i(64, 32),
			"grid_native_autotile_variant_count": 16,
			"grid_native_autotile_runtime_mode": "standalone_variants",
			"grid_native_autotile_variant_paths": PackedStringArray([
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_00_isolated.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_01_dead_n.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_02_dead_e.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_03_corner_ne.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_04_dead_s.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_05_straight_ns.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_06_corner_es.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_07_t_nes.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_08_dead_w.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_09_corner_wn.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_10_straight_ew.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_11_t_new.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_12_corner_sw.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_13_t_nsw.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_14_t_esw.svg",
				"res://assets/production/airfield_v3/taxiway_variants/taxiway_15_cross.svg"
			]),
			"grid_native_autotile_bits": {
				"north": 1,
				"east": 2,
				"south": 4,
				"west": 8
			},
			"connection_family": "airside",
			"connects_to": PackedStringArray(["taxiway", "runway", "stand", "hangar"])
		},
		{
			"id": "service_road",
			"name": "Service Road",
			"menu_name": "SERVICE ROAD",
			"category": "Infrastructure",
			"footprint": Vector2i(1, 1),
			"cost": 75,
			"level": 1,
			"color": Color("7c7368"),
			"rotatable": false,
			"sizes": PackedStringArray(["S", "M", "L"]),
			"description": "Ground vehicles use service roads to reach aircraft.",
			"icon_path": "res://assets/production/airfield_v2/service_road_icon_v2.svg",
			"art_tier": "surface_v2",
			"surface_art": "service_road_v2",
			"connection_family": "ground_service",
			"connects_to": PackedStringArray(["service_road", "stand", "service", "passenger"])
		},
		{
			"id": "apron_tile",
			"name": "Apron Concrete",
			"menu_name": "APRON CONCRETE",
			"category": "Infrastructure",
			"footprint": Vector2i(1, 1),
			"cost": 100,
			"level": 1,
			"color": Color("c7c5bd"),
			"rotatable": false,
			"movable": false,
			"sizes": PackedStringArray([]),
			"description": "Placeable airport concrete for aprons, service areas and terminal hardscape.",
			"icon_path": "res://assets/production/airfield_v2/apron_icon_v2.svg",
			"art_tier": "surface_v2",
			"surface_art": "apron_v2",
			"connection_family": "apron"
		},
		{
			"id": "airport_office",
			"name": "Main Airport Building",
			"menu_name": "MAIN BUILDING",
			"category": "Administration",
			"footprint": Vector2i(3, 2),
			"cost": 0,
			"level": 1,
			"color": Color("d9c48a"),
			"rotatable": false,
			"movable": false,
			"hidden_from_catalog": true,
			"sizes": PackedStringArray([]),
			"description": "The fixed administration and identity anchor of your airport. Operational facilities are built around it during the tutorial."
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
			"world_art_has_integrated_base": true,
			"world_sprite_grid_fit": true,
			"world_sprite_auto_ground": true,
			"world_sprite_visible_width_scale": 0.90,
			"world_sprite_max_width_scale": 1.10,
			"world_sprite_ground_align": true,
			"world_ground_pad": false,
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
			"world_art_has_integrated_base": true,
			"world_sprite_grid_fit": true,
			"world_sprite_auto_ground": true,
			"world_sprite_visible_width_scale": 0.88,
			"world_sprite_max_width_scale": 1.25,
			"world_sprite_ground_align": true,
			"world_ground_pad": false,
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
			"world_art_has_integrated_base": true,
			"world_sprite_grid_fit": true,
			"world_sprite_auto_ground": true,
			"world_sprite_visible_width_scale": 0.82,
			"world_sprite_max_width_scale": 1.25,
			"world_sprite_ground_align": true,
			"world_ground_pad": false,
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
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_A,
			"world_sprite_regions": [
				Rect2(0, 0, 448, 448),
				Rect2(448, 0, 448, 448)
			],
			"world_sprite_size": Vector2(210, 210),
			"world_sprite_offsets": [
				Vector2(0, -58),
				Vector2(0, -58)
			],
			"world_sprite_offset": Vector2(0, -58),
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
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_A,
			"world_sprite_regions": [
				Rect2(0, 448, 448, 448),
				Rect2(448, 448, 448, 448)
			],
			"world_sprite_size": Vector2(210, 210),
			"world_sprite_offsets": [
				Vector2(0, -51),
				Vector2(0, -51)
			],
			"world_sprite_offset": Vector2(0, -51),
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
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_A,
			"world_sprite_regions": [
				Rect2(0, 896, 448, 448),
				Rect2(448, 896, 448, 448)
			],
			"world_sprite_size": Vector2(210, 210),
			"world_sprite_offsets": [
				Vector2(0, -52),
				Vector2(0, -52)
			],
			"world_sprite_offset": Vector2(0, -52),
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
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_B,
			"world_sprite_regions": [
				Rect2(0, 0, 448, 448),
				Rect2(448, 0, 448, 448)
			],
			"world_sprite_size": Vector2(210, 210),
			"world_sprite_offsets": [
				Vector2(0, -41),
				Vector2(0, -41)
			],
			"world_sprite_offset": Vector2(0, -41),
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
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_B,
			"world_sprite_regions": [
				Rect2(0, 896, 448, 448),
				Rect2(448, 896, 448, 448)
			],
			"world_sprite_size": Vector2(228, 228),
			"world_sprite_offsets": [
				Vector2(0, -48),
				Vector2(0, -48)
			],
			"world_sprite_offset": Vector2(0, -48),
			"air_traffic_control": true
		},
		{
			"id": "small_hangar",
			"name": "Small Hangar",
			"menu_name": "SMALL HANGAR",
			"category": "Operations",
			"footprint": Vector2i(3, 2),
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
			"description": "Starter fuel depot with one truck, 240 storage and steady fuel deliveries.",
			"local_service_bonus": 0.08,
			"local_service_radius_tiles": 6.0,
			"service": "fuel",
			"service_speed": 1.0,
			"vehicle_capacity": 1,
			"fuel_storage": 240,
			"fuel_delivery_per_minute": 1.0,
			"icon_path": "res://assets/pixel/airport_v1/fuel_basic.svg",
			"art_tier": "canonical_v2",
			"world_art_has_integrated_base": true,
			"world_sprite_grid_fit": true,
			"world_sprite_auto_ground": true,
			"world_sprite_visible_width_scale": 0.90,
			"world_sprite_max_width_scale": 1.10,
			"world_sprite_ground_align": true,
			"world_ground_pad": false,
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
			"description": "Fast small-aircraft depot with two trucks, 360 storage and quicker deliveries.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 6.0,
			"service": "fuel",
			"service_speed": 1.6,
			"vehicle_capacity": 2,
			"fuel_storage": 360,
			"fuel_delivery_per_minute": 1.6,
			"icon_path": "res://assets/pixel/airport_v1/fuel_rapid.svg",
			"art_tier": "canonical_v2",
			"world_sprite_atlas_path": PRODUCTION_SERVICE_BUILDING_ATLAS_B,
			"world_sprite_regions": [
				Rect2(0, 448, 448, 448),
				Rect2(448, 448, 448, 448)
			],
			"world_sprite_size": Vector2(220, 220),
			"world_sprite_offsets": [
				Vector2(0, -45),
				Vector2(0, -45)
			],
			"world_sprite_offset": Vector2(0, -45)
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
			"art_tier": "regional_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_REGIONAL_FACILITIES_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 0, 384, 384),
				Rect2(384, 0, 384, 384)
			],
			"world_sprite_size": Vector2(300, 300),
			"world_sprite_offsets": [
				Vector2(0, -77),
				Vector2(0, -77)
			],
			"world_sprite_offset": Vector2(0, -77)
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
			"description": "Regional depot for S/M aircraft with 600 storage and reliable deliveries.",
			"local_service_bonus": 0.10,
			"local_service_radius_tiles": 7.0,
			"service": "fuel",
			"service_speed": 1.0,
			"vehicle_capacity": 2,
			"fuel_storage": 600,
			"fuel_delivery_per_minute": 2.0,
			"art_tier": "regional_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_REGIONAL_FACILITIES_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 384, 384, 384),
				Rect2(384, 384, 384, 384)
			],
			"world_sprite_size": Vector2(306, 306),
			"world_sprite_offsets": [
				Vector2(0, -81),
				Vector2(0, -81)
			],
			"world_sprite_offset": Vector2(0, -81)
		},
		{
			"id": "regional_runway",
			"name": "Regional Runway",
			"menu_name": "REGIONAL RUNWAY",
			"category": "Infrastructure",
			"footprint": Vector2i(12, 3),
			"cost": 90000,
			"level": 12,
			"color": Color("2c3338"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Longer runway for small and medium aircraft.",
			"icon_path": "res://assets/production/airfield_v2/runway_icon_v2.svg",
			"art_tier": "surface_v2",
			"surface_art": "runway_v2",
			"runway_direction_policy": "origin_to_long_axis_end",
			"runway_taxi_exit_policy": "rollout_end_four",
			"runway_taxi_lane_count": 2,
			"runway_max_active_taxi_connections": 2,
			"runway_max_active_taxi_connections_per_lane": 1
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
			"required_cosmetic_id": "event_autumn_alliance_flag",
			"art_tier": "seasonal_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_SEASONAL_DECOR_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 0, 256, 256)
			],
			"world_sprite_size": Vector2(112, 112),
			"world_sprite_offsets": [
				Vector2(0, -29)
			],
			"world_sprite_offset": Vector2(0, -29)
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
			"required_cosmetic_id": "event_autumn_leaf_garden",
			"art_tier": "seasonal_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_SEASONAL_DECOR_ATLAS,
			"world_sprite_regions": [
				Rect2(256, 0, 256, 256),
				Rect2(512, 0, 256, 256)
			],
			"world_sprite_size": Vector2(150, 150),
			"world_sprite_offsets": [
				Vector2(0, -35),
				Vector2(0, -35)
			],
			"world_sprite_offset": Vector2(0, -35)
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
			"required_cosmetic_id": "event_winter_alliance_flag",
			"art_tier": "seasonal_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_SEASONAL_DECOR_ATLAS,
			"world_sprite_regions": [
				Rect2(768, 0, 256, 256)
			],
			"world_sprite_size": Vector2(112, 112),
			"world_sprite_offsets": [
				Vector2(0, -29)
			],
			"world_sprite_offset": Vector2(0, -29)
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
			"required_cosmetic_id": "event_winter_snow_globe_garden",
			"art_tier": "seasonal_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_SEASONAL_DECOR_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 256, 256, 256),
				Rect2(256, 256, 256, 256)
			],
			"world_sprite_size": Vector2(154, 154),
			"world_sprite_offsets": [
				Vector2(0, -37),
				Vector2(0, -37)
			],
			"world_sprite_offset": Vector2(0, -37)
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
			"description": "High-throughput regional depot with three trucks, 900 storage and fast deliveries.",
			"local_service_bonus": 0.12,
			"local_service_radius_tiles": 7.0,
			"service": "fuel",
			"service_speed": 1.5,
			"vehicle_capacity": 3,
			"fuel_storage": 900,
			"fuel_delivery_per_minute": 3.0,
			"art_tier": "regional_v2",
			"world_ground_pad": false,
			"world_sprite_atlas_path": PRODUCTION_REGIONAL_FACILITIES_ATLAS,
			"world_sprite_regions": [
				Rect2(0, 768, 384, 384),
				Rect2(384, 768, 384, 384)
			],
			"world_sprite_size": Vector2(348, 348),
			"world_sprite_offsets": [
				Vector2(0, -98),
				Vector2(0, -98)
			],
			"world_sprite_offset": Vector2(0, -98)
		}
	]


static var GRID_RESET_VISUAL_KEYS := PackedStringArray([
	"icon_path",
	"art_tier",
	"surface_art",
	"world_art_has_integrated_base",
	"world_sprite_grid_fit",
	"world_sprite_auto_ground",
	"world_sprite_visible_width_scale",
	"world_sprite_max_width_scale",
	"world_sprite_ground_align",
	"world_ground_pad",
	"world_sprite_atlas_path",
	"world_sprite_regions",
	"world_sprite_size",
	"world_sprite_offsets",
	"world_sprite_offset",
	"world_sprite_paths",
	"world_sprite_path"
])


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_definition in _raw_definitions():
		var definition: Dictionary = raw_definition.duplicate(true)
		for key in GRID_RESET_VISUAL_KEYS:
			definition.erase(key)
		definition["visual_contract"] = "square_grid_iso_v1"
		result.append(definition)
	return result


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
		if bool(definition.get("hidden_from_catalog", false)):
			continue
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
