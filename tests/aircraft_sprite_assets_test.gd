extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var directions := ["ne", "se", "sw", "nw"]
	var checked := 0

	for profile in AircraftCatalog.all():
		var aircraft_id := String(profile.get("id", ""))
		var size_class := String(profile.get("size", ""))
		if size_class not in ["S", "M"]:
			continue

		for direction in directions:
			var path := (
				"res://assets/pixel/aircraft/%s/%s_%s.png"
				% [aircraft_id, aircraft_id, direction]
			)
			if not ResourceLoader.exists(path):
				_fail("Missing aircraft sprite: %s" % path)
				return

			var texture = load(path)
			if not (texture is Texture2D):
				_fail("Aircraft sprite is not a Texture2D: %s" % path)
				return
			if texture.get_width() <= 0 or texture.get_height() <= 0:
				_fail("Aircraft sprite has invalid dimensions: %s" % path)
				return
			checked += 1

	if checked != 36:
		_fail("Expected 36 S/M aircraft direction sprites, got %d." % checked)
		return

	print(
		"Aircraft sprite assets passed: 9 V1 aircraft × 4 directions = "
		+ "%d textures." % checked
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
