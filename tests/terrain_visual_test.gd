extends SceneTree

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var owned_colors: Dictionary = {}
	var available_colors: Dictionary = {}
	var locked_colors: Dictionary = {}
	for y in range(6):
		for x in range(6):
			var tile := Vector2i(x, y)
			var owned := grid._terrain_color_for(
				tile,
				"owned"
			)
			var available := grid._terrain_color_for(
				tile,
				"available"
			)
			var locked := grid._terrain_color_for(
				tile,
				"locked"
			)
			owned_colors[owned.to_html()] = true
			available_colors[available.to_html()] = true
			locked_colors[locked.to_html()] = true

	if owned_colors.size() < 4:
		_fail(
			"Owned grass should use several subtle terrain variants."
		)
	if available_colors.size() < 3:
		_fail(
			"Available expansion land should use varied muted grass."
		)
	if locked_colors.size() < 3:
		_fail(
			"Locked land should use varied desaturated terrain."
		)

	var owned_line := grid._terrain_line_for_state(
		"owned"
	)
	var available_line := grid._terrain_line_for_state(
		"available"
	)
	var locked_line := grid._terrain_line_for_state(
		"locked"
	)
	if owned_line.a >= 0.05:
		_fail(
			"Normal owned land should not expose a strong tile grid."
		)
	if available_line.a <= owned_line.a:
		_fail(
			"Available expansion land should remain more readable than owned land."
		)
	if locked_line.a <= owned_line.a:
		_fail(
			"Locked expansion land should remain more readable than owned land."
		)

	var owned_sample := grid._terrain_color_for(
		Vector2i(3, 4),
		"owned"
	)
	var locked_sample := grid._terrain_color_for(
		Vector2i(3, 4),
		"locked"
	)
	if (
		locked_sample.get_luminance()
		>= owned_sample.get_luminance()
	):
		_fail(
			"Locked land should read darker than active airport grass."
		)

	var fuel_definition := BuildingCatalog.get_definition(
		"basic_fuel"
	)
	var fuel_ground := grid._building_ground_color(
		fuel_definition
	)
	var fuel_catalog_color: Color = fuel_definition.get(
		"color",
		Color.WHITE
	)
	if fuel_ground.is_equal_approx(fuel_catalog_color):
		_fail(
			"High-detail buildings should use neutral hardscape pads, not catalog tint colors."
		)
	if (
		maxf(
			fuel_ground.r,
			maxf(fuel_ground.g, fuel_ground.b)
		)
		- minf(
			fuel_ground.r,
			minf(fuel_ground.g, fuel_ground.b)
		)
		> 0.16
	):
		_fail(
			"Service-building hardscape should stay visually neutral."
		)

	var stand_ground := grid._building_ground_color(
		BuildingCatalog.get_definition("small_stand")
	)
	if stand_ground.a < 0.60:
		_fail(
			"Aircraft stands should retain a clearly readable apron base."
		)

	var north := grid.get_parcel("north")
	var north_state := String(
		north.get("progression_state", "")
	)
	if north_state != "available":
		_fail(
			"Terrain pass must not change expansion progression state."
		)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"TERRAIN_VISUAL_OK owned_variants=%d available_variants=%d locked_variants=%d"
		% [
			owned_colors.size(),
			available_colors.size(),
			locked_colors.size()
		]
	)
	quit(0)


func _fail(message: String) -> void:
	errors.append(message)
