extends SceneTree

const PlacementGrid := preload("res://src/build/BuildingPlacementGrid.gd")
const AirsideArt := preload("res://src/world/AirsideGroundArt.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if PlacementGrid.TILE_WIDTH != 64.0 or PlacementGrid.TILE_HEIGHT != 32.0:
		_fail("Canonical airport construction cell must remain 64x32.")
		return
	if AirsideArt.CELL_SIZE != Vector2i(64, 32):
		_fail("Airside atlas frames must exactly match the 64x32 construction cell.")
		return
	if AirsideArt.frame_count() != 45:
		_fail("Grid-native airside atlas should preserve all 45 modular frames.")
		return
	var required := {
		"taxiway": Vector2i(1, 1),
		"service_road": Vector2i(1, 1),
		"apron_tile": Vector2i(1, 1),
		"short_runway": Vector2i(7, 2),
	}
	for id_variant in required.keys():
		var id := String(id_variant)
		var definition := BuildingCatalog.get_definition(id)
		if definition.is_empty():
			_fail("%s definition should exist." % id)
			return
		if definition.get("footprint", Vector2i.ZERO) != required[id_variant]:
			_fail("%s footprint no longer matches its grid-native art contract." % id)
			return
		var icon_path := String(definition.get("icon_path", ""))
		if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
			_fail("%s should keep a production grid-native preview asset." % id)
			return
	for name_variant in AirsideArt.FRAME_INDEX.keys():
		var name := String(name_variant)
		if AirsideArt.texture_for_frame(name) == null:
			_fail("Missing grid-native airside frame: %s" % name)
			return
	print("GRID_NATIVE_ASSET_CONTRACT_OK tile=64x32 frames=45 lego_snap=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
