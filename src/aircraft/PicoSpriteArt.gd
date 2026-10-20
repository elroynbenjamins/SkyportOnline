class_name PicoSpriteArt
extends RefCounted

# V2 is one transparent 256x256 source atlas split into 4 independent
# 128x128 direction sprites. Original /pixel/aircraft/pico_p8 PNGs remain
# available as a safe fallback for unsupported rendering environments.
const ATLAS_PATH := "res://assets/production/aircraft_pico_v2/pico_p8_refined_atlas.png"
const CELL_SIZE := 128.0
const DIRECTION_CELLS := {
	"ne": Vector2i(0, 0),
	"se": Vector2i(1, 0),
	"sw": Vector2i(0, 1),
	"nw": Vector2i(1, 1)
}

static var _atlas: Texture2D
static var _views: Dictionary = {}


static func texture_for(direction: String) -> Texture2D:
	if not DIRECTION_CELLS.has(direction):
		return null
	if _views.has(direction):
		return _views[direction] as Texture2D
	if _atlas == null:
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		var loaded := load(ATLAS_PATH)
		if not loaded is Texture2D:
			return null
		_atlas = loaded as Texture2D
	if _atlas.get_width() != 256 or _atlas.get_height() != 256:
		return null

	var cell: Vector2i = DIRECTION_CELLS[direction]
	var sprite := AtlasTexture.new()
	sprite.atlas = _atlas
	sprite.region = Rect2(
		Vector2(cell) * CELL_SIZE,
		Vector2.ONE * CELL_SIZE
	)
	sprite.filter_clip = true
	_views[direction] = sprite
	return sprite


static func uses_refined_art() -> bool:
	return texture_for("ne") != null
