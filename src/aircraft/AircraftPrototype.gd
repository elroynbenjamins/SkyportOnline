class_name AircraftPrototype
extends Node2D

signal runway_cleared
signal hold_short_reached
signal departed
signal arrival_requested
signal arrival_completed
signal state_changed(state: String)

@export var taxi_speed: float = 105.0
@export var takeoff_speed: float = 235.0
@export var approach_speed: float = 185.0
@export var landing_speed: float = 150.0
@export var departure_delay: float = 0.55
@export var lineup_delay: float = 0.45
@export var taxi_acceleration: float = 95.0
@export var taxi_deceleration: float = 150.0


var departure_route := PackedVector2Array()
var arrival_route := PackedVector2Array()
var route_index := 0
var state := "PARKED"
var aircraft_size := "S"
var aircraft_type_id := ""
var aircraft_display_name := "Aircraft"
var aircraft_profile: Dictionary = {}
var flight_plan: Dictionary = {}
var event_featured := false
var event_theme := ""
var event_marker_text := ""
var event_livery_enabled := false
var stand_uid := -1
var runway_uid := -1

var delay_remaining := 0.0
var flight_remaining := 0.0
var takeoff_velocity := 0.0
var taxi_current_speed := 0.0
var taxi_turn_rate_deg := 145.0
var departure_hold_short_index := -1
var arrival_runway_cleared := false
var turnaround_panel: PanelContainer
var turnaround_label: Label
var taxi_traffic_controller: TaxiTrafficController
var taxi_holding := false
var taxi_hold_reason := ""


func _ready() -> void:
	_build_turnaround_status()


func configure_taxi_traffic(
	controller: TaxiTrafficController
) -> void:
	taxi_traffic_controller = controller
	if taxi_traffic_controller != null:
		taxi_traffic_controller.register_aircraft(self)


func is_taxi_holding() -> bool:
	return taxi_holding


func get_taxi_hold_reason() -> String:
	return taxi_hold_reason


func get_interaction_radius() -> float:
	match aircraft_size:
		"M":
			return 44.0
		"L":
			return 54.0
		"XL":
			return 64.0
		_:
			return 36.0


func contains_world_point(world_position: Vector2) -> bool:
	if not visible:
		return false
	return global_position.distance_to(world_position) <= (
		get_interaction_radius()
	)


func configure_aircraft_type(type_id: String) -> void:
	var profile: Dictionary = AircraftCatalog.get_profile(type_id)
	if profile.is_empty():
		return

	aircraft_type_id = type_id
	aircraft_profile = profile
	aircraft_display_name = String(profile.get("name", type_id))
	aircraft_size = String(profile.get("size", aircraft_size))
	taxi_speed = maxf(float(profile.get("taxi_speed", taxi_speed)), 1.0)
	taxi_turn_rate_deg = TaxiMotionRules.turn_rate_degrees(
		aircraft_size,
		profile
	)


func assign_flight_plan(plan: Dictionary) -> void:
	flight_plan = plan.duplicate(true)
	if state == "READY_FOR_DESTINATION" and not flight_plan.is_empty():
		_set_state("READY_FOR_DEPARTURE")


func set_event_visual(
	featured: bool,
	theme: String = "",
	marker_text: String = "",
	livery_enabled: bool = false
) -> void:
	event_featured = featured
	event_theme = theme
	event_marker_text = marker_text
	event_livery_enabled = livery_enabled
	queue_redraw()


func has_flight_plan() -> bool:
	return not flight_plan.is_empty()


func get_flight_plan() -> Dictionary:
	return flight_plan.duplicate(true)


func record_boarded_passengers(amount: int) -> void:
	if flight_plan.is_empty():
		return
	flight_plan["passengers_boarded"] = maxi(amount, 0)


func get_boarded_passengers() -> int:
	return maxi(
		int(flight_plan.get("passengers_boarded", 0)),
		0
	)


func get_aircraft_profile() -> Dictionary:
	return aircraft_profile.duplicate(true)


func get_flight_remaining_seconds() -> float:
	return maxf(flight_remaining, 0.0)


func get_turnaround_seconds(
	fuel_speed: float = 1.0,
	is_returning: bool = true
) -> float:
	return TurnaroundRules.estimated_turnaround_seconds(
		aircraft_profile,
		fuel_speed,
		is_returning
	)


func get_service_docking_position(
	service_type: String,
	service_key: String = ""
) -> Vector2:
	return to_global(
		get_service_docking_local_offset(
			service_type,
			service_key
		)
	)


