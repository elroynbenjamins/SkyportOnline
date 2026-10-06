class_name ResourceVisualCatalog
extends RefCounted


const ATLAS_PATH := "res://assets/pixel/resources/country_resource_icons_v1.png"
const CELL_SIZE := 96
const COLUMNS := 5

const FRAME_INDEX := {
	"flowers": 0,
	"dairy": 1,
	"machinery": 2,
	"tools": 3,
	"chemicals": 4,
	"food": 5,
	"produce": 6,
	"ceramics": 7,
	"textiles": 8,
	"electronics": 9,
	"lumber": 10,
	"minerals": 11,
	"fiber": 12,
	"oil": 13,
	"metals": 14,
	"rubber": 15,
	"coffee": 16,
	"iron_ore": 17,
	"documents": 18,
	"automotive": 19
}

const RESOURCE_VISUALS := {
	"nl_flowers": "flowers",
	"nl_dairy": "dairy",
	"nl_horticulture": "produce",
	"be_chocolate": "coffee",
	"be_chemicals": "chemicals",
	"be_precision_parts": "tools",
	"de_machinery": "machinery",
	"de_automotive_parts": "automotive",
	"de_industrial_tools": "tools",
	"dk_pharma_goods": "chemicals",
	"dk_design_goods": "textiles",
	"dk_renewable_parts": "machinery",
	"gb_aerospace_parts": "machinery",
	"gb_financial_docs": "documents",
	"gb_specialty_goods": "food",
	"fr_luxury_goods": "chemicals",
	"fr_gourmet_food": "food",
	"fr_cosmetics": "chemicals",
	"es_olive_products": "food",
	"es_ceramic_materials": "ceramics",
	"es_citrus_goods": "produce",
	"it_fashion_goods": "textiles",
	"it_machine_components": "machinery",
	"it_specialty_foods": "food",
	"us_flight_computers": "electronics",
	"us_aerospace_systems": "machinery",
	"us_industrial_chemicals": "chemicals",
	"ca_timber": "lumber",
	"ca_potash": "minerals",
	"ca_aircraft_components": "machinery",
	"mx_vehicle_parts": "automotive",
	"mx_silver_components": "metals",
	"mx_fresh_produce": "produce",
	"br_coffee": "coffee",
	"br_biofuel": "produce",
	"br_regional_aircraft_parts": "machinery",
	"za_industrial_minerals": "minerals",
	"za_platinum_components": "metals",
	"za_fruit_exports": "produce",
	"eg_cotton": "fiber",
	"eg_fertilizer": "produce",
	"eg_heat_resistant_glass": "minerals",
	"ae_petrochemicals": "oil",
	"ae_aluminum": "metals",
	"ae_premium_goods": "chemicals",
	"tr_textiles": "textiles",
	"tr_machinery": "machinery",
	"tr_hazelnuts": "coffee",
	"in_pharmaceuticals": "chemicals",
	"in_composite_textiles": "textiles",
	"in_electrical_relays": "electronics",
	"cn_microelectronics": "electronics",
	"cn_rare_earth_parts": "minerals",
	"cn_automation_machinery": "machinery",
	"jp_precision_electronics": "electronics",
	"jp_robotics_parts": "machinery",
	"jp_optical_instruments": "electronics",
	"kr_semiconductors": "electronics",
	"kr_battery_cells": "electronics",
	"kr_display_panels": "electronics",
	"id_natural_rubber": "rubber",
	"id_nickel_components": "metals",
	"id_tropical_products": "produce",
	"au_iron_ore": "iron_ore",
	"au_wool": "fiber",
	"au_lithium_components": "minerals",
	"nz_dairy_products": "dairy",
	"nz_timber_goods": "lumber",
	"nz_weather_instruments": "electronics"
}

static var _atlas: Texture2D
static var _texture_cache: Dictionary = {}


static func visual_key_for_resource(resource_id: String) -> String:
	return String(RESOURCE_VISUALS.get(resource_id, ""))


static func has_visual(resource_id: String) -> bool:
	var visual_key := visual_key_for_resource(resource_id)
	return not visual_key.is_empty() and FRAME_INDEX.has(visual_key)


static func texture_for_resource(resource_id: String) -> Texture2D:
	if _texture_cache.has(resource_id):
		return _texture_cache[resource_id] as Texture2D

	var visual_key := visual_key_for_resource(resource_id)
	if visual_key.is_empty() or not FRAME_INDEX.has(visual_key):
		return null

	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		_atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null:
		return null

	var index := int(FRAME_INDEX[visual_key])
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _atlas
	atlas_texture.region = Rect2(
		float(index % COLUMNS) * float(CELL_SIZE),
		float(index / COLUMNS) * float(CELL_SIZE),
		float(CELL_SIZE),
		float(CELL_SIZE)
	)
	_texture_cache[resource_id] = atlas_texture
	return atlas_texture


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	for country_code in CountryResourceCatalog.all().keys():
		for resource in CountryResourceCatalog.all()[country_code]:
			var resource_id := String(resource.get("id", ""))
			if not has_visual(resource_id):
				errors.append("Missing country-resource visual: %s" % resource_id)
	return {"valid": errors.is_empty(), "errors": errors}
