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
		"taxiway"
	)
	if definition.is_empty():
		_fail("Taxiway definition should exist.")
		return
	if definition.get("footprint", Vector2i.ZERO) != Vector2i.ONE:
		_fail("Taxiway must remain exactly 1x1 logical cell.")
		return
	if String(
		definition.get("visual_contract", "")
	) != "square_grid_iso_v1":
		_fail("Taxiway should declare the square-grid visual contract.")
		return

	var paths: PackedStringArray = definition.get(
		"grid_native_surface_paths",
		PackedStringArray()
	)
	if paths.size() != 1:
		_fail("1x1 taxiway should use one orientation-independent base asset.")
		return
	if not ResourceLoader.exists(paths[0]):
		_fail("Missing taxiway production art.")
		return
	var texture = load(paths[0])
	if not (texture is Texture2D):
		_fail("Taxiway production art should import as Texture2D.")
		return
	if texture.get_size() != Vector2(64, 32):
		_fail("1x1 taxiway art must import at exactly 64x32 px.")
		return

	var atlas_path := String(
		definition.get(
			"grid_native_autotile_atlas_path",
			""
		)
	)
	if atlas_path.is_empty() or not ResourceLoader.exists(atlas_path):
		_fail("Taxiway should expose its 16-state autotile atlas.")
		return
	var atlas = load(atlas_path)
	if not (atlas is Texture2D):
		_fail("Taxiway autotile atlas should import as Texture2D.")
		return
	if atlas.get_size() != Vector2(256, 128):
		_fail("16-state taxiway atlas must import at 256x128 px.")
		return
	if int(
		definition.get(
			"grid_native_autotile_variant_count",
			0
		)
	) != 16:
		_fail("Taxiway should expose all 16 N/E/S/W connection states.")
		return

	var contract := BuildingPlacementGrid.visual_contract(
		Vector2i.ONE
	)
	if int(contract.get("authoring_width_px", 0)) != 64:
		_fail("1x1 taxiway contract should require 64 px width.")
		return
	if int(contract.get("base_depth_px", 0)) != 32:
		_fail("1x1 taxiway contract should require 32 px depth.")
		return
	if contract.get("runtime_scale", Vector2.ZERO) != Vector2.ONE:
		_fail("Taxiway should render at runtime scale 1:1.")
		return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	if not _place(
		grid,
		"short_runway",
		Vector2i(2, 2)
	):
		return
	if not _place(
		grid,
		"taxiway",
		Vector2i(6, 4)
	):
		return

	var runway_join := grid.get_taxiway_visual_connection_snapshot(
		Vector2i(6, 4)
	)
	if not bool(runway_join.get("runway_connected", false)):
		_fail("Taxiway touching the runway should auto-detect the runway seam.")
		return
	if int(runway_join.get("connection_count", 0)) != 1:
		_fail("First taxiway should initially have one visual connection.")
		return
	if int(runway_join.get("mask", -1)) != 1:
		_fail("Runway-only taxiway should resolve to north bitmask 1.")
		return
	if String(runway_join.get("variant_name", "")) != "dead_n":
		_fail("Runway-only taxiway should use dead_n art.")
		return

	if not _place(
		grid,
		"taxiway",
		Vector2i(6, 5)
	):
		return
	runway_join = grid.get_taxiway_visual_connection_snapshot(
		Vector2i(6, 4)
	)
	if int(runway_join.get("connection_count", 0)) != 2:
		_fail("Runway taxiway should connect to both runway and next taxiway.")
		return
	if int(runway_join.get("mask", -1)) != 5:
		_fail("Runway plus south taxiway should resolve to straight_ns mask 5.")
		return
	if String(runway_join.get("variant_name", "")) != "straight_ns":
		_fail("Runway plus south taxiway should use straight_ns art.")
		return

	var next_join := grid.get_taxiway_visual_connection_snapshot(
		Vector2i(6, 5)
	)
	var kinds: Dictionary = next_join.get("kinds", {})
	if not kinds.values().has("taxiway"):
		_fail("Adjacent taxiway tiles should visually join automatically.")
		return

	if not _place(grid, "taxiway", Vector2i(5, 5)):
		return
	if not _place(grid, "taxiway", Vector2i(7, 5)):
		return
	if not _place(grid, "taxiway", Vector2i(6, 6)):
		return

	var cross_join := grid.get_taxiway_visual_connection_snapshot(
		Vector2i(6, 5)
	)
	if int(cross_join.get("mask", -1)) != 15:
		_fail("Four connected directions should resolve to cross mask 15.")
		return
	if String(cross_join.get("variant_name", "")) != "cross":
		_fail("Four-direction taxiway should use cross art.")
		return
	var cross_region: Rect2 = cross_join.get(
		"atlas_region",
		Rect2()
	)
	if cross_region != Rect2(192, 96, 64, 32):
		_fail("Cross mask should resolve to the final atlas cell.")
		return

	var reachable: Array = grid.get_airside_status().get(
		"reachable_taxiway_cells",
		[]
	)
	if reachable.size() < 2:
		_fail("Taxiway auto-visuals must preserve the real routing network.")
		return

	print(
		"TAXIWAY_GRID_ART_OK footprint=1x1 asset=64x32 variants=16 "
		+ "dead_end=true straight=true cross=true runway_seam=auto routing=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
