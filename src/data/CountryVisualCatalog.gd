class_name CountryVisualCatalog
extends RefCounted


const ATLAS_PATH := "res://assets/pixel/countries/country_badges_v1.svg"
const CELL_WIDTH := 64
const CELL_HEIGHT := 48
const COLUMNS := 8

const FRAME_INDEX := {
	"NL": 0,
	"BE": 1,
	"DE": 2,
	"DK": 3,
	"GB": 4,
	"FR": 5,
	"ES": 6,
	"IT": 7,
	"US": 8,
	"CA": 9,
	"MX": 10,
	"BR": 11,
	"ZA": 12,
	"EG": 13,
	"AE": 14,
	"TR": 15,
	"IN": 16,
	"CN": 17,
	"JP": 18,
	"KR": 19,
	"ID": 20,
	"AU": 21,
	"NZ": 22,
}

static var _atlas: Texture2D
static var _texture_cache: Dictionary = {}


static func has_visual(country_code: String) -> bool:
	return FRAME_INDEX.has(country_code)


static func frame_count() -> int:
	return FRAME_INDEX.size()


static func texture_for_country(country_code: String) -> Texture2D:
	if _texture_cache.has(country_code):
		return _texture_cache[country_code] as Texture2D
	if not FRAME_INDEX.has(country_code):
		return null

	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		_atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null:
		return null

	var index := int(FRAME_INDEX[country_code])
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _atlas
	atlas_texture.region = Rect2(
		float(index % COLUMNS) * float(CELL_WIDTH),
		float(floori(float(index) / float(COLUMNS))) * float(CELL_HEIGHT),
		float(CELL_WIDTH),
		float(CELL_HEIGHT)
	)
	_texture_cache[country_code] = atlas_texture
	return atlas_texture


static func validate_catalog() -> Dictionary:
	var errors: Array[String] = []
	for country in CountryCatalog.get_countries():
		var country_code := String(country.get("id", ""))
		if not has_visual(country_code):
			errors.append("Missing country badge visual: %s" % country_code)
	return {"valid": errors.is_empty(), "errors": errors}
