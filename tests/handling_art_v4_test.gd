extends SceneTree

# Regression checks for the art wired into the Skyrama-style airport.
# Gameplay still uses square_grid_iso_v1 and instant handling transfers.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for item in [
		["basic_fuel", Vector2i(2, 2), Vector2i(128, 64), 1],
		["ground_ops_depot", Vector2i(1, 1), Vector2i(64, 32), 1],
		["small_hangar", Vector2i(4, 3), Vector2i(224, 112), 2]
	]:
		var id := String(item[0])
		var definition := BuildingCatalog.get_definition(id)
		if definition.is_empty():
			_fail("Missing building definition: %s" % id)
			return
		if definition.get("footprint") != item[1]:
			_fail("Grid footprint unexpectedly changed for %s" % id)
			return
		if not bool(definition.get("grid_first_world_sprite", false)):
			_fail("Grid-first building layer missing for %s" % id)
			return
		var pad_paths: PackedStringArray = definition.get(
			"grid_native_surface_paths", PackedStringArray()
		)
		var building_paths: PackedStringArray = definition.get(
			"grid_first_structure_paths", PackedStringArray()
		)
		if pad_paths.size() != int(item[3]):
			_fail("Incorrect pad orientation count for %s" % id)
			return
		if building_paths.size() != int(item[3]):
			_fail("Incorrect building orientation count for %s" % id)
			return
		for pad_path in pad_paths:
			var pad = load(pad_path)
			if not (pad is Texture2D):
				_fail("Missing/import-failed pad: %s" % pad_path)
				return
			if pad.get_size() != Vector2(item[2]):
				_fail("Pad does not match grid contract: %s" % pad_path)
				return
		for building_path in building_paths:
			if not (load(building_path) is Texture2D):
				_fail("Missing/import-failed building art: %s" % building_path)
				return

	var motion := AircraftMotionArt.validate_catalog()
	if not bool(motion.get("valid", false)):
		_fail("Runway motion FX invalid: %s" % str(motion.get("errors", [])))
		return

	print("HANDLING_ART_V4_OK fuel=true cargo=true hangar=true rotations=true runway_fx=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