func get_service_docking_local_offset(
	service_type: String,
	service_key: String = ""
) -> Vector2:
	var overrides: Dictionary = aircraft_profile.get(
		"service_anchors",
		{}
	)
	if overrides.has(service_key):
		var key_value = overrides[service_key]
		if key_value is Vector2:
			return key_value
	if overrides.has(service_type):
		var type_value = overrides[service_type]
		if type_value is Vector2:
			return type_value

	var scale := 1.0
	match aircraft_size:
		"M":
			scale = 1.35
		"L":
			scale = 1.65
		"XL":
			scale = 2.0

	var base := Vector2.ZERO
	match service_type:
		"passenger":
			base = Vector2(10, -34)
		"cargo":
			base = Vector2(-10, 32)
		"cleaning":
			base = Vector2(-14, -30)
		"catering":
			base = Vector2(14, 30)
		"fuel":
			base = Vector2(-2, -40)
		"pushback":
			base = Vector2(36, 0)
		_:
			base = Vector2(0, 34)

	return base * scale


func get_service_docking_rotation(
	service_type: String,
	service_key: String = ""
) -> float:
	var rotation_overrides: Dictionary = aircraft_profile.get(
		"service_anchor_rotations",
		{}
	)
	if rotation_overrides.has(service_key):
		return rotation + float(
			rotation_overrides[service_key]
		)
	if rotation_overrides.has(service_type):
		return rotation + float(
			rotation_overrides[service_type]
		)

	match service_type:
		"cargo", "catering", "pushback":
			return rotation + PI
		_:
			return rotation


func get_pushback_target_position() -> Vector2:
	var distance := float(
		aircraft_profile.get("pushback_distance", 28.0)
	)
	match aircraft_size:
		"M":
			distance = maxf(distance, 38.0)
		"L":
			distance = maxf(distance, 50.0)
		"XL":
			distance = maxf(distance, 62.0)

	if departure_route.size() >= 2:
		var first_leg := (
			departure_route[1] - departure_route[0]
		)
		var direction := first_leg.normalized()
		if direction != Vector2.ZERO:
			distance = minf(
				distance,
				first_leg.length() * 0.72
			)
			return departure_route[0] + direction * distance

	return global_position + Vector2(-distance, 0).rotated(
		rotation
	)


func begin_ground_service(stage: String) -> void:
	if stage in [
		"UNLOADING",
		"SERVICING",
		"LOADING",
		"PUSHBACK_PREP"
	]:
		_set_state(stage)


func set_turnaround_status(
	text: String,
	tone: String = "normal"
) -> void:
	if turnaround_panel == null:
		return
	turnaround_label.text = text
	turnaround_panel.visible = not text.is_empty()
	match tone:
		"warning":
			turnaround_label.add_theme_color_override(
				"font_color",
				Color("ffd27a")
			)
		"success":
			turnaround_label.add_theme_color_override(
				"font_color",
				Color("a8efbf")
			)
		_:
			turnaround_label.add_theme_color_override(
				"font_color",
				Color("f4f7f7")
			)
	_sync_turnaround_status_transform()


func clear_turnaround_status() -> void:
	if turnaround_panel != null:
		turnaround_panel.visible = false


func _build_turnaround_status() -> void:
	turnaround_panel = PanelContainer.new()
	turnaround_panel.custom_minimum_size = Vector2(156, 42)
	turnaround_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turnaround_panel.z_index = 160
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.10, 0.14, 0.92)
	style.border_color = Color("5f8798")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	turnaround_panel.add_theme_stylebox_override(
		"panel",
		style
	)
	add_child(turnaround_panel)

	turnaround_label = Label.new()
	turnaround_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	turnaround_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	turnaround_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	turnaround_label.add_theme_font_size_override(
		"font_size",
		11
	)
	turnaround_label.add_theme_color_override(
		"font_color",
		Color("f4f7f7")
	)
	turnaround_panel.add_child(turnaround_label)
	turnaround_panel.visible = false
	_sync_turnaround_status_transform()


func _sync_turnaround_status_transform() -> void:
	if turnaround_panel == null:
		return
	var anchor := Vector2(-78, -72).rotated(-rotation)
	turnaround_panel.position = anchor
	turnaround_panel.rotation = -rotation


func can_change_flight_plan() -> bool:
	return state in [
		"PARKED",
		"WAITING_FUEL",
		"UNLOADING",
		"SERVICING",
		"LOADING",
		"PUSHBACK_PREP",
		"READY_FOR_DESTINATION",
		"READY_FOR_DEPARTURE",
		"WAITING_PASSENGERS"
	]


