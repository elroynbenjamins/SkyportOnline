class_name CharterVisualPack
extends RefCounted

const PACK_PATH := "res://cargo_charter_visual_pack_v1.zip"
const URI_PREFIX := "charter://"

static var _indexed := false
static var _available := false
static var _files := PackedStringArray()
static var _normalized_to_file: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func is_uri(path: String) -> bool:
	return path.begins_with(URI_PREFIX)


static func make_uri(asset_key: String, variant: int = 0) -> String:
	return "%s%s@%d" % [URI_PREFIX, asset_key, maxi(variant, 0)]


static func texture_from_uri(uri: String) -> Texture2D:
	if not is_uri(uri):
		return null
	var payload := uri.trim_prefix(URI_PREFIX)
	var variant := 0
	var asset_key := payload
	var separator := payload.rfind("@")
	if separator >= 0:
		var variant_text := payload.substr(separator + 1)
		if variant_text.is_valid_int():
			variant = maxi(int(variant_text), 0)
			asset_key = payload.substr(0, separator)
	return texture(asset_key, variant)


static func pack_available() -> bool:
	_ensure_index()
	return _available


static func list_files() -> PackedStringArray:
	_ensure_index()
	return _files.duplicate()


static func resolve_asset_file(
	asset_key: String,
	variant: int = 0
) -> String:
	_ensure_index()
	if not _available:
		return ""

	var normalized_key := _normalize(asset_key)
	if normalized_key.is_empty():
		return ""

	var candidates := _candidate_names(
		normalized_key,
		maxi(variant, 0)
	)
	for candidate in candidates:
		if _normalized_to_file.has(candidate):
			return String(
				_normalized_to_file[candidate]
			)

	var required_tokens := _meaningful_tokens(
		normalized_key
	)
	var best_file := ""
	var best_score := -100000
	for normalized_name_variant in _normalized_to_file.keys():
		var normalized_name := String(
			normalized_name_variant
		)
		var contains_all := true
		var token_score := 0
		for token in required_tokens:
			if normalized_name.contains(token):
				token_score += 10
			else:
				contains_all = false
				break
		if not contains_all:
			continue

		var score := token_score
		score += _variant_score(
			normalized_name,
			maxi(variant, 0)
		)
		score -= absi(
			normalized_name.length()
			- normalized_key.length()
		)
		if score > best_score:
			best_score = score
			best_file = String(
				_normalized_to_file[normalized_name]
			)

	if not best_file.is_empty():
		return best_file

	# Some pack filenames use broader visual labels. Fall back to the strongest
	# token overlap so the authored pack can be renamed without breaking saves.
	for normalized_name_variant in _normalized_to_file.keys():
		var normalized_name := String(
			normalized_name_variant
		)
		var score := 0
		for token in required_tokens:
			if normalized_name.contains(token):
				score += 6
		score += _variant_score(
			normalized_name,
			maxi(variant, 0)
		)
		if score > best_score and score >= 10:
			best_score = score
			best_file = String(
				_normalized_to_file[normalized_name]
			)
	return best_file


static func texture(
	asset_key: String,
	variant: int = 0
) -> Texture2D:
	var file_path := resolve_asset_file(
		asset_key,
		variant
	)
	if file_path.is_empty():
		return null

	if _texture_cache.has(file_path):
		return _texture_cache[file_path] as Texture2D

	var zip := ZIPReader.new()
	var open_error := zip.open(PACK_PATH)
	if open_error != OK:
		return null

	var bytes := zip.read_file(file_path)
	zip.close()
	if bytes.is_empty():
		return null

	var image := Image.new()
	var extension := file_path.get_extension().to_lower()
	var image_error := ERR_FILE_UNRECOGNIZED
	match extension:
		"png":
			image_error = image.load_png_from_buffer(bytes)
		"webp":
			image_error = image.load_webp_from_buffer(bytes)
		"jpg", "jpeg":
			image_error = image.load_jpg_from_buffer(bytes)
		_:
			image_error = image.load_png_from_buffer(bytes)
			if image_error != OK:
				image_error = image.load_webp_from_buffer(bytes)
			if image_error != OK:
				image_error = image.load_jpg_from_buffer(bytes)

	if image_error != OK or image.is_empty():
		return null

	var result := ImageTexture.create_from_image(image)
	_texture_cache[file_path] = result
	return result


static func reset_cache() -> void:
	_indexed = false
	_available = false
	_files = PackedStringArray()
	_normalized_to_file.clear()
	_texture_cache.clear()


static func _ensure_index() -> void:
	if _indexed:
		return
	_indexed = true
	_available = false
	_files = PackedStringArray()
	_normalized_to_file.clear()

	var zip := ZIPReader.new()
	var open_error := zip.open(PACK_PATH)
	if open_error != OK:
		return

	_files = zip.get_files()
	for file_path_variant in _files:
		var file_path := String(file_path_variant)
		if file_path.is_empty() or file_path.ends_with("/"):
			continue
		var extension := file_path.get_extension().to_lower()
		if extension not in ["png", "webp", "jpg", "jpeg"]:
			continue
		var normalized := _normalize(file_path)
		if normalized.is_empty():
			continue
		# Prefer the first authored occurrence when a pack contains thumbnails
		# or duplicate convenience copies.
		if not _normalized_to_file.has(normalized):
			_normalized_to_file[normalized] = file_path

	zip.close()
	_available = not _normalized_to_file.is_empty()


static func _normalize(value: String) -> String:
	var normalized := value.get_file().get_basename().to_lower()
	normalized = normalized.replace("-", "_")
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace(".", "_")
	while normalized.contains("__"):
		normalized = normalized.replace("__", "_")
	return normalized.trim_prefix("_").trim_suffix("_")


static func _meaningful_tokens(
	normalized_key: String
) -> PackedStringArray:
	var ignored := PackedStringArray([
		"asset",
		"sprite",
		"transparent",
		"cropped",
		"final",
		"visual",
		"v1"
	])
	var result := PackedStringArray()
	for token_variant in normalized_key.split("_", false):
		var token := String(token_variant)
		if token.length() <= 1 or ignored.has(token):
			continue
		result.append(token)
	return result


static func _candidate_names(
	normalized_key: String,
	variant: int
) -> PackedStringArray:
	var suffixes := PackedStringArray()
	if variant % 2 == 0:
		suffixes = PackedStringArray([
			"a",
			"left",
			"view_a",
			"angle_a",
			"01",
			"1"
		])
	else:
		suffixes = PackedStringArray([
			"b",
			"right",
			"view_b",
			"angle_b",
			"02",
			"2"
		])

	var result := PackedStringArray()
	for suffix in suffixes:
		result.append(
			"%s_%s" % [normalized_key, suffix]
		)
		result.append(
			"%s%s" % [normalized_key, suffix]
		)
	result.append(normalized_key)
	return result


static func _variant_score(
	normalized_name: String,
	variant: int
) -> int:
	var hints := PackedStringArray()
	if variant % 2 == 0:
		hints = PackedStringArray([
			"_a",
			"_left",
			"_view_a",
			"_angle_a",
			"_01",
			"_1"
		])
	else:
		hints = PackedStringArray([
			"_b",
			"_right",
			"_view_b",
			"_angle_b",
			"_02",
			"_2"
		])

	var score := 0
	for hint in hints:
		if normalized_name.ends_with(hint):
			score += 8
		elif normalized_name.contains(hint):
			score += 3
	return score
