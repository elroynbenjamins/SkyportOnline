class_name AirportExpansionCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "north_west",
			"px": 0,
			"py": 0,
			"level": 30,
			"cost": 1200000,
			"name": "International Reserve",
			"tag": "FUTURE GROWTH",
			"purpose": "Long-term space for future large-aircraft and international facilities.",
			"milestone": "Reserve land for later airport tiers.",
			"accent": Color("8d9da5"),
			"unlock_buildings": PackedStringArray([])
		},
		{
			"id": "north",
			"px": 1,
			"py": 0,
			"level": 5,
			"cost": 25000,
			"name": "Service Apron",
			"tag": "FIRST EXPANSION",
			"purpose": "Extra room for service buildings, passenger support and early hangars.",
			"milestone": "Relieves the starter apron without forcing a runway rebuild.",
			"accent": Color("e0b95b"),
			"unlock_buildings": PackedStringArray([
				"cleaning_center",
				"passenger_service_hub",
				"baggage_depot"
			])
		},
		{
			"id": "north_east",
			"px": 2,
			"py": 0,
			"level": 26,
			"cost": 900000,
			"name": "Flight Support District",
			"tag": "LATE SUPPORT",
			"purpose": "High-capacity support space for a mature regional airport.",
			"milestone": "Adds room for redundant service fleets and future specialist buildings.",
			"accent": Color("79aab8"),
			"unlock_buildings": PackedStringArray([])
		},
		{
			"id": "west",
			"px": 0,
			"py": 1,
			"level": 12,
			"cost": 120000,
			"name": "Operations District",
			"tag": "AIR TRAFFIC",
			"purpose": "Space for ATC, hangars and operational support away from busy stands.",
			"milestone": "Supports higher traffic density and more complex airport layouts.",
			"accent": Color("7fa1b0"),
			"unlock_buildings": PackedStringArray([
				"atc_tower",
				"small_hangar"
			])
		},
		{
			"id": "home",
			"px": 1,
			"py": 1,
			"level": 1,
			"cost": 0,
			"name": "Home Airfield",
			"tag": "STARTER AIRPORT",
			"purpose": "Your original runway, terminal, stands and ground-service core.",
			"milestone": "Grow outward as traffic and aircraft size increase.",
			"accent": Color("76d39b"),
			"unlock_buildings": PackedStringArray([])
		},
		{
			"id": "east",
			"px": 2,
			"py": 1,
			"level": 8,
			"cost": 50000,
			"name": "Regional Apron",
			"tag": "MEDIUM AIRCRAFT",
			"purpose": "Designed for medium stands, regional fuel and a larger turnaround apron.",
			"milestone": "Opens the practical path toward medium-aircraft operations.",
			"accent": Color("63b4d1"),
			"unlock_buildings": PackedStringArray([
				"medium_stand",
				"regional_fuel"
			])
		},
		{
			"id": "south_west",
			"px": 0,
			"py": 2,
			"level": 22,
			"cost": 600000,
			"name": "Logistics District",
			"tag": "GROUND LOGISTICS",
			"purpose": "Deep service and logistics space for a high-throughput airport.",
			"milestone": "Separates heavy service traffic from passenger operations.",
			"accent": Color("ad8a61"),
			"unlock_buildings": PackedStringArray([])
		},
		{
			"id": "south",
			"px": 1,
			"py": 2,
			"level": 16,
			"cost": 250000,
			"name": "Terminal District",
			"tag": "PASSENGER GROWTH",
			"purpose": "Room for passenger production, terminal support and commercial growth.",
			"milestone": "Lets passenger capacity scale with a larger active fleet.",
			"accent": Color("78b89b"),
			"unlock_buildings": PackedStringArray([
				"shuttle_station"
			])
		},
		{
			"id": "south_east",
			"px": 2,
			"py": 2,
			"level": 12,
			"cost": 150000,
			"name": "Regional Runway Reserve",
			"tag": "SECOND RUNWAY",
			"purpose": "Protected land for a regional runway connected to the eastern apron.",
			"milestone": "Creates the first clean two-runway expansion path.",
			"accent": Color("d8b35e"),
			"unlock_buildings": PackedStringArray([
				"regional_runway"
			])
		}
	]


static func get_zone(zone_id: String) -> Dictionary:
	for zone in all():
		if String(zone.get("id", "")) == zone_id:
			return zone.duplicate(true)
	return {}


static func get_zone_name(zone_id: String) -> String:
	return String(
		get_zone(zone_id).get(
			"name",
			zone_id.replace("_", " ").capitalize()
		)
	)


static func get_unlock_names(zone_id: String) -> Array[String]:
	var result: Array[String] = []
	var zone := get_zone(zone_id)
	var ids: PackedStringArray = zone.get(
		"unlock_buildings",
		PackedStringArray()
	)
	for building_id in ids:
		var definition := BuildingCatalog.get_definition(
			String(building_id)
		)
		if definition.is_empty():
			continue
		result.append(
			String(definition.get("name", building_id))
		)
	return result
