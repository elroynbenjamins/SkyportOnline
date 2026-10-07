extends Camera2D

signal world_tapped(world_position: Vector2)
signal world_dragged(world_position: Vector2)
signal world_hovered(world_position: Vector2)

const MIN_ZOOM := 0.48
const MAX_ZOOM := 1.70
const ZOOM_STEP := 1.12
const TAP_SLOP := 14.0
const KEYBOARD_PAN_SPEED := 520.0

var touches: Dictionary = {}
var touch_starts: Dictionary = {}
var last_pinch_distance := 0.0
var multi_touch_active := false
var mouse_left_down := false
var mouse_left_start := Vector2.ZERO
var mouse_left_dragged := false
var placement_drag_enabled := false
var focus_tween: Tween


func _process(delta: float) -> void:
	if placement_drag_enabled:
		return

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if direction.length_squared() > 0.0:
		_cancel_focus_tween()
		position += (
			direction.normalized()
			* KEYBOARD_PAN_SPEED
			* delta
			/ maxf(zoom.x, 0.01)
		)
		_clamp_position_to_limits()


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
		_cancel_focus_tween()
		touches[event.index] = event.position
		touch_starts[event.index] = event.position
		if touches.size() >= 2:
			multi_touch_active = true
			last_pinch_distance = _current_pinch_distance()
	else:
		var start_position: Vector2 = touch_starts.get(
			event.index,
			event.position
		)
		var was_tap := (
			not multi_touch_active
			and event.position.distance_to(start_position) <= TAP_SLOP
		)
		touches.erase(event.index)
		touch_starts.erase(event.index)
		last_pinch_distance = (
			_current_pinch_distance()
			if touches.size() == 2
			else 0.0
		)

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
			world_dragged.emit(_screen_to_world(event.position))
		else:
			pan_by_screen_delta(event.relative)
	elif touches.size() == 2:
		var current_distance := _current_pinch_distance()
		if last_pinch_distance > 0.0 and current_distance > 0.0:
			var ratio := current_distance / last_pinch_distance
			_zoom_at_screen_position(
				zoom.x * ratio,
				_current_pinch_midpoint()
			)
			last_pinch_distance = current_distance

	get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_cancel_focus_tween()

	if event.button_index == MOUSE_BUTTON_LEFT:
		mouse_left_down = event.pressed
		if event.pressed:
			mouse_left_start = event.position
			mouse_left_dragged = false
		else:
			var was_tap := (
				not mouse_left_dragged
				and event.position.distance_to(mouse_left_start) <= TAP_SLOP
			)
			if was_tap:
				world_tapped.emit(_screen_to_world(event.position))
				get_viewport().set_input_as_handled()

	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_screen_position(
			zoom.x * ZOOM_STEP,
			event.position
		)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_screen_position(
			zoom.x / ZOOM_STEP,
			event.position
		)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var left_down := bool(
		event.button_mask & MOUSE_BUTTON_MASK_LEFT
	)
	var right_down := bool(
		event.button_mask & MOUSE_BUTTON_MASK_RIGHT
	)
	var middle_down := bool(
		event.button_mask & MOUSE_BUTTON_MASK_MIDDLE
	)

	if left_down or right_down or middle_down:
		_cancel_focus_tween()
	elif not placement_drag_enabled:
		world_hovered.emit(_screen_to_world(event.position))

	if placement_drag_enabled and left_down:
		world_dragged.emit(_screen_to_world(event.position))
		get_viewport().set_input_as_handled()
		return

	if not placement_drag_enabled and left_down:
		if (
			mouse_left_dragged
			or event.position.distance_to(mouse_left_start) > TAP_SLOP
		):
			mouse_left_dragged = true
			pan_by_screen_delta(event.relative)
			get_viewport().set_input_as_handled()
		return

	if right_down or middle_down:
		pan_by_screen_delta(event.relative)
		get_viewport().set_input_as_handled()


func set_placement_drag_enabled(value: bool) -> void:
	placement_drag_enabled = value
	mouse_left_dragged = false


func pan_by_screen_delta(delta: Vector2) -> void:
	position -= delta / maxf(zoom.x, 0.01)
	_clamp_position_to_limits()


func set_zoom_level(value: float) -> void:
	_set_zoom_clamped(value)
	_clamp_position_to_limits()


func zoom_in() -> void:
	set_zoom_level(zoom.x * ZOOM_STEP)


func zoom_out() -> void:
	set_zoom_level(zoom.x / ZOOM_STEP)


func reset_view(
	world_position: Vector2 = Vector2(480, 480),
	zoom_level: float = 0.62
) -> void:
	_cancel_focus_tween()
	position = world_position
	_set_zoom_clamped(zoom_level)
	_clamp_position_to_limits()


func get_navigation_snapshot() -> Dictionary:
	return {
		"zoom": zoom.x,
		"min_zoom": MIN_ZOOM,
		"max_zoom": MAX_ZOOM,
		"touch_pan": true,
		"pinch_zoom": true,
		"mouse_left_pan": not placement_drag_enabled,
		"mouse_right_pan": true,
		"mouse_wheel_zoom": true,
		"keyboard_pan": not placement_drag_enabled,
		"fixed_angle": true
	}


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
		_clamp_position_to_limits()
		return

	focus_tween = create_tween()
	focus_tween.set_trans(Tween.TRANS_QUAD)
	focus_tween.set_ease(Tween.EASE_OUT)
	focus_tween.tween_property(
		self,
		"position",
		target,
		duration
	)


func _cancel_focus_tween() -> void:
	if focus_tween != null and focus_tween.is_valid():
		focus_tween.kill()
	focus_tween = null


func _zoom_at_screen_position(
	value: float,
	screen_position: Vector2
) -> void:
	var before := _screen_to_world(screen_position)
	_set_zoom_clamped(value)
	var after := _screen_to_world(screen_position)
	position += before - after
	_clamp_position_to_limits()


func _set_zoom_clamped(value: float) -> void:
	var clamped_value := clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * clamped_value


func _clamp_position_to_limits() -> void:
	var viewport_size := get_viewport_rect().size
	var half_view := (
		viewport_size * 0.5 / maxf(zoom.x, 0.01)
	)
	var min_x := float(limit_left) + half_view.x
	var max_x := float(limit_right) - half_view.x
	var min_y := float(limit_top) + half_view.y
	var max_y := float(limit_bottom) - half_view.y

	if min_x > max_x:
		position.x = float(limit_left + limit_right) * 0.5
	else:
		position.x = clampf(position.x, min_x, max_x)

	if min_y > max_y:
		position.y = float(limit_top + limit_bottom) * 0.5
	else:
		position.y = clampf(position.y, min_y, max_y)


func _current_pinch_distance() -> float:
	if touches.size() != 2:
		return 0.0
	var positions: Array = touches.values()
	var first: Vector2 = positions[0]
	var second: Vector2 = positions[1]
	return first.distance_to(second)


func _current_pinch_midpoint() -> Vector2:
	if touches.size() != 2:
		return get_viewport_rect().size * 0.5
	var positions: Array = touches.values()
	var first: Vector2 = positions[0]
	var second: Vector2 = positions[1]
	return (first + second) * 0.5


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return (
		get_canvas_transform().affine_inverse()
		* screen_position
	)
