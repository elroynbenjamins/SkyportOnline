class_name CountryResourceCatalog
extends RefCounted


static func all() -> Dictionary:
	return {
		"NL": [
			{"id":"nl_flowers","name":"Flowers"},
			{"id":"nl_dairy","name":"Dairy"},
			{"id":"nl_horticulture","name":"Horticulture"}
		],
		"BE": [
			{"id":"be_chocolate","name":"Chocolate"},
			{"id":"be_chemicals","name":"Specialty Chemicals"},
			{"id":"be_precision_parts","name":"Precision Parts"}
		],
		"DE": [
			{"id":"de_machinery","name":"Machinery"},
			{"id":"de_automotive_parts","name":"Automotive Parts"},
			{"id":"de_industrial_tools","name":"Industrial Tools"}
		],
		"DK": [
			{"id":"dk_pharma_goods","name":"Pharma Goods"},
			{"id":"dk_design_goods","name":"Design Goods"},
			{"id":"dk_renewable_parts","name":"Renewable Parts"}
		],
		"GB": [
			{"id":"gb_aerospace_parts","name":"Aerospace Parts"},
			{"id":"gb_financial_docs","name":"Financial Documents"},
			{"id":"gb_specialty_goods","name":"Specialty Goods"}
		],
		"FR": [
			{"id":"fr_luxury_goods","name":"Luxury Goods"},
			{"id":"fr_gourmet_food","name":"Gourmet Food"},
			{"id":"fr_cosmetics","name":"Cosmetics"}
		],
		"ES": [
			{"id":"es_olive_products","name":"Olive Products"},
			{"id":"es_ceramic_materials","name":"Ceramic Materials"},
			{"id":"es_citrus_goods","name":"Citrus Goods"}
		],
		"IT": [
			{"id":"it_fashion_goods","name":"Fashion Goods"},
			{"id":"it_machine_components","name":"Machine Components"},
			{"id":"it_specialty_foods","name":"Specialty Foods"}
		],
		"US": [
			{"id":"us_flight_computers","name":"Flight Computers"},
			{"id":"us_aerospace_systems","name":"Aerospace Systems"},
			{"id":"us_industrial_chemicals","name":"Industrial Chemicals"}
		],
		"CA": [
			{"id":"ca_timber","name":"Timber"},
			{"id":"ca_potash","name":"Potash"},
			{"id":"ca_aircraft_components","name":"Aircraft Components"}
		],
		"MX": [
			{"id":"mx_vehicle_parts","name":"Vehicle Parts"},
			{"id":"mx_silver_components","name":"Silver Components"},
			{"id":"mx_fresh_produce","name":"Fresh Produce"}
		],
		"BR": [
			{"id":"br_coffee","name":"Coffee"},
			{"id":"br_biofuel","name":"Biofuel"},
			{"id":"br_regional_aircraft_parts","name":"Regional Aircraft Parts"}
		],
		"ZA": [
			{"id":"za_industrial_minerals","name":"Industrial Minerals"},
			{"id":"za_platinum_components","name":"Platinum Components"},
			{"id":"za_fruit_exports","name":"Fruit Exports"}
		],
		"EG": [
			{"id":"eg_cotton","name":"Cotton"},
			{"id":"eg_fertilizer","name":"Fertilizer"},
			{"id":"eg_heat_resistant_glass","name":"Heat-Resistant Glass"}
		],
		"AE": [
			{"id":"ae_petrochemicals","name":"Petrochemicals"},
			{"id":"ae_aluminum","name":"Aluminum"},
			{"id":"ae_premium_goods","name":"Premium Goods"}
		],
		"TR": [
			{"id":"tr_textiles","name":"Textiles"},
			{"id":"tr_machinery","name":"Turkish Machinery"},
			{"id":"tr_hazelnuts","name":"Hazelnuts"}
		],
		"IN": [
			{"id":"in_pharmaceuticals","name":"Pharmaceuticals"},
			{"id":"in_composite_textiles","name":"Composite Textiles"},
			{"id":"in_electrical_relays","name":"Electrical Relays"}
		],
		"CN": [
			{"id":"cn_microelectronics","name":"Microelectronics"},
			{"id":"cn_rare_earth_parts","name":"Rare-Earth Parts"},
			{"id":"cn_automation_machinery","name":"Automation Machinery"}
		],
		"JP": [
			{"id":"jp_precision_electronics","name":"Precision Electronics"},
			{"id":"jp_robotics_parts","name":"Robotics Parts"},
			{"id":"jp_optical_instruments","name":"Optical Instruments"}
		],
		"KR": [
			{"id":"kr_semiconductors","name":"Semiconductors"},
			{"id":"kr_battery_cells","name":"Battery Cells"},
			{"id":"kr_display_panels","name":"Display Panels"}
		],
		"ID": [
			{"id":"id_natural_rubber","name":"Natural Rubber"},
			{"id":"id_nickel_components","name":"Nickel Components"},
			{"id":"id_tropical_products","name":"Tropical Products"}
		],
		"AU": [
			{"id":"au_iron_ore","name":"Iron Ore"},
			{"id":"au_wool","name":"Wool"},
			{"id":"au_lithium_components","name":"Lithium Components"}
		],
		"NZ": [
			{"id":"nz_dairy_products","name":"Dairy Products"},
			{"id":"nz_timber_goods","name":"Timber Goods"},
			{"id":"nz_weather_instruments","name":"Weather Instruments"}
		]
	}


static func resources_for_country(country_code: String) -> Array[Dictionary]:
	var catalog := all()
	if not catalog.has(country_code):
		return []

	var result: Array[Dictionary] = []
	for resource in catalog[country_code]:
		result.append(resource.duplicate(true))
	return result


static func get_resource(resource_id: String) -> Dictionary:
	for country_code in all().keys():
		for resource in all()[country_code]:
			if String(resource.get("id", "")) == resource_id:
				var result: Dictionary = resource.duplicate(true)
				result["country_code"] = String(country_code)
				return result
	return {}
