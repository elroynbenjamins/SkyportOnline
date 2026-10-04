class_name CountryResourceCatalog
extends RefCounted


static func all() -> Dictionary:
	return {
		"NL": [
			{"id": "flowers", "name": "Flowers"},
			{"id": "dairy", "name": "Dairy"},
			{"id": "horticulture", "name": "Horticulture"}
		],
		"BE": [
			{"id": "chocolate", "name": "Chocolate"},
			{"id": "chemicals", "name": "Chemicals"},
			{"id": "precision_parts", "name": "Precision Parts"}
		],
		"GB": [
			{"id": "aerospace_parts", "name": "Aerospace Parts"},
			{"id": "financial_docs", "name": "Financial Documents"},
			{"id": "specialty_goods", "name": "Specialty Goods"}
		],
		"DE": [
			{"id": "machinery", "name": "Machinery"},
			{"id": "automotive_parts", "name": "Automotive Parts"},
			{"id": "industrial_tools", "name": "Industrial Tools"}
		],
		"FR": [
			{"id": "luxury_goods", "name": "Luxury Goods"},
			{"id": "gourmet_food", "name": "Gourmet Food"},
			{"id": "cosmetics", "name": "Cosmetics"}
		],
		"DK": [
			{"id": "pharma_goods", "name": "Pharma Goods"},
			{"id": "design_goods", "name": "Design Goods"},
			{"id": "renewable_parts", "name": "Renewable Parts"}
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


static func get_resource_name(resource_id: String) -> String:
	for country_code in all().keys():
		for resource_variant in all()[country_code]:
			var resource: Dictionary = resource_variant
			if String(resource.get("id", "")) == resource_id:
				return String(resource.get("name", resource_id))
	return resource_id
