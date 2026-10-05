extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var services := [
		"fuel",
		"passenger",
		"cargo",
		"cleaning",
		"catering",
		"pushback"
	]

	for service_type in services:
		var path := GroundVehicleVisuals.atlas_path(service_type)
		if path.is_empty():
			_fail("Missing atlas path for %s." % service_type)
			return
		if not ResourceLoader.exists(path):
			_fail("Missing ground-service atlas: %s" % path)
			return

		var texture = load(path)
		if not (texture is Texture2D):
			_fail("Ground-service atlas is not a Texture2D: %s" % path)
			return
		if texture.get_width() != 256 or texture.get_height() != 64:
			_fail(
				"Ground-service atlas should be 256x64: %s is %dx%d."
				% [path, texture.get_width(), texture.get_height()]
			)
			return

		var display_size := GroundVehicleVisuals.display_size(
			service_type
		)
		if display_size.x <= 0.0 or display_size.y <= 0.0:
			_fail("Invalid display size for %s." % service_type)
			return

	var checks := [
		{"angle": -PI / 4.0, "index": 0, "name": "NE"},
		{"angle": PI / 4.0, "index": 1, "name": "SE"},
		{"angle": 3.0 * PI / 4.0, "index": 2, "name": "SW"},
		{"angle": -3.0 * PI / 4.0, "index": 3, "name": "NW"}
	]
	for check in checks:
		var actual := GroundVehicleVisuals.direction_index(
			float(check["angle"])
		)
		if actual != int(check["index"]):
			_fail(
				"%s direction should map to atlas index %d, got %d."
				% [check["name"], int(check["index"]), actual]
			)
			return

	print(
		"Ground-service sprites passed: 6 vehicle families × "
		+ "4 directional views."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
