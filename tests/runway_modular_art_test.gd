extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _place(
	grid: AirportGrid,
	building_id: String,
	cell: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(
			Vector2(cell.x, cell.y)
		),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"Could not place %s at %s: %s"
			% [
				building_id,
				str(cell),
				String(preview.get("reason", "invalid"))
			]
		)
		return false
	return not grid.confirm_build_preview().is_empty()


func _run() -> void:
	var definition := BuildingCatalog.get_definition(
		"short_runway"
	)
	if definition.is_empty():
		_fail("Short Runway definition should exist.")
		return
	if not bool(
		definition.get(
			"grid_native_modular_runway_exits",
			false
		)
	):
		_fail("Short Runway should enable modular runway exit art.")
		return
	if definition.get(
		"footprint",
		Vector2i.ZERO
	) != Vector2i(5, 2):
		_fail("Short Runway must remain exactly 5x2.")
		return

	var paths: PackedStringArray = definition.get(
		"grid_native_surface_paths",
		PackedStringArray()
	)
	if paths.size() != 2:
		_fail("Short Runway should keep two grid-native orientations.")
		return
	for path in paths:
		if not ResourceLoader.exists(path):
			_fail("Missing Short Runway surface art: %s" % path)
			return
		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Short Runway art should import as Texture2D.")
			return
		if texture.get_size() != Vector2(224, 112):
			_fail("Short Runway art must stay exactly 224x112 px.")
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(
		grid,
		"short_runway",
		Vector2i(4, 4)
	):
		return
	if not _place(
		grid,
		"taxiway",
		Vector2i(8, 3)
	):
		return
	if not _place(
		grid,
		"taxiway",
		Vector2i(9, 5)
	):
		return

	var runway_uid := -1
	for building_variant in grid.export_airport_layout():
		var building: Dictionary = building_variant
		if String(
			building.get(
				"definition_id",
				""
			)
		) == "short_runway":
			runway_uid = int(
				building.get("uid", -1)
			)
			break
	if runway_uid < 0:
		_fail("Short Runway UID should be available.")
		return

	var state := grid.get_runway_modular_visual_state(
		runway_uid
	)
	if not bool(state.get("modular", false)):
		_fail("Runway visual state should report modular=true.")
		return
	if int(
		state.get(
			"active_exit_count",
			0
		)
	) != 2:
		_fail("Mixed modular state should expose exactly two active exits.")
		return

	var types: Array = state.get(
		"active_exit_types",
		[]
	)
	if not types.has("side_upper"):
		_fail("Mixed modular state should include side_upper.")
		return
	if not types.has("forward_lower"):
		_fail("Mixed modular state should include forward_lower.")
		return

	print(
		"RUNWAY_MODULAR_ART_OK footprint=5x2 asset=224x112 "
		+ "base=true sockets=true mixed_pair=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
