extends SceneTree


const STARTER_INTEGRATED_IDS := [
	"small_terminal",
	"small_stand",
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
		var atlas_texture = load(atlas_path)
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
		var used := _alpha_used_rect(region_image)
		if used.size.y <= 0:
			_fail("%s atlas region has no visible pixels." % building_id)
			return
		var visible_bottom := (
			rect.position.y
			+ (
				float(used.end.y)
				/ maxf(float(source_i.size.y), 1.0)
			) * rect.size.y
		)
		var footprint_polygon := grid._footprint_polygon(
			Vector2i.ZERO,
			footprint
		)
		var footprint_bottom := -INF
		for point_variant in footprint_polygon:
			footprint_bottom = maxf(
				footprint_bottom,
				(point_variant as Vector2).y
			)
		if absf(visible_bottom - footprint_bottom) > 1.5:
			_fail(
				"%s visible base %.2f should sit on footprint %.2f."
				% [building_id, visible_bottom, footprint_bottom]
			)
			return

	if not grid._definition_uses_integrated_world_base(
		BuildingCatalog.get_definition("small_terminal")
	):
		_fail("Integrated-base helper should recognize the terminal.")
		return

	print(
		"STARTER_BUILDING_GRID_FIT_OK integrated_bases=true "
		+ "procedural_underlays=false grounded=true raised_site_slab=false width_cap=1.35"
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
