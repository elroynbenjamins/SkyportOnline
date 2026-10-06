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

	if not grid._definition_uses_integrated_world_base(
		BuildingCatalog.get_definition("small_terminal")
	):
		_fail("Integrated-base helper should recognize the terminal.")
		return

	print(
		"STARTER_BUILDING_GRID_FIT_OK integrated_bases=true "
		+ "procedural_underlays=false width_cap=1.35"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
