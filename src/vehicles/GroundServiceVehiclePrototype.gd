class_name GroundServiceVehiclePrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 120.0

var current_drive_speed := 0.0
var outbound_travel_duration := 0.0
var return_travel_duration := 0.0
var phase_travel_elapsed := 0.0
var visual_route_progress := 0.0
var traffic_yield_factor := 1.0
var traffic_waiting := false
var traffic_reason := ""
var traffic_blocker_id := -1
var traffic_sequence := 999999
var traffic_stand_uid := -1

var outbound_route := PackedVector2Array()
var return_route := PackedVector2Array()
var route_index := 0
var service_duration := 4.0
var service_remaining := 0.0
var service_type := "cargo"
var phase := "IDLE"
var launch_delay_remaining := 0.0
var service_pose_rotation := 0.0
var has_service_pose_rotation := false
var service_connection_target := Vector2.ZERO
var has_service_connection_target := false
var tow_aircraft: AircraftPrototype
var tow_start_aircraft_position := Vector2.ZERO
var tow_end_aircraft_position := Vector2.ZERO
var tow_start_vehicle_position := Vector2.ZERO
var tow_initialized := false
var motion_clock := 0.0
var visual_motion_amount := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func set_launch_delay(seconds: float) -> void:
	launch_delay_remaining = maxf(seconds, 0.0)


func set_service_pose_rotation(value: float) -> void:
	service_pose_rotation = value
	has_service_pose_rotation = true


func set_service_connection_target(
	global_target: Vector2
) -> void:
	service_connection_target = global_target
	has_service_connection_target = true


func configure_apron_traffic(
	stand_uid: int,
	sequence: int
) -> void:
	traffic_stand_uid = stand_uid
	traffic_sequence = sequence


func configure_tow(
	aircraft: AircraftPrototype,
	target_position: Vector2
) -> void:
	tow_aircraft = aircraft
	tow_end_aircraft_position = target_position
	tow_initialized = false