func set_departure_route(
	points: PackedVector2Array,
	size_class: String = "S",
	assigned_stand_uid: int = -1,
	assigned_runway_uid: int = -1
) -> void:
	aircraft_size = size_class
	departure_route = _refined_departure_route(points)
	stand_uid = assigned_stand_uid
	runway_uid = assigned_runway_uid
	route_index = 0
	delay_remaining = 0.0
	takeoff_velocity = taxi_speed
	taxi_current_speed = 0.0
	_set_state("WAITING_FUEL")

	if departure_route.is_empty():
		visible = false
		return

	visible = true
	position = departure_route[0]
	if departure_route.size() >= 2:
		var taxi_direction := (
			departure_route[1] - departure_route[0]
		).normalized()
		if taxi_direction != Vector2.ZERO:
			rotation = (-taxi_direction).angle()
	queue_redraw()


func set_arrival_route(
	points: PackedVector2Array,
	assigned_stand_uid: int,
	assigned_runway_uid: int
) -> void:
	arrival_route = _refined_arrival_route(points)
	stand_uid = assigned_stand_uid
	runway_uid = assigned_runway_uid
	route_index = 0
	arrival_runway_cleared = false


func mark_service_complete() -> void:
	if flight_plan.is_empty():
		_set_state("READY_FOR_DESTINATION")
	else:
		_set_state("READY_FOR_DEPARTURE")


func mark_waiting_passengers() -> void:
	_set_state("WAITING_PASSENGERS")


func begin_taxi_to_hold_short() -> void:
	if departure_route.size() < 5 or flight_plan.is_empty():
		return
	route_index = mini(
		route_index,
		maxi(departure_hold_short_index - 1, 0)
	)
	taxi_current_speed = 0.0
	_set_state("TAXIING_OUT")


func begin_departure_after_clearance() -> void:
	if departure_route.size() < 5 or flight_plan.is_empty():
		return

	# Compatibility for direct/internal callers that invoke runway
	# clearance without first taxiing through the dispatcher.
	if state != "HOLD_SHORT":
		route_index = maxi(departure_hold_short_index, 0)
		position = departure_route[route_index]

	delay_remaining = departure_delay
	takeoff_velocity = taxi_speed
	taxi_current_speed = 0.0
	_set_state("CLEARED")


func begin_arrival_after_clearance() -> void:
	if arrival_route.size() < 4:
		return

	var runway_start := arrival_route[0]
	var runway_next := arrival_route[1]
	var outward := (runway_start - runway_next).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2(-1, 0)

	position = runway_start + outward * 220.0
	visible = true
	route_index = -1
	arrival_runway_cleared = false
	_set_state("APPROACH")


func _process(delta: float) -> void:
	_sync_turnaround_status_transform()
	match state:
		"CLEARED":
			delay_remaining -= delta
			if delay_remaining <= 0.0:
				_set_state("ENTERING_RUNWAY")

		"TAXIING_OUT":
			_process_departure_taxi(delta)

		"ENTERING_RUNWAY":
			_process_runway_entry(delta)

		"LINE_UP":
			delay_remaining -= delta
			if delay_remaining <= 0.0:
				takeoff_velocity = taxi_speed
				_set_state("TAKEOFF_ROLL")

		"TAKEOFF_ROLL":
			_process_takeoff_roll(delta)

		"CLIMBING":
			_process_climb(delta)

		"EN_ROUTE":
			flight_remaining -= delta
			if flight_remaining <= 0.0:
				_set_state("HOLDING_FOR_ARRIVAL")
				arrival_requested.emit()

		"APPROACH":
			_process_approach(delta)

		"LANDING_ROLL":
			_process_landing_roll(delta)

		"TAXIING_IN":
			_process_taxi_in(delta)


