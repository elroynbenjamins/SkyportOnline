extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := [
		{
			"id": "access_road",
			"icon": "res://assets/pixel/landside_v1/access_road.svg",
			"paths": []
		},
		{
			"id": "parking_lot",
			"icon": "res://assets/pixel/landside_v1/parking_lot.svg",
			"paths": [
				"res://assets/pixel/landside_v1/parking_lot.svg",
				"res://assets/pixel/landside_v1/parking_lot_b.svg"
			]
		},
		{
			"id": "terminal_forecourt",
			"icon": "res://assets/pixel/landside_v1/terminal_forecourt.svg",
			"paths": [
				"res://assets/pixel/landside_v1/terminal_forecourt.svg",
				"res://assets/pixel/landside_v1/terminal_forecourt_b.svg"
			]
		},
		{
			"id": "flower_strip",
			"icon": "res://assets/pixel/landside_v1/flower_strip.svg",
			"paths": [
				"res://assets/pixel/landside_v1/flower_strip.svg"
			]
		},
		{
			"id": "welcome_sign",
			"icon": "res://assets/pixel/landside_v1/welcome_sign.svg",
			"paths": [
				"res://assets/pixel/landside_v1/welcome_sign.svg"
			]
		}
	]

	for item in expected:
		var building_id := String(item["id"])
		var definition := BuildingCatalog.get_definition(
			building_id
		)
		if definition.is_empty():
			_fail("Missing landside definition: %s" % building_id)
			return
		if String(definition.get("category", "")) != "Decorations":
			_fail("%s should be in Decorations." % building_id)
			return
		if not bool(definition.get("cosmetic_only", false)):
			_fail("%s must stay cosmetic-only." % building_id)
			return
		if not bool(
			definition.get("suppress_world_label", false)
		):
			_fail("%s should suppress floating labels." % building_id)
			return
		if bool(definition.get("passenger_generator", false)):
			_fail("%s must not generate passengers." % building_id)
			return
		if not String(definition.get("service", "")).is_empty():
			_fail("%s must not provide service capacity." % building_id)
			return
		var services: Dictionary = definition.get(
			"services",
			{}
		)
		if not services.is_empty():
			_fail("%s must not provide multi-service capacity." % building_id)
			return

		var icon_path := String(item["icon"])
		if String(definition.get("icon_path", "")) != icon_path:
			_fail("%s icon path mismatch." % building_id)
			return
		if not ResourceLoader.exists(icon_path):
			_fail("Missing landside icon: %s" % icon_path)
			return
		var icon = load(icon_path)
		if not (icon is Texture2D):
			_fail("Landside icon must import as Texture2D: %s" % icon_path)
			return

		var expected_paths: Array = item["paths"]
		var actual_paths: Array[String] = []
		var single_path := String(
			definition.get("world_sprite_path", "")
		)
		if not single_path.is_empty():
			actual_paths.append(single_path)
		var variants: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		for path in variants:
			actual_paths.append(String(path))

		if actual_paths.size() != expected_paths.size():
			_fail("%s sprite variant count mismatch." % building_id)
			return

		for index in range(expected_paths.size()):
			var expected_path := String(expected_paths[index])
			if actual_paths[index] != expected_path:
				_fail("%s sprite path mismatch." % building_id)
				return
			if not ResourceLoader.exists(expected_path):
				_fail("Missing landside sprite: %s" % expected_path)
				return
			var texture = load(expected_path)
			if not (texture is Texture2D):
				_fail(
					"Landside sprite must import as Texture2D: %s"
					% expected_path
				)
				return

	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var before := grid.get_airside_status()
	grid.select_parcel("east")
	grid.purchase_selected()

	if not _place(grid, "access_road", Vector2i(16, 10)):
		return
	if not _place(grid, "access_road", Vector2i(17, 10)):
		return
	if not _place(grid, "parking_lot", Vector2i(18, 10)):
		return
	if not _place(grid, "terminal_forecourt", Vector2i(20, 10)):
		return
	if not _place(grid, "flower_strip", Vector2i(22, 12)):
		return
	if not _place(grid, "welcome_sign", Vector2i(22, 13)):
		return

	if grid.get_access_road_connection_count(
		Vector2i(16, 10)
	) != 1:
		_fail("First access road should connect to one landside neighbor.")
		return

	if grid.get_access_road_connection_count(
		Vector2i(17, 10)
	) != 2:
		_fail(
			"Second access road should connect to road and car park."
		)
		return

	var after := grid.get_airside_status()
	for key in [
		"runways",
		"taxiways",
		"stands_total",
		"stands_connected",
		"hangars_total",
		"hangars_connected"
	]:
		if int(after.get(key, -1)) != int(before.get(key, -2)):
			_fail(
				"Landside cosmetics must not change airside stat %s."
				% String(key)
			)
			return

	print(
		"Landside visuals passed: roads, parking, forecourt, "
		+ "landscaping and airport boundaries stay cosmetic."
	)
	quit(0)


func _place(
	grid: AirportGrid,
	building_id: String,
	tile: Vector2i
) -> bool:
	var preview := grid.set_build_preview(
		building_id,
		grid.tile_to_world(Vector2(tile.x, tile.y)),
		0
	)
	if not bool(preview.get("valid", false)):
		_fail(
			"%s should be placeable at %s: %s"
			% [
				building_id,
				str(tile),
				String(preview.get("reason", "unknown"))
			]
		)
		return false
	grid.confirm_build_preview()
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
