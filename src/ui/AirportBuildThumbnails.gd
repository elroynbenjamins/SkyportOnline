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
	if _fallback_cache.has(id):
		return _fallback_cache[id] as Texture2D
	var fill := "#6cbcc5"
	var pale := "#cef5e8"
	match kind:
		"parking":
			fill = "#87b9ac"
			pale = "#e2f8e9"
		"stand":
			fill = "#8bbac5"
			pale = "#e2f5f5"
		"tower":
			fill = "#89b6da"
			pale = "#e6f6ff"
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
		"parking":
			silhouette = '<path d="M15 53L50 30L82 50L47 75Z" fill="#849a9d" stroke="#effffc" stroke-width="2"/><path d="M28 54l18-12 20 12-18 12Z" fill="none" stroke="#fff6d7" stroke-width="2" stroke-dasharray="3 3"/><path d="M32 51l24 11m-10-23l8 17" stroke="#e5faff" stroke-width="1.4" opacity=".85"/>'
		"stand":
			silhouette = '<path d="M12 54l35-23 36 23-35 23Z" fill="#91b1bc" stroke="#f0fcff" stroke-width="2"/><path d="M29 58l17-13 18 13-17 12Z" fill="none" stroke="#f9eeb8" stroke-width="2"/><path d="M46 39l3 9 13 6-1 4-13-4-5 9-4-1 3-12-9-5 2-3 10 3z" fill="#f8fdfd" stroke="#3f7688" stroke-width="1.3"/>'
		"tower":
			silhouette = '<path d="M34 74l8-38h18l8 38z" fill="#aad2d7" stroke="#f7fffe" stroke-width="2"/><path d="M29 34h43l-5 10H34z" fill="#4f93ac" stroke="#ecfffe" stroke-width="2"/><path d="M48 22v11m0-9l11-3" stroke="#f6d997" stroke-width="3" stroke-linecap="round"/><rect x="39" y="47" width="18" height="6" fill="#659aaf"/>'
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
	svg += _detail_for_id(id)
	svg += '</svg>'

	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_fallback_cache[id] = texture
	return texture


