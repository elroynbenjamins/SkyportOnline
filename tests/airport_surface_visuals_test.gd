extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var terminal := BuildingCatalog.get_definition("small_terminal")
	if terminal.is_empty():
		_fail("Small Terminal definition is missing.")
		return

	var paths: PackedStringArray = terminal.get(
		"world_sprite_paths",
		PackedStringArray()
	)
	if paths.size() != 2:
		_fail("Small Terminal should have two isometric orientation sprites.")
		return

	for path in paths:
		if not ResourceLoader.exists(path):
			_fail("Missing modern terminal sprite: %s" % path)
			return
		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Terminal sprite must import as Texture2D: %s" % path)
			return

	if String(terminal.get("icon_path", "")) != paths[0]:
		_fail("Terminal build icon should use the modern terminal art.")
		return

	var sprite_size: Vector2 = terminal.get(
		"world_sprite_size",
		Vector2.ZERO
	)
	if sprite_size.x < 220.0 or sprite_size.y < 160.0:
		_fail("Modern terminal should render larger than the old starter art.")
		return

	var stand_fill := AirportVisualStyle.tile_fill(
		"small_stand",
		Color.WHITE,
		false
	)
	var taxi_fill := AirportVisualStyle.tile_fill(
		"taxiway",
		Color.WHITE,
		false
	)
	var runway_fill := AirportVisualStyle.tile_fill(
		"short_runway",
		Color.WHITE,
		false
	)
	var road_fill := AirportVisualStyle.tile_fill(
		"service_road",
		Color.WHITE,
		false
	)

	if stand_fill == taxi_fill:
		_fail("Apron stands and taxiways need distinct surface colors.")
		return
	if taxi_fill == runway_fill:
		_fail("Taxiway and runway asphalt need distinct surface colors.")
		return
	if road_fill == taxi_fill:
		_fail("Service roads need a distinct visual identity from taxiways.")
		return

	if AirportVisualStyle.runway_number_for("short_runway") != "09":
		_fail("Short runway visual number should be 09.")
		return
	if AirportVisualStyle.runway_number_for("regional_runway") != "27":
		_fail("Regional runway visual number should be 27.")
		return

	if not AirportVisualStyle.is_airport_surface("medium_stand"):
		_fail("Medium stand should be recognized as an airport surface.")
		return
	if AirportVisualStyle.is_airport_surface("small_terminal"):
		_fail("Terminal must not be treated as a pavement surface.")
		return

	print(
		"Airport visual style passed: modern terminal, apron, taxiway, "
		+ "service-road and runway surface rules."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
