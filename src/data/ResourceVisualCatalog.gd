class_name ResourceVisualCatalog
extends RefCounted


const ATLAS_PATH := "res://assets/pixel/resources/country_resource_icons_v2.svg"
const CELL_SIZE := 96
const COLUMNS := 8

# Every live country resource gets its own atlas frame. Frames reuse a coherent
# visual language, while country accents and subtype marks keep similar cargo
# categories distinguishable at a glance.
const FRAME_INDEX := {
	"nl_flowers": 0,
	"nl_dairy": 1,
	"nl_horticulture": 2,
	"be_chocolate": 3,
	"be_chemicals": 4,
	"be_precision_parts": 5,
	"de_machinery": 6,
	"de_automotive_parts": 7,
	"de_industrial_tools": 8,
	"dk_pharma_goods": 9,
	"dk_design_goods": 10,
	"dk_renewable_parts": 11,
	"gb_aerospace_parts": 12,
	"gb_financial_docs": 13,
	"gb_specialty_goods": 14,
	"fr_luxury_goods": 15,
	"fr_gourmet_food": 16,
	"fr_cosmetics": 17,
	"es_olive_products": 18,
	"es_ceramic_materials": 19,
	"es_citrus_goods": 20,
	"it_fashion_goods": 21,
	"it_machine_components": 22,
	"it_specialty_foods": 23,
	"us_flight_computers": 24,
	"us_aerospace_systems": 25,
	"us_industrial_chemicals": 26,
	"ca_timber": 27,
	"ca_potash": 28,
	"ca_aircraft_components": 29,
	"mx_vehicle_parts": 30,
	"mx_silver_components": 31,
	"mx_fresh_produce": 32,
	"br_coffee": 33,
	"br_biofuel": 34,
	"br_regional_aircraft_parts": 35,
	"za_industrial_minerals": 36,
	"za_platinum_components": 37,
	"za_fruit_exports": 38,
	"eg_cotton": 39,
	"eg_fertilizer": 40,
	"eg_heat_resistant_glass": 41,
	"ae_petrochemicals": 42,
	"ae_aluminum": 43,
	"ae_premium_goods": 44,
	"tr_textiles": 45,
	"tr_machinery": 46,
	"tr_hazelnuts": 47,
	"in_pharmaceuticals": 48,
	"in_composite_textiles": 49,
	"in_electrical_relays": 50,
	"cn_microelectronics": 51,
	"cn_rare_earth_parts": 52,
	"cn_automation_machinery": 53,
	"jp_precision_electronics": 54,
	"jp_robotics_parts": 55,
	"jp_optical_instruments": 56,
	"kr_semiconductors": 57,
	"kr_battery_cells": 58,
	"kr_display_panels": 59,
	"id_natural_rubber": 60,
	"id_nickel_components": 61,
	"id_tropical_products": 62,
	"au_iron_ore": 63,
	"au_wool": 64,
	"au_lithium_components": 65,
	"nz_dairy_products": 66,
	"nz_timber_goods": 67,
	"nz_weather_instruments": 68,
}

static var _atlas: Texture2D
static var _texture_cache: Dictionary = {}


static func visual_key_for_resource(resource_id: String) -> String:
	return resource_id if FRAME_INDEX.has(resource_id) else ""


static func has_visual(resource_id: String) -> bool:
	return FRAME_INDEX.has(resource_id)


static func frame_count() -> int:
	return FRAME_INDEX.size()


static func texture_for_resource(resource_id: String) -> Texture2D:
	if _texture_cache.has(resource_id):
		return _texture_cache[resource_id] as Texture2D

	if not FRAME_INDEX.has(resource_id):
		return null

	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		_atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null:
		return null

	var index := int(FRAME_INDEX[resource_id])
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _atlas
	atlas_texture.region = Rect2(
		float(index % COLUMNS) * float(CELL_SIZE),
		float(floori(float(index) / float(COLUMNS))) * float(CELL_SIZE),
		float(CELL_SIZE),
		float(CELL_SIZE)
	)
	_texture_cache[resource_id] = atlas_texture
	return atlas_texture


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	var used_frames := {}
	for country_code in CountryResourceCatalog.all().keys():
		for resource in CountryResourceCatalog.all()[country_code]:
			var resource_id := String(resource.get("id", ""))
			if not has_visual(resource_id):
				errors.append("Missing country-resource visual: %s" % resource_id)
				continue
			var frame := int(FRAME_INDEX[resource_id])
			if used_frames.has(frame):
				errors.append(
					"Country resources share v2 frame %d: %s / %s"
					% [frame, String(used_frames[frame]), resource_id]
				)
			else:
				used_frames[frame] = resource_id
	return {"valid": errors.is_empty(), "errors": errors}
