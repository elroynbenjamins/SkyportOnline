extends Camera2D

signal world_tapped(world_position: Vector2)
signal world_dragged(world_position: Vector2)

const MIN_ZOOM := 0.52
const MAX_ZOOM := 1.45
const TAP_SLOP := 14.0

var touches: Dictionary = {}
var touch_starts: Dictionary = {}
var last_pinch_distance := 0.0
var multi_touch_active := false
var mouse_left_down := false
var mouse_left_start := Vector2.ZERO
var placement_drag_enabled := false
var focus_tween: Tween


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touches[event.index] = event.position
		touch_starts[event.index] = event.position
		if touches.size() >= 2:
			multi_touch_active = true
			last_pinch_distance = _current_pinch_distance()
	else:
		var start_position: Vector2 = touch_starts.get(event.index, event.position)
		var was_tap := not multi_touch_active and event.position.distance_to(start_position) <= TAP_SLOP
		touches.erase(event.index)
		touch_starts.erase(event.index)
		last_pinch_distance = _current_pinch_distance() if touches.size() == 2 else 0.0

		if was_tap:
			world_tapped.emit(_screen_to_world(event.position))
		if touches.is_empty():
			multi_touch_active = false

	get_viewport().set_input_as_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	_cancel_focus_tween()
	touches[event.index] = event.position

	if touches.size() == 1:
		if placement_drag_enabled:
			world_dragged.emit(
				_screen_to_world(event.position)
			)
		else:
			position -= event.relative / zoom.x
	elif touches.size() == 2:
		var current_distance := _current_pinch_distance()
		if last_pinch_distance > 0.0 and current_distance > 0.0:
			var ratio := current_distance / last_pinch_distance
			_set_zoom_clamped(zoom.x * ratio)
		last_pinch_distance = current_distance

	get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index in [
		MOUSE_BUTTON_RIGHT,
		MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN
	]:
		_cancel_focus_tween()

	if event.button_index == MOUSE_BUTTON_LEFT:
		mouse_left_down = event.pressed
		if event.pressed:
			mouse_left_start = event.position
		elif event.position.distance_to(mouse_left_start) <= TAP_SLOP:
			world_tapped.emit(_screen_to_world(event.position))
			get_viewport().set_input_as_handled()

	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom_clamped(zoom.x * 1.12)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom_clamped(zoom.x / 1.12)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if (
		event.button_mask & MOUSE_BUTTON_MASK_LEFT
		or event.button_mask & MOUSE_BUTTON_MASK_RIGHT
	):
		_cancel_focus_tween()

	if (
		placement_drag_enabled
		and event.button_mask & MOUSE_BUTTON_MASK_LEFT
	):
		world_dragged.emit(
			_screen_to_world(event.position)
		)
		get_viewport().set_input_as_handled()
	elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		position -= event.relative / zoom.x
		get_viewport().set_input_as_handled()


func set_placement_drag_enabled(value: bool) -> void:
	placement_drag_enabled = value


func focus_world_position(
	world_position: Vector2,
	duration: float = 0.42,
	strength: float = 0.72
) -> void:
	_cancel_focus_tween()
	var target := position.lerp(
		world_position,
		clampf(strength, 0.0, 1.0)
	)
	if duration <= 0.0:
		position = target
		return

	focus_tween = create_tween()
	focus_tween.set_trans(
		Tween.TRANS_QUAD
	)
	focus_tween.set_ease(
		Tween.EASE_OUT
	)
	focus_tween.tween_property(
		self,
		"position",
		target,
		duration
	)


func _cancel_focus_tween() -> void:
	if (
		focus_tween != null
		and focus_tween.is_valid()
	):
		focus_tween.kill()
	focus_tween = null


func _set_zoom_clamped(value: float) -> void:
	var clamped_value := clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * clamped_value


func _current_pinch_distance() -> float:
	if touches.size() != 2:
		return 0.0
	var positions: Array = touches.values()
	var first: Vector2 = positions[0]
	var second: Vector2 = positions[1]
	return first.distance_to(second)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position
