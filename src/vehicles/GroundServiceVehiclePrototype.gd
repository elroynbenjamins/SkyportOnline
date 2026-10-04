class_name GroundServiceVehiclePrototype
extends Node2D

signal service_started
signal service_completed
signal returned_to_station

@export var drive_speed: float = 120.0

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
var vehicle_sprite_atlas: Texture2D


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

	outbound_route = route
	return_route = route.duplicate()
	return_route.reverse()
	route_index = 0
	service_duration = maxf(duration, 0.25)
	service_remaining = service_duration
	service_type = kind
	_load_vehicle_sprite()
	position = outbound_route[0]
	visible = true
	phase = "WAITING_LAUNCH" if launch_delay_remaining > 0.0 else "OUTBOUND"
	queue_redraw()


func _process(delta: float) -> void:
	match phase:
		"WAITING_LAUNCH":
			launch_delay_remaining = maxf(
				launch_delay_remaining - delta,
				0.0
			)
			if launch_delay_remaining <= 0.0:
				phase = "OUTBOUND"
				queue_redraw()
		"OUTBOUND":
			if _follow_route(outbound_route, delta):
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
				service_completed.emit()
				queue_redraw()
		"RETURNING":
			if _follow_route(return_route, delta):
				phase = "DONE"
				returned_to_station.emit()
				queue_free()


func _follow_route(points: PackedVector2Array, delta: float) -> bool:
	if points.size() < 2:
		return true

	var target_index := mini(route_index + 1, points.size() - 1)
	var target := points[target_index]
	var to_target := target - position
	var distance := to_target.length()

	if distance <= drive_speed * delta:
		position = target
		route_index = target_index
		return route_index >= points.size() - 1

	var direction := to_target.normalized()
	position += direction * drive_speed * delta
	rotation = direction.angle()
	queue_redraw()
	return false


func _draw() -> void:
	_draw_shadow()

	var sprite_drawn := _draw_directional_sprite()
	if not sprite_drawn:
		var body_color := _body_color()
		draw_rect(
			Rect2(Vector2(-12, -7), Vector2(24, 14)),
			body_color
		)
		draw_rect(
			Rect2(Vector2(5, -6), Vector2(10, 12)),
			Color("e9ecec")
		)

	if not sprite_drawn:
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
				draw_circle(Vector2(-5, 0), 4.0, Color("d7f5ef"))
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
	
	if phase == "SERVICING":
		draw_circle(Vector2(0, -15), 4.0, Color("ffd166"))
		_draw_service_attachment()


func _load_vehicle_sprite() -> void:
	vehicle_sprite_atlas = null
	var path := GroundVehicleVisuals.atlas_path(service_type)
	if path.is_empty() or not ResourceLoader.exists(path):
		return

	var texture = load(path)
	if texture is Texture2D:
		vehicle_sprite_atlas = texture


func _draw_directional_sprite() -> bool:
	if vehicle_sprite_atlas == null:
		return false

	var display_size := GroundVehicleVisuals.display_size(
		service_type
	)
	var source_region := GroundVehicleVisuals.source_region(
		service_type,
		rotation
	)

	draw_set_transform(
		Vector2.ZERO,
		-rotation,
		Vector2.ONE
	)
	draw_texture_rect_region(
		vehicle_sprite_atlas,
		Rect2(-display_size * 0.5, display_size),
		source_region
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
	return true


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
	draw_set_transform(
		Vector2(2, 4),
		0.0,
		Vector2(1.0, 0.45)
	)
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
