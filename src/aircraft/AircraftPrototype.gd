class_name AircraftPrototype
extends Node2D

signal runway_cleared
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


var departure_route := PackedVector2Array()
var arrival_route := PackedVector2Array()
var route_index := 0
var state := "PARKED"
var aircraft_size := "S"
var aircraft_type_id := ""
var aircraft_display_name := "Aircraft"
var aircraft_profile: Dictionary = {}
var flight_plan: Dictionary = {}
var stand_uid := -1
var runway_uid := -1

var delay_remaining := 0.0
var flight_remaining := 0.0
var takeoff_velocity := 0.0
var arrival_runway_cleared := false


func configure_aircraft_type(type_id: String) -> void:
	var profile: Dictionary = AircraftCatalog.get_profile(type_id)
	if profile.is_empty():
		return

	aircraft_type_id = type_id
	aircraft_profile = profile
	aircraft_display_name = String(profile.get("name", type_id))
	aircraft_size = String(profile.get("size", aircraft_size))
	taxi_speed = maxf(float(profile.get("taxi_speed", taxi_speed)), 1.0)


func assign_flight_plan(plan: Dictionary) -> void:
	flight_plan = plan.duplicate(true)
	if state == "READY_FOR_DESTINATION" and not flight_plan.is_empty():
		_set_state("READY_FOR_DEPARTURE")


func has_flight_plan() -> bool:
	return not flight_plan.is_empty()


func get_flight_plan() -> Dictionary:
	return flight_plan.duplicate(true)


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


func begin_ground_service(stage: String) -> void:
	if stage in [
		"UNLOADING",
		"SERVICING",
		"LOADING",
		"PUSHBACK_PREP"
	]:
		_set_state(stage)


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
	departure_route = points
	aircraft_size = size_class
	stand_uid = assigned_stand_uid
	runway_uid = assigned_runway_uid
	route_index = 0
	delay_remaining = 0.0
	takeoff_velocity = taxi_speed
	_set_state("WAITING_FUEL")

	if departure_route.is_empty():
		visible = false
		return

	visible = true
	position = departure_route[0]
	queue_redraw()


func set_arrival_route(
	points: PackedVector2Array,
	assigned_stand_uid: int,
	assigned_runway_uid: int
) -> void:
	arrival_route = points
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


func begin_departure_after_clearance() -> void:
	if departure_route.size() < 4 or flight_plan.is_empty():
		return
	delay_remaining = departure_delay
	route_index = 0
	takeoff_velocity = taxi_speed
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
	match state:
		"CLEARED":
			delay_remaining -= delta
			if delay_remaining <= 0.0:
				_set_state("TAXIING_OUT")

		"TAXIING_OUT":
			_process_departure_taxi(delta)

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
	var runway_entry_index := departure_route.size() - 2
	if route_index >= runway_entry_index:
		delay_remaining = lineup_delay
		_set_state("LINE_UP")
		return

	var target_index := mini(route_index + 1, runway_entry_index)
	if _move_toward_point(departure_route[target_index], taxi_speed, delta):
		route_index = target_index
		if route_index >= runway_entry_index:
			delay_remaining = lineup_delay
			_set_state("LINE_UP")


func _process_takeoff_roll(delta: float) -> void:
	var runway_end_index := departure_route.size() - 1
	takeoff_velocity = minf(takeoff_velocity + 135.0 * delta, takeoff_speed)

	if _move_toward_point(departure_route[runway_end_index], takeoff_velocity, delta):
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
	if _move_toward_point(climb_target, takeoff_speed * 1.15, delta):
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

	if _move_toward_point(arrival_route[0], approach_speed, delta):
		route_index = 0
		_set_state("LANDING_ROLL")


func _process_landing_roll(delta: float) -> void:
	if arrival_route.size() < 2:
		return

	var runway_exit_index := 1
	var current_speed := maxf(landing_speed - float(route_index) * 15.0, taxi_speed)
	if _move_toward_point(arrival_route[runway_exit_index], current_speed, delta):
		route_index = runway_exit_index
		_set_state("TAXIING_IN")


func _process_taxi_in(delta: float) -> void:
	if route_index >= arrival_route.size() - 1:
		_set_state("PARKED")
		arrival_completed.emit()
		return

	var target_index := route_index + 1
	if _move_toward_point(arrival_route[target_index], taxi_speed, delta):
		route_index = target_index

		if not arrival_runway_cleared and route_index >= 2:
			arrival_runway_cleared = true
			runway_cleared.emit()

		if route_index >= arrival_route.size() - 1:
			_set_state("PARKED")
			arrival_completed.emit()


func _move_toward_point(target: Vector2, speed: float, delta: float) -> bool:
	var to_target := target - position
	var distance := to_target.length()
	if distance <= speed * delta:
		position = target
		queue_redraw()
		return true

	var direction := to_target.normalized()
	position += direction * speed * delta
	rotation = direction.angle()
	queue_redraw()
	return false


func _set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
	queue_redraw()


func _draw() -> void:
	_draw_shadow()

	var fuselage := PackedVector2Array([
		Vector2(22, 0),
		Vector2(12, -5),
		Vector2(-18, -5),
		Vector2(-25, 0),
		Vector2(-18, 5),
		Vector2(12, 5)
	])
	draw_colored_polygon(fuselage, Color("f4f7f7"))

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
	draw_colored_polygon(tail, Color("5d90b8"))

	draw_rect(Rect2(Vector2(2, -4), Vector2(7, 8)), Color("4a7898"))
	draw_circle(Vector2(14, 0), 2.2, Color("c8e9f1"))

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
		"CLEARED", "LINE_UP":
			draw_circle(Vector2(-2, -26), 6.0, Color("78b7e8"))
		"HOLDING_FOR_ARRIVAL":
			draw_circle(Vector2(-2, -26), 6.0, Color("d6a3ff"))


func _draw_shadow() -> void:
	if state in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]:
		return

	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
