class_name AircraftCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "pico_p8",
			"name": "Pico P8",
			"size_class": "S",
			"unlock_level": 1,
			"purchase_price": 12000,
			"capacity": 8,
			"range_km": 320,
			"cruise_speed_kmh": 270,
			"fuel_cost_per_km": 0.55,
			"fixed_operating_cost": 110,
			"service_cost_per_passenger": 2.0,
			"turnaround_minutes": 4,
			"hangar_space": 1,
			"specialty": "Very low operating cost."
		},
		{
			"id": "swift_s14",
			"name": "Swift S14",
			"size_class": "S",
			"unlock_level": 2,
			"purchase_price": 22000,
			"capacity": 14,
			"range_km": 430,
			"cruise_speed_kmh": 330,
			"fuel_cost_per_km": 0.72,
			"fixed_operating_cost": 150,
			"service_cost_per_passenger": 2.2,
			"turnaround_minutes": 4,
			"hangar_space": 1,
			"specialty": "Fast short-route shuttle."
		},
		{
			"id": "comet_c22",
			"name": "Comet C22",
			"size_class": "S",
			"unlock_level": 4,
			"purchase_price": 45000,
			"capacity": 22,
			"range_km": 600,
			"cruise_speed_kmh": 360,
			"fuel_cost_per_km": 0.90,
			"fixed_operating_cost": 210,
			"service_cost_per_passenger": 2.4,
			"turnaround_minutes": 6,
			"hangar_space": 1,
			"specialty": "Efficient early-game workhorse."
		},
		{
			"id": "voyager_v32",
			"name": "Voyager V32",
			"size_class": "S",
			"unlock_level": 6,
			"purchase_price": 82000,
			"capacity": 32,
			"range_km": 900,
			"cruise_speed_kmh": 390,
			"fuel_cost_per_km": 1.10,
			"fixed_operating_cost": 280,
			"service_cost_per_passenger": 2.6,
			"turnaround_minutes": 8,
			"hangar_space": 1,
			"specialty": "Long-range small aircraft."
		},
		{
			"id": "nimbus_n40",
			"name": "Nimbus N40",
			"size_class": "M",
			"unlock_level": 8,
			"purchase_price": 185000,
			"capacity": 40,
			"range_km": 1050,
			"cruise_speed_kmh": 450,
			"fuel_cost_per_km": 1.55,
			"fixed_operating_cost": 480,
			"service_cost_per_passenger": 3.0,
			"turnaround_minutes": 9,
			"hangar_space": 1,
			"specialty": "First regional aircraft."
		},
		{
			"id": "arrow_a52",
			"name": "Arrow A52",
			"size_class": "M",
			"unlock_level": 10,
			"purchase_price": 270000,
			"capacity": 52,
			"range_km": 1300,
			"cruise_speed_kmh": 520,
			"fuel_cost_per_km": 1.85,
			"fixed_operating_cost": 600,
			"service_cost_per_passenger": 3.2,
			"turnaround_minutes": 8,
			"hangar_space": 1,
			"specialty": "Fast regional cycles."
		},
		{
			"id": "atlas_a64",
			"name": "Atlas A64",
			"size_class": "M",
			"unlock_level": 12,
			"purchase_price": 390000,
			"capacity": 64,
			"range_km": 1500,
			"cruise_speed_kmh": 470,
			"fuel_cost_per_km": 2.00,
			"fixed_operating_cost": 720,
			"service_cost_per_passenger": 3.4,
			"turnaround_minutes": 11,
			"hangar_space": 1,
			"specialty": "High-capacity regional economy."
		},
		{
			"id": "falcon_f72",
			"name": "Falcon F72",
			"size_class": "M",
			"unlock_level": 15,
			"purchase_price": 575000,
			"capacity": 72,
			"range_km": 1900,
			"cruise_speed_kmh": 560,
			"fuel_cost_per_km": 2.35,
			"fixed_operating_cost": 900,
			"service_cost_per_passenger": 3.6,
			"turnaround_minutes": 10,
			"hangar_space": 1,
			"specialty": "Fast premium regional."
		},
		{
			"id": "horizon_h88",
			"name": "Horizon H88",
			"size_class": "M",
			"unlock_level": 17,
			"purchase_price": 850000,
			"capacity": 88,
			"range_km": 2350,
			"cruise_speed_kmh": 500,
			"fuel_cost_per_km": 2.65,
			"fixed_operating_cost": 1100,
			"service_cost_per_passenger": 3.8,
			"turnaround_minutes": 13,
			"hangar_space": 1,
			"specialty": "V1 regional flagship."
		}
	]


static func get_definition(aircraft_id: String) -> Dictionary:
	for definition in all():
		if String(definition.get("id", "")) == aircraft_id:
			return definition.duplicate(true)
	return {}


static func get_available(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in all():
		if int(definition.get("unlock_level", 1)) <= level:
			result.append(definition.duplicate(true))
	return result


static func size_rank(size_class: String) -> int:
	match size_class.to_upper():
		"S":
			return 0
		"M":
			return 1
		"L":
			return 2
		"XL":
			return 3
		_:
			return 99
