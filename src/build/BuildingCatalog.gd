class_name BuildingCatalog
extends RefCounted


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
			"description": "Handles small aircraft."
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
			"description": "Parking and turnaround for small aircraft."
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
			"description": "Connects runways and stands."
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
			"description": "Basic passenger handling."
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
			"description": "Stores and maintains small aircraft."
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
			"service": "fuel",
			"service_speed": 1.0,
			"vehicle_capacity": 1
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
			"description": "Longer runway for small and medium aircraft."
		},
		{
			"id": "rapid_regional_fuel",
			"name": "Regional Rapid Fuel Station",
			"menu_name": "RAPID FUEL",
			"category": "Services",
			"footprint": Vector2i(4, 3),
			"cost": 65000,
			"level": 10,
			"color": Color("d2a64a"),
			"rotatable": true,
			"sizes": PackedStringArray(["S", "M"]),
			"description": "Three faster fuel trucks for regional operations.",
			"service": "fuel",
			"service_speed": 1.5,
			"vehicle_capacity": 3
		}
	]


static func get_definition(building_id: String) -> Dictionary:
	for definition in all():
		if String(definition["id"]) == building_id:
			return definition.duplicate(true)
	return {}


static func get_menu_definitions() -> Array[Dictionary]:
	return all()