func _process_departure_taxi(delta: float) -> void:
	if departure_hold_short_index < 0:
		return
	if route_index >= departure_hold_short_index:
		taxi_current_speed = 0.0
		_release_taxi_segment()
		_set_state("HOLD_SHORT")
		set_turnaround_status(
			"HOLD SHORT\nAwaiting runway",
			"warning"
		)
		hold_short_reached.emit()
		return

	var target_index := mini(
		route_index + 1,
		departure_hold_short_index
	)
	if not _request_taxi_segment(
		departure_route[route_index],
		departure_route[target_index]
	):
		taxi_current_speed = _approach_taxi_speed(
			taxi_current_speed,
			0.0,
			delta
		)
		return

	var target_speed := TaxiMotionRules.speed_for_target(
		departure_route,
		route_index,
		target_index,
		taxi_speed
	)
	taxi_current_speed = _approach_taxi_speed(
		taxi_current_speed,
		target_speed,
		delta
	)

	if _move_toward_point(
		departure_route[target_index],
		taxi_current_speed,
		delta,
		taxi_turn_rate_deg
	):
		route_index = target_index
		_release_taxi_segment()
		if route_index >= departure_hold_short_index:
			taxi_current_speed = 0.0
			_set_state("HOLD_SHORT")
			set_turnaround_status(
				"HOLD SHORT\nAwaiting runway",
				"warning"
			)
			hold_short_reached.emit()


func _process_runway_entry(delta: float) -> void:
	var runway_entry_index := departure_route.size() - 2
	if route_index >= runway_entry_index:
		taxi_current_speed = 0.0
		delay_remaining = lineup_delay
		_set_state("LINE_UP")
		return

	var target_speed := taxi_speed * 0.62
	taxi_current_speed = _approach_taxi_speed(
		taxi_current_speed,
		target_speed,
		delta
	)
	if _move_toward_point(
		departure_route[runway_entry_index],
		taxi_current_speed,
		delta,
		taxi_turn_rate_deg
	):
		route_index = runway_entry_index
		taxi_current_speed = 0.0
		delay_remaining = lineup_delay
		_set_state("LINE_UP")


func _process_takeoff_roll(delta: float) -> void:
	var runway_end_index := departure_route.size() - 1
	takeoff_velocity = minf(takeoff_velocity + 135.0 * delta, takeoff_speed)

	if _move_toward_point(
		departure_route[runway_end_index],
		takeoff_velocity,
		delta,
		280.0
	):
		route_index = runway_end_index
		runway_cleared.emit()

		var previous := departure_route[runway_end_index - 1]
		var direction := (departure_route[runway_end_index] - previous).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2(1, 0)

		departure_route.append(departure_route[runway_end_index] + direction * 260.0)
		_set_state("CLIMBING")


func _process_climb(delta: float) -> void:
	var climb_target := departure_route[departure_route.size() - 1]
	if _move_toward_point(
		climb_target,
		takeoff_speed * 1.15,
		delta,
		165.0
	):
		visible = false
		flight_remaining = maxf(
			float(flight_plan.get("duration_seconds", 0.0)),
			1.0
		)
		_set_state("EN_ROUTE")
		departed.emit()


func _process_approach(delta: float) -> void:
	if arrival_route.is_empty():
		return

	if _move_toward_point(
		arrival_route[0],
		approach_speed,
		delta,
		125.0
	):
		route_index = 0
		_set_state("LANDING_ROLL")


func _process_landing_roll(delta: float) -> void:
	if arrival_route.size() < 2:
		return

	var runway_exit_index := 1
	var current_speed := maxf(landing_speed - float(route_index) * 15.0, taxi_speed)
	if _move_toward_point(
		arrival_route[runway_exit_index],
		current_speed,
		delta,
		190.0
	):
		route_index = runway_exit_index
		_set_state("TAXIING_IN")


func _process_taxi_in(delta: float) -> void:
	if route_index >= arrival_route.size() - 1:
		taxi_current_speed = 0.0
		_set_state("PARKED")
		arrival_completed.emit()
		return

	var target_index := route_index + 1
	if not _request_taxi_segment(
		arrival_route[route_index],
		arrival_route[target_index]
	):
		taxi_current_speed = _approach_taxi_speed(
			taxi_current_speed,
			0.0,
			delta
		)
		return

	var target_speed := TaxiMotionRules.speed_for_target(
		arrival_route,
		route_index,
		target_index,
		taxi_speed
	)

	# Final stand approach is deliberately slower so larger sprites do not
	# visually overshoot or cut through the terminal/apron.
	if target_index >= arrival_route.size() - 1:
		target_speed = minf(
			target_speed,
			taxi_speed * 0.48
		)

	taxi_current_speed = _approach_taxi_speed(
		taxi_current_speed,
		target_speed,
		delta
	)

	if _move_toward_point(
		arrival_route[target_index],
		taxi_current_speed,
		delta,
		taxi_turn_rate_deg
	):
		route_index = target_index
		_release_taxi_segment()

		if not arrival_runway_cleared and route_index >= 2:
			arrival_runway_cleared = true
			runway_cleared.emit()

		if route_index >= arrival_route.size() - 1:
			taxi_current_speed = 0.0
			_set_state("PARKED")
			arrival_completed.emit()