# A small corner pictogram differentiates size and function even when
# full structure-specific production art is not available yet.
static func _detail_for_id(id: String) -> String:
	var icon := ""
	match id:
		"short_runway":
			icon = '<path d="M-8 0h16" stroke="#fff4c5" stroke-width="3" stroke-dasharray="3 3"/>'
		"regional_runway":
			icon = '<path d="M-10-5h20M-10 1h20M-10 7h20" stroke="#fff7d9" stroke-width="2"/>'
		"fuel_parking_s":
			icon = '<path d="M-7-8h9v14h-9zM2-4h5v7" stroke="#ffffff" fill="#72b7d3" stroke-width="2"/>'
		"cargo_parking_s":
			icon = '<path d="M-8-5l8-4 8 4v10L0 9l-8-4zM-8-5l8 5 8-5M0 0v9" stroke="#fff3cc" stroke-width="2" fill="none"/>'
		"small_stand":
			icon = '<path d="M0-9L3-1 9 2 8 5 2 4 0 10-2 4-8 5-9 2-3-1z" fill="#f8fcff"/>'
		"medium_stand":
			icon = '<path d="M0-11L4-2 11 1 10 5 2 4 0 11-2 4-10 5-11 1-4-2z" fill="#f8fcff"/>'
		"small_hangar":
			icon = '<path d="M-9 5v-9L0-9 9-4v9M-5 5v-6h10v6" fill="none" stroke="#e9fff7" stroke-width="2"/>'
		"medium_hangar":
			icon = '<path d="M-11 6v-12L0-11 11-6V6M-8 6v-8h16v8M-4 6v-8m8 8v-8" stroke="#e8fff9" stroke-width="2" fill="none"/>'
		"basic_fuel":
			icon = '<path d="M-6-8h10v16H-6zM4-4h5v10" fill="#ffd991" stroke="#ffffff" stroke-width="2"/>'
		"rapid_small_fuel", "rapid_regional_fuel":
			icon = '<path d="M-1-11l-8 12h8l-2 10L9-4H1z" fill="#fff2b0" stroke="#ffe6a0" stroke-width="1"/>'
		"regional_fuel":
			icon = '<rect x="-9" y="-7" width="8" height="16" rx="2" fill="#b4e9f7"/><rect x="2" y="-7" width="8" height="16" rx="2" fill="#b4e9f7"/>'
		"small_terminal":
			icon = '<path d="M-8 7v-14h16V7M-8-2h16M-3-7V7M4-7V7" fill="none" stroke="#efffff" stroke-width="2"/>'
		"airport_office":
			icon = '<path d="M-6 9v-18h11v18M-3-5h5M-3 0h5M-3 5h5" fill="none" stroke="#fff4ce" stroke-width="2"/>'
		"shuttle_station":
			icon = '<rect x="-11" y="-6" width="22" height="12" rx="3" fill="#ecf8ff"/><path d="M-7-3h14M-4 0v-3m8 3v-3" stroke="#6193a5" stroke-width="2"/><circle cx="-6" cy="7" r="2" fill="#3a6474"/><circle cx="6" cy="7" r="2" fill="#3a6474"/>'
		"travel_office":
			icon = '<rect x="-8" y="-9" width="16" height="19" rx="2" fill="#f6fbff"/><path d="M-4-4h8M-4 0h8M-4 4h5" stroke="#689bab" stroke-width="2"/>'
		"ground_ops_depot":
			icon = '<path d="M-10 4h20V-4H-3l-3-5h-6v13z" fill="#edfaff"/><circle cx="-5" cy="7" r="3" fill="#4c8aa3"/><circle cx="7" cy="7" r="3" fill="#4c8aa3"/>'
		"cleaning_center":
			icon = '<path d="M-8-3h13l-2 12h-9z" fill="#ccf3ff"/><path d="M-5-3v-6H5" stroke="#ffffff" stroke-width="2" fill="none"/><circle cx="8" cy="-7" r="3" fill="#ffffff"/><circle cx="11" cy="1" r="2" fill="#ffffff"/>'
		"passenger_service_hub":
			icon = '<circle cx="-6" cy="-5" r="3" fill="#ffffff"/><circle cx="4" cy="-5" r="3" fill="#ffffff"/><path d="M-12 9q0-10 6-10t6 10m-2 0q0-10 6-10t6 10" stroke="#e9fff9" stroke-width="3" fill="none"/>'
		"baggage_depot":
			icon = '<rect x="-8" y="-6" width="16" height="16" rx="2" fill="#fff1d5"/><path d="M-3-6v-4h6v4" stroke="#fff4dc" stroke-width="2" fill="none"/><path d="M0-5v13" stroke="#cd9c5c" stroke-width="2"/>'
		"catering_kitchen":
			icon = '<path d="M-6-9v17M-10-9v6h8v-6M6-9v17M6-9q6 4 0 9" stroke="#f7ffff" stroke-width="2.5" stroke-linecap="round" fill="none"/>'
		"tow_operations":
			icon = '<path d="M-10 2h15V-6H9V7H-10z" fill="#e7faff"/><path d="M9-6l5 4-5 4" stroke="#ffffff" stroke-width="2" fill="none"/><circle cx="-6" cy="8" r="2" fill="#3f7085"/><circle cx="6" cy="8" r="2" fill="#3f7085"/>'
		"atc_tower":
			icon = '<path d="M-7 9L-4-5h8L7 9M-10-5h20L7-9H-7z" stroke="#efffff" stroke-width="2" fill="#7bc4e0"/>'
		"apron_tile":
			icon = '<path d="M-10-10v20M0-10v20M10-10v20M-10 0h20" stroke="#eafff5" stroke-width="2"/>'
		"autumn_event_flag":
			icon = '<path d="M-8 10v-21M-7-9H9L5 0H-7" fill="#efab6c" stroke="#f9eed2" stroke-width="2"/>'
		"winter_event_flag":
			icon = '<path d="M-8 10v-21M-7-9H9L5 0H-7" fill="#9bcef5" stroke="#f9fdff" stroke-width="2"/>'
		"autumn_leaf_garden":
			icon = '<path d="M0 10V-9M0-6q-13-7-10 5 5 4 10-1M0-4q13-10 11 2-6 6-11 0" fill="#ffd186" stroke="#fff0ca" stroke-width="2"/>'
		"winter_snow_globe_garden":
			icon = '<circle r="9" fill="none" stroke="#f7ffff" stroke-width="2"/><path d="M-6 11h12M-8 0h16M0-8v16" stroke="#ecfcff" stroke-width="2"/>'
	if icon.is_empty():
		# Stable visual signature for unexpected new definitions so two new
		# structures cannot silently inherit an indistinguishable thumbnail.
		var strokes := 1 + posmod(id.hash(), 3)
		for i in range(strokes):
			var y := -5 + i * 5
			icon += '<path d="M-7 %dH7" stroke="#f5ffef" stroke-width="2"/>' % y
	return '<circle cx="79" cy="17" r="14" fill="#2d7180" stroke="#effff3" stroke-width="2"/><g transform="translate(79 17)">%s</g>' % icon


static func _kind(id: String, category: String) -> String:
	var key := id.to_lower()
	if key.contains("parking"):
		return "parking"
	if key.contains("stand"):
		return "stand"
	if key.contains("tower"):
		return "tower"
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
