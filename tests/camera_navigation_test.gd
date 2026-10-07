extends SceneTree

const CAMERA_SCRIPT := preload(
	"res://src/world/CameraController.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var camera = CAMERA_SCRIPT.new()
	camera.limit_left = -4000
	camera.limit_top = -3000
	camera.limit_right = 4000
	camera.limit_bottom = 3000
	root.add_child(camera)
	await process_frame

	camera.reset_view()
	if camera.position.distance_to(Vector2(0, 390)) > 0.01:
		_fail("Default camera reset should frame the projected starter airport from the Skyrama-style view.")
		return
	if absf(camera.zoom.x - 0.84) > 0.001:
		_fail("Default camera zoom should keep the projected starter airport readable in landscape.")
		return

	camera.position = Vector2(100, 200)
	camera.set_zoom_level(1.0)
	camera.pan_by_screen_delta(Vector2(64, -32))
	if camera.position.distance_to(Vector2(36, 232)) > 0.01:
		_fail(
			"Screen drag should pan the fixed-angle airport camera."
		)
		return

	camera.set_zoom_level(99.0)
	var snapshot: Dictionary = camera.get_navigation_snapshot()
	if absf(
		camera.zoom.x - float(snapshot.get("max_zoom", 0.0))
	) > 0.001:
		_fail("Camera zoom-in should clamp at MAX_ZOOM.")
		return

	camera.set_zoom_level(0.01)
	snapshot = camera.get_navigation_snapshot()
	if absf(
		camera.zoom.x - float(snapshot.get("min_zoom", 0.0))
	) > 0.001:
		_fail("Camera zoom-out should clamp at MIN_ZOOM.")
		return

	camera.set_zoom_level(1.0)
	snapshot = camera.get_navigation_snapshot()
	for key in [
		"touch_pan",
		"pinch_zoom",
		"mouse_left_pan",
		"mouse_right_pan",
		"mouse_wheel_zoom",
		"keyboard_pan",
		"fixed_angle"
	]:
		if not bool(snapshot.get(key, false)):
			_fail("%s should be enabled in normal airport view." % key)
			return

	camera.set_placement_drag_enabled(true)
	snapshot = camera.get_navigation_snapshot()
	if bool(snapshot.get("mouse_left_pan", true)):
		_fail(
			"Left drag must control the building while placement is active."
		)
		return
	if bool(snapshot.get("keyboard_pan", true)):
		_fail(
			"Keyboard camera pan should pause during active placement."
		)
		return
	if not bool(snapshot.get("pinch_zoom", false)):
		_fail(
			"Pinch zoom should remain available while placing a building."
		)
		return

	print(
		"CAMERA_NAVIGATION_OK pan=touch+mouse+keys "
		+ "zoom=pinch+wheel range=0.48..1.70 fixed_angle=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
