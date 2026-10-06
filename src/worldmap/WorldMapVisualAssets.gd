class_name WorldMapVisualAssets
extends RefCounted


const ROOT := "res://assets/production/worldmap_v2/"

const OCEAN_TILE := ROOT + "ocean_tile_v2.svg"
const HUB_MARKER := ROOT + "hub_marker_v2.svg"
const AIRPORT_MARKER := ROOT + "airport_marker_v2.svg"
const AIRPORT_LOCKED := ROOT + "airport_locked_v2.svg"
const AIRPORT_SELECTED := ROOT + "airport_selected_v2.svg"
const ROUTE_PLANE := ROOT + "route_plane_v2.svg"
const ROUTE_BADGE_PANEL := ROOT + "route_badge_panel_v2.svg"
const TERRAIN_FOREST := ROOT + "terrain_forest_v2.svg"
const TERRAIN_MOUNTAIN := ROOT + "terrain_mountain_v2.svg"
const CLOUD_CLUSTER := ROOT + "cloud_cluster_v3.svg"
const SEA_GLINT := ROOT + "sea_glint_v3.svg"
const COUNTRY_FOCUS := ROOT + "country_focus_v3.svg"
const TERRAIN_CITY := ROOT + "terrain_city_v3.svg"

const REQUIRED := [
	OCEAN_TILE,
	HUB_MARKER,
	AIRPORT_MARKER,
	AIRPORT_LOCKED,
	AIRPORT_SELECTED,
	ROUTE_PLANE,
	ROUTE_BADGE_PANEL,
	TERRAIN_FOREST,
	TERRAIN_MOUNTAIN,
	CLOUD_CLUSTER,
	SEA_GLINT,
	COUNTRY_FOCUS,
	TERRAIN_CITY,
]

static var _texture_cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not (resource is Texture2D):
		return null
	_texture_cache[path] = resource
	return resource as Texture2D


static func validate_assets() -> Dictionary:
	var errors: Array[String] = []
	for path in REQUIRED:
		if not ResourceLoader.exists(path):
			errors.append("Missing World Map production art: %s" % path)
			continue
		if texture(path) == null:
			errors.append("World Map production art failed to load: %s" % path)
	return {"valid": errors.is_empty(), "errors": errors}
