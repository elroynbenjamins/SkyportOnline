class_name ProductionUIAssets
extends RefCounted

const ROOT := "res://assets/ui/production_v3/"

const LEVEL_BADGE := ROOT + "level_badge.svg"
const IDENTITY_PANEL := ROOT + "identity_panel.svg"
const RESOURCE_CHIP := ROOT + "resource_chip.svg"
const WORLD_BUBBLE := ROOT + "world_bubble.svg"
const BUTTON_GREEN := ROOT + "button_green.svg"
const BUTTON_BLUE := ROOT + "button_blue.svg"
const BUTTON_GRAY := ROOT + "button_gray.svg"
const NAV_TILE := ROOT + "nav_tile.svg"
const NAV_TILE_SELECTED := ROOT + "nav_tile_selected.svg"
const PROGRESS_TRACK := ROOT + "progress_track.svg"
const PROGRESS_GREEN := ROOT + "progress_fill_green.svg"
const PROGRESS_BLUE := ROOT + "progress_fill_blue.svg"
const PROGRESS_GOLD := ROOT + "progress_fill_gold.svg"
const NOTIFICATION_BADGE := ROOT + "notification_badge.svg"
const SETTINGS_ICON := ROOT + "settings_icon.svg"

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


static func style_box(
	path: String,
	texture_margin: float = 18.0,
	content_margin: float = 8.0
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(path)
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style


static func button_style(path: String) -> StyleBoxTexture:
	return style_box(path, 22.0, 10.0)


static func progress_style(path: String) -> StyleBoxTexture:
	return style_box(path, 15.0, 3.0)