func _request_taxi_segment(
	from_point: Vector2,
	to_point: Vector2
) -> bool:
	if taxi_traffic_controller == null:
		_set_taxi_hold(false, "")
		return true

	var result := taxi_traffic_controller.request_segment(
		self,
		from_point,
		to_point
	)
	var allowed := bool(result.get("allowed", false))
	if allowed:
		_set_taxi_hold(false, "")
		return true

	_set_taxi_hold(
		true,
		String(result.get("reason", "traffic"))
	)
	return false


func _release_taxi_segment() -> void:
	if taxi_traffic_controller != null:
		taxi_traffic_controller.release_segment(self)


func _set_taxi_hold(
	holding: bool,
	reason: String
) -> void:
	if taxi_holding == holding and (
		not holding or taxi_hold_reason == reason
	):
		return

	taxi_holding = holding
	taxi_hold_reason = reason if holding else ""
	if holding:
		set_turnaround_status(
			"TAXI HOLD\n%s" % reason.capitalize(),
			"warning"
		)
	elif state in ["TAXIING_OUT", "TAXIING_IN"]:
		clear_turnaround_status()


func _move_toward_point(
	target: Vector2,
	speed: float,
	delta: float,
	turn_rate_degrees: float = -1.0
) -> bool:
	var to_target := target - position
	var distance := to_target.length()
	if distance <= maxf(speed, 1.0) * delta:
		position = target
		if to_target.length() > 0.001:
			_rotate_toward_heading(
				to_target.angle(),
				delta,
				turn_rate_degrees
			)
		queue_redraw()
		return true

	var direction := to_target.normalized()
	position += direction * maxf(speed, 1.0) * delta
	_rotate_toward_heading(
		direction.angle(),
		delta,
		turn_rate_degrees
	)
	queue_redraw()
	return false


func _rotate_toward_heading(
	target_heading: float,
	delta: float,
	turn_rate_degrees: float
) -> void:
	var rate := turn_rate_degrees
	if rate <= 0.0:
		rate = taxi_turn_rate_deg

	var difference := wrapf(
		target_heading - rotation,
		-PI,
		PI
	)
	var maximum_step := deg_to_rad(rate) * delta
	rotation += clampf(
		difference,
		-maximum_step,
		maximum_step
	)


func _approach_taxi_speed(
	current_speed: float,
	target_speed: float,
	delta: float
) -> float:
	var rate := taxi_acceleration
	if target_speed < current_speed:
		rate = taxi_deceleration
	return move_toward(
		current_speed,
		target_speed,
		rate * delta
	)


func _refined_departure_route(
	points: PackedVector2Array
) -> PackedVector2Array:
	if points.size() < 4:
		departure_hold_short_index = -1
		return points.duplicate()

	var source := _ensure_hold_short_point(points)
	var hold_raw_index := source.size() - 3

	# Keep the exact stand, hold-short line, runway entry and runway end.
	# Only the taxiway section before hold-short is rounded.
	var taxi_points := PackedVector2Array()
	for index in range(1, hold_raw_index + 1):
		taxi_points.append(source[index])

	var refined_taxi := TaxiMotionRules.refined_route(
		taxi_points,
		aircraft_size,
		aircraft_profile
	)
	var result := PackedVector2Array()
	result.append(source[0])
	for point in refined_taxi:
		result.append(point)

	departure_hold_short_index = result.size() - 1
	result.append(source[source.size() - 2])
	result.append(source[source.size() - 1])
	return result


func _ensure_hold_short_point(
	points: PackedVector2Array
) -> PackedVector2Array:
	if points.size() >= 5:
		return points.duplicate()

	# Legacy four-point route:
	# stand -> taxiway -> runway entry -> runway end.
	var result := PackedVector2Array()
	result.append(points[0])
	result.append(points[1])

	var taxi_point := points[1]
	var runway_entry := points[2]
	result.append(
		taxi_point.lerp(runway_entry, 0.58)
	)
	result.append(runway_entry)
	result.append(points[3])
	return result