func start_service(
	route: PackedVector2Array,
	duration: float,
	kind: String
) -> void:
	if route.size() < 2:
		queue_free()
		return

	var baseline_length := GroundServiceMotionRules.route_length(route)
	outbound_route = GroundServiceMotionRules.refined_route(
		route,
		kind
	)
	return_route = outbound_route.duplicate()
	return_route.reverse()
	route_index = 0
	current_drive_speed = 0.0
	outbound_travel_duration = maxf(
		baseline_length / maxf(drive_speed, 1.0),
		0.08
	)
	return_travel_duration = outbound_travel_duration
	phase_travel_elapsed = 0.0
	visual_route_progress = 0.0
	traffic_yield_factor = 1.0
	traffic_waiting = false
	traffic_reason = ""
	traffic_blocker_id = -1
	service_duration = maxf(duration, 0.25)
	service_remaining = service_duration
	service_type = kind
	position = outbound_route[0]
	visible = true
	phase = "WAITING_LAUNCH" if launch_delay_remaining > 0.0 else "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	motion_clock += delta
	var moving := (
		phase in ["OUTBOUND", "RETURNING"]
		and not traffic_waiting
	)
	visual_motion_amount = move_toward(
		visual_motion_amount,
		1.0 if moving else 0.0,
		delta * 4.0
	)
	if moving or phase == "SERVICING":
		queue_redraw()

	match phase:
		"WAITING_LAUNCH":
			launch_delay_remaining = maxf(
				launch_delay_remaining - delta,
				0.0
			)
			if launch_delay_remaining <= 0.0:
				phase = "OUTBOUND"
				current_drive_speed = 0.0
				queue_redraw()
		"OUTBOUND":
			if _follow_route(
			outbound_route,
			delta,
			outbound_travel_duration
		):
				phase = "SERVICING"
				if has_service_pose_rotation:
					rotation = service_pose_rotation
				if tow_aircraft != null and is_instance_valid(
					tow_aircraft
				):
					tow_start_aircraft_position = (
						tow_aircraft.global_position
					)
					tow_start_vehicle_position = global_position
					tow_initialized = true
					service_connection_target = (
						tow_aircraft.global_position
					)
					has_service_connection_target = true
				service_started.emit()
				queue_redraw()
		"SERVICING":
			service_remaining = maxf(
				service_remaining - delta,
				0.0
			)
			if tow_initialized and tow_aircraft != null and (
				is_instance_valid(tow_aircraft)
			):
				var progress := 1.0 - (
					service_remaining / maxf(
						service_duration,
						0.001
					)
				)
				var aircraft_delta := (
					tow_end_aircraft_position
					- tow_start_aircraft_position
				)
				tow_aircraft.global_position = (
					tow_start_aircraft_position
					+ aircraft_delta * progress
				)
				global_position = (
					tow_start_vehicle_position
					+ aircraft_delta * progress
				)
				service_connection_target = (
					tow_aircraft.global_position
				)
				queue_redraw()
			if service_remaining <= 0.0:
				if tow_initialized and tow_aircraft != null and (
					is_instance_valid(tow_aircraft)
				):
					tow_aircraft.global_position = (
						tow_end_aircraft_position
					)
					service_connection_target = (
						tow_aircraft.global_position
					)
				phase = "RETURNING"
				route_index = 0
				current_drive_speed = 0.0
				phase_travel_elapsed = 0.0
				visual_route_progress = 0.0
				traffic_yield_factor = 1.0
				traffic_waiting = false
				traffic_reason = ""
				traffic_blocker_id = -1
				if tow_initialized and not return_route.is_empty():
					return_route[0] = global_position
					return_travel_duration = maxf(
						GroundServiceMotionRules.route_length(
							return_route
						) / maxf(drive_speed, 1.0),
						0.08
					)
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _follow_route(
			return_route,
			delta,
			return_travel_duration
		):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _follow_route(
	points: PackedVector2Array,
	delta: float,
	travel_duration: float
) -> bool:
	if points.size() < 2:
		return true

	var duration := maxf(travel_duration, 0.01)
	var previous_position := position
	phase_travel_elapsed = minf(
		phase_travel_elapsed + delta,
		duration
	)
	var time_progress := clampf(
		phase_travel_elapsed / duration,
		0.0,
		1.0
	)
	var scheduled_progress := (
		GroundServiceMotionRules.distance_progress_for_time(
			time_progress,
			service_type
		)
	)
	var traffic := _current_traffic_decision()
	traffic_yield_factor = float(
		traffic.get("factor", 1.0)
	)
	traffic_waiting = bool(
		traffic.get("yielding", false)
	)
	traffic_reason = String(
		traffic.get("reason", "")
	)
	traffic_blocker_id = int(
		traffic.get("blocker_id", -1)
	)

	var nominal_step := delta / duration
	var progress_step := nominal_step * traffic_yield_factor
	if not traffic_waiting:
		progress_step = nominal_step * 2.20
	visual_route_progress = move_toward(
		visual_route_progress,
		scheduled_progress,
		progress_step
	)
	var sample := GroundServiceMotionRules.sample_route_at_progress(
		points,
		visual_route_progress
	)
	position = sample.get("position", position)
	var target_index := clampi(
		int(sample.get("target_index", 1)),
		1,
		points.size() - 1
	)
	route_index = (
		points.size() - 1
		if bool(sample.get("done", false))
		else maxi(target_index - 1, 0)
	)

	current_drive_speed = (
		previous_position.distance_to(position)
		/ maxf(delta, 0.001)
	)
	var target_heading := GroundServiceMotionRules.lookahead_heading(
		points,
		position,
		target_index,
		service_type
	)
	var turn_rate := deg_to_rad(
		GroundServiceMotionRules.turn_rate_degrees(service_type)
	)
	rotation = _rotate_heading_toward(
		rotation,
		target_heading,
		turn_rate * delta
	)
	queue_redraw()

	if (
		time_progress >= 1.0
		and visual_route_progress >= 0.999
	):
		position = points[points.size() - 1]
		route_index = points.size() - 1
		current_drive_speed = 0.0
		rotation = GroundServiceMotionRules.endpoint_heading(points)
		return true
	return false


func _rotate_heading_toward(
	current_heading: float,
	target_heading: float,
	maximum_step: float
) -> float:
	var difference := wrapf(
		target_heading - current_heading,
		-PI,
		PI
	)
	return current_heading + clampf(
		difference,
		-maximum_step,
		maximum_step
	)


func get_apron_traffic_snapshot() -> Dictionary:
	return {
		"instance_id": get_instance_id(),
		"position": global_position,
		"heading": global_rotation,
		"phase": phase,
		"service_type": service_type,
		"traffic_sequence": traffic_sequence,
		"stand_uid": traffic_stand_uid,
		"yielding": traffic_waiting,
		"route_progress": visual_route_progress,
	}


