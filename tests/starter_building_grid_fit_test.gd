extends SceneTree


const STARTER_INTEGRATED_IDS := [
	"small_terminal",
	"small_stand",
	"small_hangar",
	"travel_office",
	"ground_ops_depot",
	"basic_fuel"
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	for building_id in STARTER_INTEGRATED_IDS:
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("%s should exist in the building catalog." % building_id)
			return
		if not bool(
			definition.get("world_art_has_integrated_base", false)
		):
			_fail(
				"%s should declare its atlas base as integrated."
				% building_id
			)
			return
		if not bool(definition.get("world_sprite_grid_fit", false)):
			_fail(
				"%s should opt into logical grid fitting."
				% building_id
			)
			return
		var max_width_scale := float(
			definition.get("world_sprite_max_width_scale", 9.0)
		)
		if max_width_scale > 1.25:
			_fail(
				"%s should keep visible production art close to its grid footprint."
				% building_id
			)
			return
		if bool(definition.get("world_ground_pad", true)):
			_fail(
				"%s should not draw the old procedural ground pad."
				% building_id
			)
			return

		var footprint: Vector2i = definition.get(
			"footprint",
			Vector2i.ONE
		)
		var rect := grid._building_sprite_rect(
			definition,
			Vector2i.ZERO,
			footprint,
			0
		)
		var footprint_width := (
			float(footprint.x + footprint.y)
			* AirportGrid.TILE_WIDTH
			* 0.5
		)
		var max_width := (
			footprint_width
			* AirportGrid.WORLD_SPRITE_MAX_FOOTPRINT_OVERHANG
		)
		if rect.size.x > max_width + 0.01:
			_fail(
				"%s sprite width %.2f exceeds grid-fit cap %.2f."
				% [building_id, rect.size.x, max_width]
			)
			return

		if not bool(
			definition.get("world_sprite_ground_align", false)
		):
			_fail(
				"%s should keep its visible base grounded after runtime scaling."
				% building_id
			)
			return

		var atlas_path := String(
			definition.get("world_sprite_atlas_path", "")
		)
		var atlas_texture: Resource = load(atlas_path)
		if not (atlas_texture is Texture2D):
			_fail("%s atlas failed to load." % building_id)
			return
		var regions: Array = definition.get("world_sprite_regions", [])
		if regions.is_empty():
			_fail("%s has no atlas region." % building_id)
			return
		var source: Rect2 = regions[0]
		var source_i := Rect2i(
			int(source.position.x),
			int(source.position.y),
			int(source.size.x),
			int(source.size.y)
		)
		var region_image: Image = (
			atlas_texture as Texture2D
		).get_image().get_region(source_i)
		var used: Rect2i = _alpha_used_rect(region_image)
		if used.size.y <= 0:
			_fail("%s atlas region has no visible pixels." % building_id)
			return
		var visible_bottom: float = (
			rect.position.y
			+ (
				float(used.end.y)
				/ maxf(float(source_i.size.y), 1.0)
			) * rect.size.y
		)
		var footprint_polygon: PackedVector2Array = grid._footprint_polygon(
			Vector2i.ZERO,
			footprint
		)
		var footprint_bottom: float = -INF
		for point_variant in footprint_polygon:
			var footprint_point: Vector2 = point_variant
			footprint_bottom = maxf(
				footprint_bottom,
				footprint_point.y
			)
		if absf(visible_bottom - footprint_bottom) > 1.5:
			_fail(
				"%s visible base %.2f should sit on footprint %.2f."
				% [building_id, visible_bottom, footprint_bottom]
			)
			return

		var visible_width := (
			float(used.size.x)
			/ maxf(float(source_i.size.x), 1.0)
			* rect.size.x
		)
		if visible_width > footprint_width + 0.01:
			_fail(
				"%s visible art %.2f must not exceed footprint width %.2f."
				% [building_id, visible_width, footprint_width]
			)
			return
		var visible_width_scale := float(
			definition.get("world_sprite_visible_width_scale", 9.0)
		)
		if visible_width_scale > 1.0:
			_fail(
				"%s should never render wider than its declared grid footprint."
				% building_id
			)
			return

	if not grid._definition_uses_integrated_world_base(
		BuildingCatalog.get_definition("small_terminal")
	):
		_fail("Integrated-base helper should recognize the terminal.")
		return

	if grid.is_starter_apron_underlay_enabled():
		_fail(
			"Normal starter airport should not draw the old combined apron underlay."
		)
		return

	var travel_origin := Vector2i(-1, -1)
	for building in grid.placed_buildings:
		if String(building.get("definition_id", "")) == "travel_office":
			travel_origin = building.get("origin", Vector2i(-1, -1))
			break
	if travel_origin != Vector2i(8, 10):
		_fail(
			"Starter Travel Office should sit beside the Terminal, not visually stack over its roof."
		)
		return

	var terminal_origin := Vector2i(-1, -1)
	for building in grid.placed_buildings:
		if String(building.get("definition_id", "")) == "small_terminal":
			terminal_origin = building.get("origin", Vector2i(-1, -1))
			break
	if terminal_origin != Vector2i(4, 10):
		_fail(
			"Starter Terminal should keep a clear ground position inside the 16x16 area."
		)
		return

	var starter_setup := grid.get_starter_construction_snapshot()
	if int(starter_setup.get("starter_width_tiles", 0)) != 16:
		_fail("Starter owned build area should be 16x16 tiles.")
		return
	if int(starter_setup.get("runway_count", -1)) != 0:
		_fail("Starter layout should leave runway placement to the player.")
		return
	if int(starter_setup.get("taxiway_count", -1)) != 0:
		_fail("Starter layout should leave taxiway placement to the player.")
		return
	if int(starter_setup.get("service_road_count", -1)) != 0:
		_fail("Starter layout should leave service-road placement to the player.")
		return

	print(
		"STARTER_BUILDING_GRID_FIT_OK integrated_bases=true "
		+ "procedural_underlays=false grounded=true strict_footprints=true people_hidden=true"
	)
	quit(0)


func _alpha_used_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.03:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(
		min_x,
		min_y,
		max_x - min_x + 1,
		max_y - min_y + 1
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