func _refined_arrival_route(
	points: PackedVector2Array
) -> PackedVector2Array:
	if points.size() < 4:
		return points.duplicate()

	# Arrival routes are the reverse of departure routes. Keep runway
	# end/entry exact, then round from the hold-short exit toward the stand.
	var taxi_points := PackedVector2Array()
	for index in range(2, points.size()):
		taxi_points.append(points[index])

	var refined_taxi := TaxiMotionRules.refined_route(
		taxi_points,
		aircraft_size,
		aircraft_profile
	)
	var result := PackedVector2Array()
	result.append(points[0])
	result.append(points[1])
	for point in refined_taxi:
		result.append(point)
	return result


func _set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	if new_state not in [
		"TAXIING_OUT",
		"TAXIING_IN",
		"ENTERING_RUNWAY"
	]:
		_release_taxi_segment()
		_set_taxi_hold(false, "")
	if new_state in [
		"TAXIING_OUT",
		"HOLD_SHORT",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING",
		"EN_ROUTE",
		"APPROACH",
		"LANDING_ROLL",
		"TAXIING_IN"
	]:
		clear_turnaround_status()
	state_changed.emit(state)
	queue_redraw()


func _draw() -> void:
	_draw_shadow()
	_draw_stand_ground_props()

	var fuselage := PackedVector2Array([
		Vector2(22, 0),
		Vector2(12, -5),
		Vector2(-18, -5),
		Vector2(-25, 0),
		Vector2(-18, 5),
		Vector2(12, 5)
	])
	var fuselage_color := Color("f4f7f7")
	if event_livery_enabled:
		match event_theme:
			"autumn":
				fuselage_color = Color("f4e6d0")
			"winter":
				fuselage_color = Color("f7fcff")
	draw_colored_polygon(fuselage, fuselage_color)

	var wing := PackedVector2Array([
		Vector2(4, -4),
		Vector2(-5, -18),
		Vector2(-12, -18),
		Vector2(-7, -3),
		Vector2(-7, 3),
		Vector2(-12, 18),
		Vector2(-5, 18),
		Vector2(4, 4)
	])
	draw_colored_polygon(wing, Color("dce8ea"))

	var tail := PackedVector2Array([
		Vector2(-14, -4),
		Vector2(-20, -11),
		Vector2(-23, -11),
		Vector2(-20, -3),
		Vector2(-20, 3),
		Vector2(-23, 11),
		Vector2(-20, 11),
		Vector2(-14, 4)
	])
	var tail_color := Color("5d90b8")
	if event_livery_enabled:
		match event_theme:
			"autumn":
				tail_color = Color("c35f2d")
			"winter":
				tail_color = Color("c8373c")
	draw_colored_polygon(tail, tail_color)

	draw_rect(Rect2(Vector2(2, -4), Vector2(7, 8)), Color("4a7898"))
	draw_circle(Vector2(14, 0), 2.2, Color("c8e9f1"))

	if event_livery_enabled and event_theme == "autumn":
		draw_rect(
			Rect2(Vector2(-3, -5), Vector2(6, 10)),
			Color("e5a23b")
		)
		draw_line(
			Vector2(-10, -14),
			Vector2(1, -4),
			Color("a94b2b"),
			3.0
		)

	if event_livery_enabled and event_theme == "winter":
		draw_line(
			Vector2(-15, 0),
			Vector2(10, 0),
			Color("2f8f58"),
			3.0
		)
		draw_circle(
			Vector2(-17, 0),
			3.0,
			Color("f2c94c")
		)
		draw_line(
			Vector2(-9, -14),
			Vector2(1, -4),
			Color("c8373c"),
			3.0
		)

	_draw_stand_people()

	if (
		event_featured
		and state not in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]
	):
		_draw_event_badge()

	match state:
		"WAITING_FUEL":
			draw_circle(Vector2(-2, -26), 6.0, Color("f4c95d"))
		"UNLOADING":
			draw_circle(Vector2(-2, -26), 6.0, Color("d6a3ff"))
		"SERVICING":
			draw_circle(Vector2(-2, -26), 6.0, Color("f4c95d"))
		"LOADING":
			draw_circle(Vector2(-2, -26), 6.0, Color("69c9dd"))
		"PUSHBACK_PREP":
			draw_circle(Vector2(-2, -26), 6.0, Color("76d39b"))
		"READY_FOR_DESTINATION":
			draw_circle(Vector2(-2, -26), 6.0, Color("f0a6ff"))
		"WAITING_PASSENGERS":
			draw_circle(Vector2(-2, -26), 6.0, Color("ff9f68"))
		"READY_FOR_DEPARTURE":
			draw_circle(Vector2(-2, -26), 6.0, Color("76d39b"))
		"HOLD_SHORT":
			draw_circle(Vector2(-2, -26), 6.0, Color("f3c969"))
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			draw_circle(Vector2(-2, -26), 6.0, Color("78b7e8"))
		"HOLDING_FOR_ARRIVAL":
			draw_circle(Vector2(-2, -26), 6.0, Color("d6a3ff"))