func _current_traffic_decision() -> Dictionary:
	if phase not in ["OUTBOUND", "RETURNING"]:
		return {
			"factor": 1.0,
			"yielding": false,
			"reason": "",
			"blocker_id": -1,
		}
	var parent := get_parent()
	if parent == null:
		return {
			"factor": 1.0,
			"yielding": false,
			"reason": "",
			"blocker_id": -1,
		}
	var others: Array = []
	for child in parent.get_children():
		if child == self:
			continue
		if not child.has_method("get_apron_traffic_snapshot"):
			continue
		var snapshot_variant = child.call(
			"get_apron_traffic_snapshot"
		)
		if snapshot_variant is Dictionary:
			others.append(snapshot_variant)
	return ApronTrafficRules.traffic_decision(
		get_apron_traffic_snapshot(),
		others
	)


func get_motion_snapshot() -> Dictionary:
	var route := (
		return_route
		if phase == "RETURNING"
		else outbound_route
	)
	return {
		"phase": phase,
		"service_type": service_type,
		"route_index": route_index,
		"route_points": route.size(),
		"route_length": GroundServiceMotionRules.route_length(route),
		"current_speed": current_drive_speed,
		"target_speed": drive_speed,
		"travel_elapsed": phase_travel_elapsed,
		"travel_duration": (
			return_travel_duration
			if phase == "RETURNING"
			else outbound_travel_duration
		),
		"turn_rate_deg": GroundServiceMotionRules.turn_rate_degrees(
			service_type
		),
		"corner_radius": GroundServiceMotionRules.corner_radius(
			service_type
		),
		"braking_distance": GroundServiceMotionRules.braking_distance(
			service_type
		),
		"production_road_following": true,
		"traffic_waiting": traffic_waiting,
		"traffic_factor": traffic_yield_factor,
		"traffic_reason": traffic_reason,
		"traffic_blocker_id": traffic_blocker_id,
		"traffic_sequence": traffic_sequence,
		"stand_uid": traffic_stand_uid,
	}




func _draw() -> void:
	_draw_shadow()

	var atlas := GroundServiceVehicleArt.texture()
	if atlas != null:
		var draw_size := GroundServiceVehicleArt.world_size(
			service_type
		)
		var source := GroundServiceVehicleArt.source_rect(
			service_type,
			global_rotation
		)
		draw_set_transform(
			Vector2.ZERO,
			-global_rotation
			+ GroundServiceVehicleArt.turn_lean(
				global_rotation
			),
			Vector2.ONE
		)
		draw_texture_rect_region(
			atlas,
			Rect2(
				-draw_size * 0.5
				+ Vector2(
					0,
					-2 + _motion_bob_y()
				),
				draw_size
			),
			source
		)
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)
	else:
		var body_color := _body_color()
		draw_rect(
			Rect2(Vector2(-12, -7), Vector2(24, 14)),
			body_color
		)
		draw_rect(
			Rect2(Vector2(5, -6), Vector2(10, 12)),
			Color("e9ecec")
		)

		match service_type:
			"passenger":
				draw_rect(
					Rect2(Vector2(-8, -5), Vector2(4, 10)),
					Color("dff4f7")
				)
				draw_rect(
					Rect2(Vector2(-2, -5), Vector2(4, 10)),
					Color("dff4f7")
				)
			"cargo":
				draw_rect(
					Rect2(Vector2(-17, -5), Vector2(7, 10)),
					Color("8a775f")
				)
			"cleaning":
				draw_circle(
					Vector2(-5, 0),
					4.0,
					Color("d7f5ef")
				)
			"catering":
				draw_rect(
					Rect2(Vector2(-10, -10), Vector2(12, 4)),
					Color("f5ead8")
				)
			"pushback":
				draw_rect(
					Rect2(Vector2(12, -3), Vector2(10, 6)),
					Color("d9b85f")
				)
				draw_line(
					Vector2(18, -5),
					Vector2(24, -7),
					Color("e7cf8a"),
					2.0
				)
				draw_line(
					Vector2(18, 5),
					Vector2(24, 7),
					Color("e7cf8a"),
					2.0
				)

		draw_circle(Vector2(-7, -8), 3.0, Color("292f32"))
		draw_circle(Vector2(9, -8), 3.0, Color("292f32"))
		draw_circle(Vector2(-7, 8), 3.0, Color("292f32"))
		draw_circle(Vector2(9, 8), 3.0, Color("292f32"))

	if phase in ["OUTBOUND", "RETURNING"]:
		_draw_service_beacon(
			0.88 if traffic_waiting else 0.55
		)
	elif phase == "SERVICING":
		_draw_service_beacon(1.0)
		_draw_service_attachment()


