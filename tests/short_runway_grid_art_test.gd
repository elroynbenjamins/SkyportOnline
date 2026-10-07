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

	if definition.get("footprint", Vector2i.ZERO) != Vector2i(8, 2):
		_fail("Short Runway must remain exactly 8x2 logical cells.")
		return
	if String(
		definition.get("art_tier", "")
	) != "grid_native_v3":
		_fail("Short Runway should use the grid-native v3 art tier.")
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
	if asset_size != Vector2i(320, 160):
		_fail("8x2 Short Runway art must be authored at exactly 320x160 px.")
		return

	for path in paths:
		if not ResourceLoader.exists(path):
			_fail("Missing Short Runway production art: %s" % path)
			return
		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Short Runway art should import as Texture2D: %s" % path)
			return
		if texture.get_size() != Vector2(320, 160):
			_fail(
				"Short Runway texture must import at 320x160: %s"
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
	if int(contract_0.get("authoring_width_px", 0)) != 320:
		_fail("8x2 runway contract should require 320 px width.")
		return
	if int(contract_0.get("base_depth_px", 0)) != 160:
		_fail("8x2 runway contract should require 160 px base depth.")
		return
	if contract_0.get("runtime_scale", Vector2.ZERO) != Vector2.ONE:
		_fail("Short Runway should render at runtime scale 1:1.")
		return

	var contract_90 := grid.get_grid_visual_contract_for_definition(
		definition,
		1
	)
	if contract_90.get("footprint", Vector2i.ZERO) != Vector2i(2, 8):
		_fail("Rotated Short Runway should occupy exactly 2x8 cells.")
		return
	if int(contract_90.get("authoring_width_px", 0)) != 320:
		_fail("Rotated 2x8 runway should still use a 320 px art base.")
		return
	if int(contract_90.get("base_depth_px", 0)) != 160:
		_fail("Rotated 2x8 runway should still use a 160 px art depth.")
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
	if rect_0.size != Vector2(320, 160):
		_fail("Placed Short Runway should draw at exactly 320x160 world px.")
		return
	if rect_90.size != Vector2(320, 160):
		_fail("Rotated Short Runway should draw at exactly 320x160 world px.")
		return

	print(
		"SHORT_RUNWAY_GRID_ART_OK footprint=8x2 rotated=2x8 "
		+ "asset=320x160 runtime_scale=1 orientations=2"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