func get_ambience_profile() -> Dictionary:
	var profile := AirportAmbienceRules.profile_for_state(state)
	if profile.is_empty():
		return {}

	profile["worker_count"] = AirportAmbienceRules.worker_count_for(
		state,
		aircraft_size
	)
	profile["passenger_count"] = AirportAmbienceRules.passenger_count_for(
		state,
		aircraft_size
	)
	profile["baggage_count"] = AirportAmbienceRules.baggage_count_for(
		state,
		aircraft_size
	)
	profile["size_scale"] = AirportAmbienceRules.size_scale(
		aircraft_size
	)
	return profile


func _draw_stand_ground_props() -> void:
	var profile := get_ambience_profile()
	if profile.is_empty():
		return

	var scale := float(profile.get("size_scale", 1.0))
	if bool(profile.get("chocks", false)):
		_draw_chock_pair(Vector2(13, 0) * scale)
		_draw_chock_pair(Vector2(-10, 0) * scale)

	var cone_count := int(profile.get("cones", 0))
	var cone_positions := [
		Vector2(19, -24),
		Vector2(-14, -30),
		Vector2(-17, 27),
		Vector2(18, 28)
	]
	for index in range(mini(cone_count, cone_positions.size())):
		_draw_cone(cone_positions[index] * scale)

	var baggage_count := int(
		profile.get("baggage_count", 0)
	)
	if baggage_count > 0:
		_draw_baggage_cluster(
			Vector2(-18, 35) * scale,
			baggage_count,
			scale
		)


func _draw_stand_people() -> void:
	var profile := get_ambience_profile()
	if profile.is_empty():
		return

	var scale := float(profile.get("size_scale", 1.0))
	var workers := int(profile.get("worker_count", 0))
	var worker_positions := [
		Vector2(-9, 39),
		Vector2(13, -40),
		Vector2(-20, -34)
	]
	for index in range(mini(workers, worker_positions.size())):
		_draw_upright_person(
			worker_positions[index] * scale,
			Color("ef9a3a"),
			Color("ffe16a"),
			scale
		)

	var passengers := int(
		profile.get("passenger_count", 0)
	)
	var passenger_origin := Vector2(18, -42) * scale
	for index in range(passengers):
		var row := index / 3
		var column := index % 3
		var offset := Vector2(
			float(column) * 8.0,
			-float(row) * 8.0
		) * scale
		var shirt := Color("5f9fc0")
		if index % 3 == 1:
			shirt = Color("a77eb7")
		elif index % 3 == 2:
			shirt = Color("6e9d69")
		_draw_upright_person(
			passenger_origin + offset,
			shirt,
			Color("dce9ec"),
			scale * 0.92
		)

	if bool(profile.get("marshaller", false)):
		_draw_marshaller(Vector2(46, 0) * scale, scale)


func _draw_chock_pair(center: Vector2) -> void:
	var normal := Vector2(0, 1)
	for side in [-1.0, 1.0]:
		var p := center + normal * 5.5 * float(side)
		var shape := PackedVector2Array([
			p + Vector2(-4, 0),
			p + Vector2(1, -3),
			p + Vector2(4, 0),
			p + Vector2(1, 3)
		])
		draw_colored_polygon(
			shape,
			Color("efc64d")
		)
		draw_polyline(
			PackedVector2Array([
				shape[0],
				shape[1],
				shape[2],
				shape[3],
				shape[0]
			]),
			Color("5f5129"),
			1.0
		)


func _draw_cone(position_local: Vector2) -> void:
	var cone := PackedVector2Array([
		position_local + Vector2(0, -5),
		position_local + Vector2(-4, 4),
		position_local + Vector2(4, 4)
	])
	draw_colored_polygon(cone, Color("ee8b37"))
	draw_line(
		position_local + Vector2(-3, 1),
		position_local + Vector2(3, 1),
		Color("f5ede2"),
		1.5
	)
	draw_line(
		position_local + Vector2(-5, 4),
		position_local + Vector2(5, 4),
		Color("6a4a31"),
		1.5
	)


