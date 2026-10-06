class_name CountryResourceVisuals
extends RefCounted

const ATLAS_PATH := "res://assets/production/country_resources_v1/skyport_country_resources_atlas.svg"
const CELL_SIZE := Vector2i(96, 96)
const COLUMNS := 8

const RESOURCE_IDS := PackedStringArray([
	"nl_flowers",
	"nl_dairy",
	"nl_horticulture",
	"be_chocolate",
	"be_chemicals",
	"be_precision_parts",
	"de_machinery",
	"de_automotive_parts",
	"de_industrial_tools",
	"dk_pharma_goods",
	"dk_design_goods",
	"dk_renewable_parts",
	"gb_aerospace_parts",
	"gb_financial_docs",
	"gb_specialty_goods",
	"fr_luxury_goods",
	"fr_gourmet_food",
	"fr_cosmetics",
	"es_olive_products",
	"es_ceramic_materials",
	"es_citrus_goods",
	"it_fashion_goods",
	"it_machine_components",
	"it_specialty_foods",
	"us_flight_computers",
	"us_aerospace_systems",
	"us_industrial_chemicals",
	"ca_timber",
	"ca_potash",
	"ca_aircraft_components",
	"mx_vehicle_parts",
	"mx_silver_components",
	"mx_fresh_produce",
	"br_coffee",
	"br_biofuel",
	"br_regional_aircraft_parts",
	"za_industrial_minerals",
	"za_platinum_components",
	"za_fruit_exports",
	"eg_cotton",
	"eg_fertilizer",
	"eg_heat_resistant_glass",
	"ae_petrochemicals",
	"ae_aluminum",
	"ae_premium_goods",
	"tr_textiles",
	"tr_machinery",
	"tr_hazelnuts",
	"in_pharmaceuticals",
	"in_composite_textiles",
	"in_electrical_relays",
	"cn_microelectronics",
	"cn_rare_earth_parts",
	"cn_automation_machinery",
	"jp_precision_electronics",
	"jp_robotics_parts",
	"jp_optical_instruments",
	"kr_semiconductors",
	"kr_battery_cells",
	"kr_display_panels",
	"id_natural_rubber",
	"id_nickel_components",
	"id_tropical_products",
	"au_iron_ore",
	"au_wool",
	"au_lithium_components",
	"nz_dairy_products",
	"nz_timber_goods",
	"nz_weather_instruments"
])

static var _atlas_texture: Texture2D


static func has_visual(resource_id: String) -> bool:
	return RESOURCE_IDS.find(resource_id) >= 0


static func atlas_region(resource_id: String) -> Rect2:
	var index := RESOURCE_IDS.find(resource_id)
	if index < 0:
		return Rect2()
	var column := index % COLUMNS
	var row := index / COLUMNS
	return Rect2(
		Vector2(column * CELL_SIZE.x, row * CELL_SIZE.y),
		Vector2(CELL_SIZE)
	)


static func texture_for(resource_id: String) -> Texture2D:
	var region := atlas_region(resource_id)
	if region.size == Vector2.ZERO:
		return null
	if _atlas_texture == null:
		var loaded := load(ATLAS_PATH)
		if loaded is Texture2D:
			_atlas_texture = loaded as Texture2D
	if _atlas_texture == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlas_texture
	texture.region = region
	return texture
