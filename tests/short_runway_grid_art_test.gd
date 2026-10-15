extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := BuildingCatalog.get_definition(
		"short_runway"
	)
	if definition.is_empty():
		_fail("Short Runway definition should exist.")
		return

	if definition.get("footprint", Vector2i.ZERO) != Vector2i(6, 2):
		_fail("Short Runway must remain exactly 6x2 logical cells.")
		return
	if String(
		definition.get("visual_contract", "")
	) != "square_grid_iso_v1":
		_fail("Short Runway should declare the square-grid visual contract.")
		return

	var paths: PackedStringArray = definition.get(
		"grid_native_surface_paths",
		PackedStringArray()
	)
	if paths.size() != 2:
		_fail("Short Runway should provide both gameplay orientations.")
		return

	var asset_size: Vector2i = definition.get(
		"grid_native_surface_size",
		Vector2i.ZERO
	)
	if asset_size != Vector2i(256, 128):
		_fail("6x2 Short Runway art must be authored at exactly 256x128 px.")
		return

	for path in paths:
		if not ResourceLoader.exists(path):
			_fail("Missing Short Runway production art: %s" % path)
			return
		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Short Runway art should import as Texture2D: %s" % path)
			return
		if texture.get_size() != Vector2(256, 128):
			_fail(
				"Short Runway texture must import at 256x128: %s"
				% path
			)
			return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	if not grid.is_grid_first_visual_reset_enabled():
		_fail("This QA expects grid-first reset to remain active.")
		return

	var contract_0 := grid.get_grid_visual_contract_for_definition(
		definition,
		0
	)
	if int(contract_0.get("authoring_width_px", 0)) != 224:
		_fail("6x2 runway contract should require 256 px width.")
		return
	if int(contract_0.get("base_depth_px", 0)) != 112:
		_fail("6x2 runway contract should require 128 px base depth.")
		return
	if contract_0.get("runtime_scale", Vector2.ZERO) != Vector2.ONE:
		_fail("Short Runway should render at runtime scale 1:1.")
		return

	var contract_90 := grid.get_grid_visual_contract_for_definition(
		definition,
		1
	)
	if contract_90.get("footprint", Vector2i.ZERO) != Vector2i(2, 6):
		_fail("Rotated Short Runway should occupy exactly 2x6 cells.")
		return
	if int(contract_90.get("authoring_width_px", 0)) != 224:
		_fail("Rotated 2x6 runway should still use a 256 px art base.")
		return
	if int(contract_90.get("base_depth_px", 0)) != 112:
		_fail("Rotated 2x6 runway should still use a 128 px art depth.")
		return

	var rect_0 := grid.get_grid_visual_draw_rect_for_definition(
		definition,
		Vector2i(8, 8),
		0,
		asset_size
	)
	var rect_90 := grid.get_grid_visual_draw_rect_for_definition(
		definition,
		Vector2i(8, 8),
		1,
		asset_size
	)
	if rect_0.size != Vector2(256, 128):
		_fail("Placed Short Runway should draw at exactly 256x128 world px.")
		return
	if rect_90.size != Vector2(256, 128):
		_fail("Rotated Short Runway should draw at exactly 256x128 world px.")
		return

	var bounds_0 := BuildingPlacementGrid.footprint_bounds(
		Vector2i(8, 8),
		Vector2i(6, 2)
	)
	var bounds_90 := BuildingPlacementGrid.footprint_bounds(
		Vector2i(8, 8),
		Vector2i(2, 6)
	)
	if rect_0.position != bounds_0.position:
		_fail(
			"6x2 runway draw rect must start at the exact footprint bounds; "
			+ "no sideways anchor shift is allowed."
		)
		return
	if rect_90.position != bounds_90.position:
		_fail(
			"Rotated 2x6 runway draw rect must start at the exact footprint bounds."
		)
		return

	print(
		"SHORT_RUNWAY_GRID_ART_OK footprint=6x2 rotated=2x6 "
		+ "asset=256x128 runtime_scale=1 orientations=2"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