func _draw_baggage_cluster(
	center: Vector2,
	count: int,
	scale: float
) -> void:
	var draw_count := mini(count, 4)
	var colors := [
		Color("bb7a3b"),
		Color("d2a04e"),
		Color("80665b"),
		Color("557f9a")
	]
	for index in range(draw_count):
		var column := index % 2
		var row := index / 2
		var p := center + Vector2(
			float(column) * 8.0,
			-float(row) * 7.0
		) * scale
		draw_rect(
			Rect2(
				p + Vector2(-4, -3) * scale,
				Vector2(8, 6) * scale
			),
			colors[index % colors.size()]
		)
		draw_line(
			p + Vector2(-1, -4) * scale,
			p + Vector2(2, -4) * scale,
			Color("e6d5b9"),
			1.0
		)

	var cart_origin := center + Vector2(-5, 7) * scale
	draw_line(
		cart_origin,
		cart_origin + Vector2(22, 0) * scale,
		Color("6b7880"),
		2.0
	)
	draw_circle(
		cart_origin + Vector2(3, 3) * scale,
		2.2 * scale,
		Color("28363d")
	)
	draw_circle(
		cart_origin + Vector2(18, 3) * scale,
		2.2 * scale,
		Color("28363d")
	)


func _draw_upright_person(
	position_local: Vector2,
	shirt_color: Color,
	vest_color: Color,
	scale: float
) -> void:
	draw_set_transform(
		position_local,
		-rotation,
		Vector2.ONE
	)

	draw_circle(
		Vector2(0, -8) * scale,
		3.0 * scale,
		Color("d7a77d")
	)
	draw_rect(
		Rect2(
			Vector2(-3, -5) * scale,
			Vector2(6, 9) * scale
		),
		shirt_color
	)
	draw_rect(
		Rect2(
			Vector2(-3, -2) * scale,
			Vector2(6, 3) * scale
		),
		vest_color
	)
	draw_line(
		Vector2(-1.5, 4) * scale,
		Vector2(-2.5, 9) * scale,
		Color("344852"),
		1.6 * scale
	)
	draw_line(
		Vector2(1.5, 4) * scale,
		Vector2(2.5, 9) * scale,
		Color("344852"),
		1.6 * scale
	)

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_marshaller(
	position_local: Vector2,
	scale: float
) -> void:
	draw_set_transform(
		position_local,
		-rotation,
		Vector2.ONE
	)

	draw_circle(
		Vector2(0, -8) * scale,
		3.2 * scale,
		Color("d7a77d")
	)
	draw_rect(
		Rect2(
			Vector2(-3.5, -5) * scale,
			Vector2(7, 10) * scale
		),
		Color("ed8f35")
	)
	draw_rect(
		Rect2(
			Vector2(-3.5, -2) * scale,
			Vector2(7, 3) * scale
		),
		Color("f4df61")
	)

	draw_line(
		Vector2(-3, -2) * scale,
		Vector2(-9, -11) * scale,
		Color("32444d"),
		1.8 * scale
	)
	draw_line(
		Vector2(3, -2) * scale,
		Vector2(9, -11) * scale,
		Color("32444d"),
		1.8 * scale
	)
	draw_line(
		Vector2(-9, -11) * scale,
		Vector2(-11, -17) * scale,
		Color("f26a4b"),
		2.4 * scale
	)
	draw_line(
		Vector2(9, -11) * scale,
		Vector2(11, -17) * scale,
		Color("f26a4b"),
		2.4 * scale
	)

	draw_line(
		Vector2(-1.5, 5) * scale,
		Vector2(-2.5, 10) * scale,
		Color("344852"),
		1.7 * scale
	)
	draw_line(
		Vector2(1.5, 5) * scale,
		Vector2(2.5, 10) * scale,
		Color("344852"),
		1.7 * scale
	)

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_event_badge() -> void:
	var center := Vector2(-2, -39)
	var fill := Color("e6a83f")
	match event_theme:
		"autumn":
			fill = Color("d66d30")
		"winter":
			fill = Color("3f8ebd")

	draw_circle(center, 9.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 7.0, fill)
	draw_circle(center, 7.0, Color("ffe3a1"), false, 2.0)

	var diamond := PackedVector2Array([
		center + Vector2(0, -4),
		center + Vector2(4, 0),
		center + Vector2(0, 4),
		center + Vector2(-4, 0)
	])
	draw_colored_polygon(diamond, Color("fff0bd"))

	if not event_marker_text.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-20, -50),
			event_marker_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			36.0,
			10,
			Color("fff0bd")
		)


func _draw_shadow() -> void:
	if state in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]:
		return

	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
