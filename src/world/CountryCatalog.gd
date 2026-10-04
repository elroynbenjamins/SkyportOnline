class_name CountryCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"code": "NL",
			"name": "Netherlands",
			"latitude": 52.13,
			"longitude": 5.29,
			"resources": [
				{"id": "nl_logistics_crates", "name": "Logistics Crates"},
				{"id": "nl_hydraulic_valves", "name": "Hydraulic Valves"},
				{"id": "nl_aero_paint", "name": "Aero Paint"}
			]
		},
		{
			"code": "DE",
			"name": "Germany",
			"latitude": 51.16,
			"longitude": 10.45,
			"resources": [
				{"id": "de_precision_steel", "name": "Precision Steel"},
				{"id": "de_bearing_sets", "name": "Bearing Sets"},
				{"id": "de_machine_tooling", "name": "Machine Tooling"}
			]
		},
		{
			"code": "BE",
			"name": "Belgium",
			"latitude": 50.50,
			"longitude": 4.47,
			"resources": [
				{"id": "be_tempered_glass", "name": "Tempered Glass"},
				{"id": "be_fine_wire", "name": "Fine Wire"},
				{"id": "be_composite_sealant", "name": "Composite Sealant"}
			]
		},
		{
			"code": "GB",
			"name": "United Kingdom",
			"latitude": 54.00,
			"longitude": -2.50,
			"resources": [
				{"id": "gb_turbine_blades", "name": "Turbine Blades"},
				{"id": "gb_avionics_boards", "name": "Avionics Boards"},
				{"id": "gb_radar_parts", "name": "Weather Radar Parts"}
			]
		},
		{
			"code": "CH",
			"name": "Switzerland",
			"latitude": 46.82,
			"longitude": 8.23,
			"resources": [
				{"id": "ch_precision_gears", "name": "Precision Gears"},
				{"id": "ch_instrument_crystals", "name": "Instrument Crystals"},
				{"id": "ch_carbon_panels", "name": "Carbon Panels"}
			]
		},
		{
			"code": "DK",
			"name": "Denmark",
			"latitude": 56.26,
			"longitude": 9.50,
			"resources": [
				{"id": "dk_wind_alloys", "name": "Wind Alloys"},
				{"id": "dk_marine_fasteners", "name": "Marine Fasteners"},
				{"id": "dk_polymer_sheets", "name": "Polymer Sheets"}
			]
		},
		{
			"code": "CZ",
			"name": "Czechia",
			"latitude": 49.82,
			"longitude": 15.47,
			"resources": [
				{"id": "cz_gearboxes", "name": "Gearboxes"},
				{"id": "cz_hardened_springs", "name": "Hardened Springs"},
				{"id": "cz_cast_housings", "name": "Cast Housings"}
			]
		},
		{
			"code": "IT",
			"name": "Italy",
			"latitude": 42.83,
			"longitude": 12.83,
			"resources": [
				{"id": "it_cabin_fabric", "name": "Cabin Fabric"},
				{"id": "it_light_alloy_frames", "name": "Light Alloy Frames"},
				{"id": "it_premium_leather", "name": "Premium Leather"}
			]
		},
		{
			"code": "ES",
			"name": "Spain",
			"latitude": 40.46,
			"longitude": -3.75,
			"resources": [
				{"id": "es_composite_resin", "name": "Composite Resin"},
				{"id": "es_ceramic_insulators", "name": "Ceramic Insulators"},
				{"id": "es_solar_cells", "name": "Solar Cells"}
			]
		}
	]


static func get_country(code: String) -> Dictionary:
	var normalized := code.to_upper()
	for country in all():
		if String(country.get("code", "")) == normalized:
			return country.duplicate(true)
	return {}


static func get_resources(code: String) -> Array[Dictionary]:
	var country := get_country(code)
	var result: Array[Dictionary] = []
	for resource in country.get("resources", []):
		result.append((resource as Dictionary).duplicate(true))
	return result


static func roll_resource_drops(
	country_code: String,
	chance: float = 0.40,
	rolls: Array = []
) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var resources := get_resources(country_code)
	var clamped_chance := clampf(chance, 0.0, 1.0)

	for index in range(resources.size()):
		var roll := randf()
		if index < rolls.size():
			roll = float(rolls[index])

		if roll < clamped_chance:
			var resource := resources[index].duplicate(true)
			resource["country_code"] = country_code.to_upper()
			drops.append(resource)

	return drops


static func resource_names(code: String) -> PackedStringArray:
	var names := PackedStringArray()
	for resource in get_resources(code):
		names.append(String(resource.get("name", "Resource")))
	return names
