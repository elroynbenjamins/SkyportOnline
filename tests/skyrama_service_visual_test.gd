extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _check_surface(
	id: String,
	expected_footprint: Vector2i,
	expected_size: Vector2i,
	expected_paths: int
) -> bool:
	var definition := BuildingCatalog.get_definition(id)
	if definition.is_empty():
		_fail("Missing service definition: %s" % id)
		return false
	if definition.get("footprint", Vector2i.ZERO) != expected_footprint:
		_fail("%s footprint changed unexpectedly." % id)
		return false
	if not bool(definition.get("grid_first_world_sprite", false)):
		_fail("%s should layer canonical building art over its grid pad." % id)
		return false
	var paths: PackedStringArray = definition.get(
		"grid_native_surface_paths",
		PackedStringArray()
	)
	if paths.size() != expected_paths:
		_fail("%s should expose %d service-pad orientation(s)." % [id, expected_paths])
		return false
	for asset_path in paths:
		if not ResourceLoader.exists(asset_path):
			_fail("Missing service-pad asset: %s" % asset_path)
			return false
		var texture = load(asset_path)
		if not (texture is Texture2D):
			_fail("Service-pad asset should import as Texture2D: %s" % asset_path)
			return false
		if texture.get_size() != Vector2(expected_size):
			_fail("%s service-pad size should be %s." % [id, str(expected_size)])
			return false
	return true


func _run() -> void:
	if not _check_surface(
		"basic_fuel",
		Vector2i(2, 2),
		Vector2i(128, 64),
		1
	):
		return
	if not _check_surface(
		"ground_ops_depot",
		Vector2i(1, 1),
		Vector2i(64, 32),
		1
	):
		return
	if not _check_surface(
		"small_hangar",
		Vector2i(3, 2),
		Vector2i(160, 80),
		2
	):
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	for item in [
		["basic_fuel", Vector2i(2, 7)],
		["ground_ops_depot", Vector2i(6, 7)],
		["small_hangar", Vector2i(8, 6)]
	]:
		var id := String(item[0])
		var cell: Vector2i = item[1]
		var preview := grid.set_build_preview(
			id,
			grid.tile_to_world(Vector2(cell.x, cell.y)),
			0
		)
		if not bool(preview.get("valid", false)):
			_fail("Could not place %s for service visual QA." % id)
			return
		grid.confirm_build_preview()

	var fuel := grid.get_best_service_building("fuel", "S")
	var cargo := grid.get_best_service_building("cargo", "S")
	if fuel.is_empty() or cargo.is_empty():
		_fail("Fuel and cargo structures should remain usable service targets.")
		return

	var fuel_center := grid.tile_to_world(Vector2(2.5, 7.5))
	if fuel.get("world_position", Vector2.ZERO).y <= fuel_center.y:
		_fail("Fuel aircraft slot should sit toward the front of its service pad.")
		return

	print(
		"SKYRAMA_SERVICE_VISUAL_OK fuel=2x2 cargo=1x1 hangar=3x2 "
		+ "grid_native=true canonical_sprite=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
