extends Camera2D

signal world_tapped(world_position: Vector2)
signal emphasis_started(kind: String)
signal emphasis_finished(kind: String)

const MIN_ZOOM := 0.52
const MAX_ZOOM := 1.45
const TAP_SLOP := 14.0

var touches: Dictionary = {}
var touch_starts: Dictionary = {}
var last_pinch_distance := 0.0
var multi_touch_active := false
var mouse_left_down := false
var mouse_left_start := Vector2.ZERO

var emphasis_tween: Tween
var emphasis_active := false
var emphasis_kind := ""
var emphasis_origin_position := Vector2.ZERO
var emphasis_origin_zoom := Vector2.ONE
var last_emphasis_target := Vector2.ZERO
var last_emphasis_zoom_multiplier := 1.0


func _unhandled_input(event: InputEvent) -> void:
	if (
		emphasis_active
		and (
			event is InputEventScreenTouch
			or event is InputEventScreenDrag
			or event is InputEventMouseButton
			or event is InputEventMouseMotion
		)
	):
		cancel_emphasis()

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
	touches[event.index] = event.position

	if touches.size() == 1:
		position -= event.relative / zoom.x
	elif touches.size() == 2:
		var current_distance := _current_pinch_distance()
		if last_pinch_distance > 0.0 and current_distance > 0.0:
			var ratio := current_distance / last_pinch_distance
			_set_zoom_clamped(zoom.x * ratio)
		last_pinch_distance = current_distance

	get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
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
	if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		position -= event.relative / zoom.x
		get_viewport().set_input_as_handled()


func play_emphasis(
	world_position: Vector2,
	kind: String = "focus",
	zoom_multiplier: float = 1.08,
	duration: float = 0.72,
	pan_weight: float = 0.18
) -> void:
	cancel_emphasis()

	emphasis_active = true
	emphasis_kind = kind
	emphasis_origin_position = position
	emphasis_origin_zoom = zoom
	last_emphasis_target = world_position
	last_emphasis_zoom_multiplier = zoom_multiplier

	var focus_position := position.lerp(
		world_position,
		clampf(pan_weight, 0.0, 0.35)
	)
	var target_zoom_value := clampf(
		zoom.x * zoom_multiplier,
		MIN_ZOOM,
		MAX_ZOOM
	)
	var focus_zoom := Vector2.ONE * target_zoom_value

	var in_duration := maxf(duration * 0.36, 0.08)
	var out_duration := maxf(duration - in_duration, 0.12)

	emphasis_started.emit(kind)
	emphasis_tween = create_tween()
	emphasis_tween.set_trans(Tween.TRANS_SINE)
	emphasis_tween.set_ease(Tween.EASE_OUT)
	emphasis_tween.set_parallel(true)
	emphasis_tween.tween_property(
		self,
		"position",
		focus_position,
		in_duration
	)
	emphasis_tween.tween_property(
		self,
		"zoom",
		focus_zoom,
		in_duration
	)

	emphasis_tween.chain()
	emphasis_tween.set_parallel(true)
	emphasis_tween.set_ease(Tween.EASE_IN_OUT)
	emphasis_tween.tween_property(
		self,
		"position",
		emphasis_origin_position,
		out_duration
	)
	emphasis_tween.tween_property(
		self,
		"zoom",
		emphasis_origin_zoom,
		out_duration
	)
	emphasis_tween.finished.connect(
		_on_emphasis_finished.bind(kind)
	)


func cancel_emphasis() -> void:
	if emphasis_tween != null and emphasis_tween.is_valid():
		emphasis_tween.kill()
	emphasis_tween = null
	if emphasis_active:
		position = emphasis_origin_position
		zoom = emphasis_origin_zoom
	emphasis_active = false
	emphasis_kind = ""


func is_emphasis_active() -> bool:
	return emphasis_active


func get_last_emphasis_request() -> Dictionary:
	return {
		"target": last_emphasis_target,
		"zoom_multiplier": last_emphasis_zoom_multiplier,
		"kind": emphasis_kind
	}


func _on_emphasis_finished(kind: String) -> void:
	emphasis_tween = null
	emphasis_active = false
	emphasis_kind = ""
	emphasis_finished.emit(kind)


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
