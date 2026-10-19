class_name AirportBuildThumbnails
extends RefCounted

# One thumbnail resolver for both the Build catalogue and building detail.
# Prefer actual grid-native production art; generate a small, consistent
# illustrated placeholder only when no suitable real asset is committed.
static var _fallback_cache: Dictionary = {}


static func for_definition(definition: Dictionary) -> Texture2D:
	if definition.is_empty():
		return null

	# Atlas entries are cropped to a single item, not shown as an entire
	# sheet. World building art is more useful than a generic menu symbol.
	var atlas_path := String(definition.get("world_sprite_atlas_path", ""))
	var regions: Array = definition.get("world_sprite_regions", [])
	if not atlas_path.is_empty() and not regions.is_empty() and regions[0] is Rect2:
		var atlas := ProductionUIAssets.texture(atlas_path)
		if atlas != null:
			var crop := AtlasTexture.new()
			crop.atlas = atlas
			crop.region = regions[0]
			crop.filter_clip = true
			return crop

	for key in ["grid_first_structure_paths", "world_sprite_paths"]:
		var paths: PackedStringArray = definition.get(key, PackedStringArray())
		for path in paths:
			var texture := ProductionUIAssets.texture(String(path))
			if texture != null:
				return texture

	for key in ["world_sprite_path", "icon_path"]:
		var texture := ProductionUIAssets.texture(String(definition.get(key, "")))
		if texture != null:
			return texture

	# A surface-only artwork is still more specific than an invented building.
	var surface_paths: PackedStringArray = definition.get(
		"grid_native_surface_paths", PackedStringArray()
	)
	for path in surface_paths:
		var ground := ProductionUIAssets.texture(String(path))
		if ground != null:
			return ground

	return _illustration(definition)


static func _illustration(definition: Dictionary) -> Texture2D:
	var id := String(definition.get("id", ""))
	var category := String(definition.get("category", ""))
	var kind := _kind(id, category)
	if _fallback_cache.has(kind):
		return _fallback_cache[kind] as Texture2D
	var fill := "#6cbcc5"
	var pale := "#cef5e8"
	match kind:
		"runway":
			fill = "#7eacc0"
			pale = "#d7edf5"
		"fuel":
			fill = "#79c3e2"
			pale = "#d6f1fc"
		"cargo":
			fill = "#e0b675"
			pale = "#fff0cf"
		"hangar":
			fill = "#85c3b4"
			pale = "#d8f3e7"
		"terminal":
			fill = "#8dc8e7"
			pale = "#e3f6ff"
		"decor":
			fill = "#a7d18a"
			pale = "#e4f5d7"

	# Each simplified silhouette is authored for the same square thumbnail,
	# with a common isometric floor and shadow. It is a deliberate fallback,
	# not a substitute for later grid-native building artwork.
	var silhouette := ""
	match kind:
		"runway":
			silhouette = '<path d="M20 55L56 23L76 40L40 72Z" fill="#526778" stroke="#e4f4ff" stroke-width="2"/><path d="M32 54l4-3m7-7l4-3m7-6l4-3" stroke="#fff3c6" stroke-width="3" stroke-linecap="round"/>'
		"fuel":
			silhouette = '<rect x="28" y="24" width="28" height="42" rx="5" fill="#f6d182" stroke="#f8fbff" stroke-width="2"/><rect x="33" y="29" width="18" height="15" rx="2" fill="#457e97"/><path d="M56 34h8l3 7v16q0 7-7 5" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M35 57h15" stroke="#7c684a" stroke-width="3"/>'
		"cargo":
			silhouette = '<path d="M24 37l24-12 23 11v29L48 78 24 64Z" fill="#dfad69" stroke="#fff8e8" stroke-width="2"/><path d="M24 37l24 13 23-14M48 50v28" stroke="#fff5d7" stroke-width="2"/><path d="M43 29l23 12-9 6-23-13Z" fill="#f8dc9c"/>'
		"hangar":
			silhouette = '<path d="M18 39L48 21L79 39V70H18Z" fill="#94c9c2" stroke="#f4fffc" stroke-width="2.5"/><path d="M22 40l26-15 26 15" fill="none" stroke="#5c8499" stroke-width="4"/><rect x="31" y="45" width="36" height="25" rx="3" fill="#426b7c" stroke="#d9f5ee" stroke-width="2"/><path d="M34 52h30M34 60h30" stroke="#93bfc8" stroke-width="2"/>'
		"terminal":
			silhouette = '<path d="M20 39l29-16 28 16v31H20Z" fill="#b8dded" stroke="#ffffff" stroke-width="2"/><rect x="25" y="44" width="47" height="17" rx="2" fill="#438ba5"/><path d="M35 44v17m13-17v17m12-17v17" stroke="#d7f6ff" stroke-width="2"/><rect x="40" y="62" width="19" height="8" fill="#6caeaf"/>'
		"decor":
			silhouette = '<path d="M47 71V33" stroke="#835f4a" stroke-width="6" stroke-linecap="round"/><circle cx="47" cy="31" r="17" fill="#7ac294"/><circle cx="35" cy="36" r="10" fill="#9adcad"/><circle cx="59" cy="38" r="11" fill="#a9e4b0"/>'
		_:
			silhouette = '<rect x="28" y="30" width="43" height="42" rx="4" fill="#9bc7cf" stroke="#f3fffd" stroke-width="2"/><path d="M22 35l28-15 27 15" fill="#ccebea" stroke="#f3fffd" stroke-width="2"/><rect x="35" y="41" width="10" height="11" fill="#467c93"/><rect x="53" y="41" width="11" height="11" fill="#467c93"/>'

	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'
	svg += '<rect x="2" y="2" width="92" height="92" rx="17" fill="%s" stroke="%s" stroke-width="2"/>' % [fill, pale]
	svg += '<path d="M12 74L48 90L86 72L51 55Z" fill="#204c54" opacity=".19"/>'
	svg += '<path d="M12 70L47 84L84 68L49 54Z" fill="#a5d5cd" stroke="#f2fff6" stroke-width="2"/>'
	svg += silhouette
	svg += '</svg>'

	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_fallback_cache[kind] = texture
	return texture


static func _kind(id: String, category: String) -> String:
	var key := id.to_lower()
	if key.contains("runway") or key.contains("taxiway"):
		return "runway"
	if key.contains("fuel"):
		return "fuel"
	if key.contains("cargo") or key.contains("container") or key.contains("warehouse"):
		return "cargo"
	if key.contains("hangar"):
		return "hangar"
	if key.contains("terminal") or category == "Passenger":
		return "terminal"
	if category == "Decorations" or key.contains("garden") or key.contains("tree"):
		return "decor"
	return "service"
