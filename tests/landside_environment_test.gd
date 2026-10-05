extends SceneTree

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var scenery := grid.get_landside_scenery_layout()
	if scenery.size() < 5:
		_fail(
			"Landside environment should include parking, entrance, trees and hedge scenery."
		)

	var ids: Dictionary = {}
	for item_variant in scenery:
		var item: Dictionary = item_variant
		var id := String(item.get("id", ""))
		var path := String(item.get("path", ""))
		var position: Vector2 = item.get(
			"position",
			Vector2.ZERO
		)
		var size: Vector2 = item.get(
			"size",
			Vector2.ZERO
		)
		if id.is_empty():
			_fail("Landside scenery item is missing an id.")
			continue
		if ids.has(id):
			_fail("Duplicate landside scenery id: %s" % id)
		ids[id] = true

		if path.is_empty() or not ResourceLoader.exists(path):
			_fail("%s scenery asset is missing: %s" % [id, path])
			continue
		var resource = load(path)
		if not (resource is Texture2D):
			_fail("%s scenery asset should load as a Texture2D." % id)

		if size.x <= 0.0 or size.y <= 0.0:
			_fail("%s scenery item has invalid draw size." % id)

		var anchor_tile := grid.world_to_tile(position)
		if (
			anchor_tile.x >= 0
			and anchor_tile.y >= 0
			and anchor_tile.x
				< AirportGrid.PARCEL_COLUMNS * AirportGrid.PARCEL_SIZE
			and anchor_tile.y
				< AirportGrid.PARCEL_ROWS * AirportGrid.PARCEL_SIZE
		):
			_fail(
				"%s scenery anchor should remain outside the buildable airport grid; got %s."
				% [id, str(anchor_tile)]
			)

	for required_id in [
		"parking_west",
		"entrance_south_west",
		"trees_east",
		"trees_west",
		"hedge_south"
	]:
		if not ids.has(required_id):
			_fail("Missing required landside scenery: %s" % required_id)

	var road := grid.get_landside_access_road_points()
	if road.size() < 5:
		_fail("Airport access road should have a multi-segment authored path.")
	for point in road:
		var tile := grid.world_to_tile(point)
		if (
			tile.x >= 0
			and tile.y >= 0
			and tile.x
				< AirportGrid.PARCEL_COLUMNS * AirportGrid.PARCEL_SIZE
			and tile.y
				< AirportGrid.PARCEL_ROWS * AirportGrid.PARCEL_SIZE
		):
			_fail(
				"Access road control point should stay outside buildable land; got %s."
				% str(tile)
			)

	var before_layout := grid.export_airport_layout()
	grid._draw_landside_environment()
	var after_layout := grid.export_airport_layout()
	if before_layout != after_layout:
		_fail(
			"Decorative landside scenery must never mutate the player airport layout."
		)

	var terminal := {}
	for uid in range(1, 80):
		var building := grid.get_building(uid)
		if String(building.get("definition_id", "")) == "small_terminal":
			terminal = building
			break
	if terminal.is_empty():
		_fail("Starter airport should still contain a movable terminal.")
	else:
		var eligibility := grid.get_move_eligibility(
			int(terminal.get("uid", -1))
		)
		if not bool(eligibility.get("movable", false)):
			_fail(
				"Landside scenery must not make the Terminal fixed in place."
			)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"LANDSIDE_ENVIRONMENT_OK scenery=%d road_points=%d terminal_movable=true"
		% [scenery.size(), road.size()]
	)
	quit(0)


func _fail(message: String) -> void:
	errors.append(message)