func _motion_bob_y() -> float:
	if visual_motion_amount <= 0.001:
		return 0.0
	var amplitude := GroundServiceVehicleArt.motion_bob_amplitude(
		service_type
	)
	return (
		sin(motion_clock * 12.0)
		* amplitude
		* visual_motion_amount
	)


func _draw_service_beacon(
	strength: float = 1.0
) -> void:
	var draw_size := GroundServiceVehicleArt.world_size(
		service_type
	)
	var height := maxf(draw_size.y * 0.36, 15.0)
	var pulse := (
		0.5
		+ 0.5 * sin(motion_clock * 8.5)
	)
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation
		+ GroundServiceVehicleArt.turn_lean(
			global_rotation
		),
		Vector2.ONE
	)
	var beacon_position := Vector2(
		0,
		-height + _motion_bob_y()
	)
	draw_circle(
		beacon_position + Vector2(1, 2),
		4.2,
		Color(0.03, 0.06, 0.07, 0.28 * strength)
	)
	draw_circle(
		beacon_position,
		4.8 + pulse * 1.2,
		Color(1.0, 0.74, 0.20, (0.08 + pulse * 0.10) * strength)
	)
	draw_circle(
		beacon_position,
		3.2,
		Color(1.0, 0.74 + pulse * 0.12, 0.24, 0.92 * strength)
	)
	draw_circle(
		beacon_position + Vector2(-1, -1),
		1.15,
		Color(1.0, 0.96, 0.72, 0.95 * strength)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_service_attachment() -> void:
	if not has_service_connection_target:
		return

	var target := to_local(service_connection_target)
	if target.length() < 1.0:
		return
	var connection := target.normalized() * minf(
		target.length(),
		34.0
	)

	match service_type:
		"passenger":
			var step_direction := connection / 4.0
			for index in range(1, 5):
				var point := step_direction * float(index)
				draw_line(
					point + Vector2(-5, 0),
					point + Vector2(5, 0),
					Color("dff4f7"),
					2.0
				)
			draw_line(
				Vector2.ZERO,
				connection,
				Color("dff4f7"),
				2.0
			)
		"cargo":
			draw_line(
				Vector2.ZERO,
				connection,
				Color("d7b37c"),
				4.0
			)
			for fraction in [0.35, 0.65, 0.9]:
				draw_circle(
					connection * float(fraction),
					2.2,
					Color("f2cf96")
				)
		"cleaning":
			draw_line(
				Vector2.ZERO,
				connection,
				Color("b9efe5"),
				2.0
			)
			draw_circle(
				connection,
				3.0,
				Color("d7f5ef")
			)
		"catering":
			var lift_end := connection * 0.85
			draw_line(
				Vector2.ZERO,
				lift_end,
				Color("f5ead8"),
				3.0
			)
			draw_rect(
				Rect2(
					lift_end - Vector2(7, 4),
					Vector2(14, 8)
				),
				Color("f5ead8")
			)
		"pushback":
			draw_line(
				Vector2(15, 0),
				connection,
				Color("d9b85f"),
				4.0
			)
			draw_circle(
				connection,
				3.0,
				Color("f1d98e")
			)


func _body_color() -> Color:
	match service_type:
		"passenger":
			return Color("4f93b5")
		"cargo":
			return Color("9a7c55")
		"cleaning":
			return Color("61a39c")
		"catering":
			return Color("c88962")
		"pushback":
			return Color("6f8191")
		_:
			return Color("7f8d96")


func _draw_shadow() -> void:
	var radius := GroundServiceVehicleArt.shadow_radius(
		service_type
	)
	var aspect := GroundServiceVehicleArt.shadow_aspect(
		service_type
	)
	var world_offset := Vector2(3, 5)
	var local_offset := world_offset.rotated(
		-global_rotation
	)
	draw_set_transform(
		local_offset,
		-global_rotation
		+ GroundServiceVehicleArt.turn_lean(
			global_rotation
		),
		Vector2(1.0, aspect)
	)
	draw_circle(
		Vector2(-radius * 0.12, 0),
		radius * 1.08,
		Color(0, 0, 0, 0.10)
	)
	draw_circle(
		Vector2(radius * 0.12, 0),
		radius * 0.82,
		Color(0, 0, 0, 0.16)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
