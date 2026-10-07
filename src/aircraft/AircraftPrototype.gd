class_name AircraftPrototype
extends Node2D

signal runway_cleared
signal hold_short_reached
signal departed
signal arrival_requested
signal arrival_completed
signal predeparture_transfer_completed
signal state_changed(state: String)
signal handling_action_requested(
	aircraft: AircraftPrototype,
	action: String
)

@export var taxi_speed: float = 105.0
@export var takeoff_speed: float = 235.0
@export var approach_speed: float = 185.0
@export var landing_speed: float = 150.0
@export var takeoff_acceleration: float = 135.0
@export var departure_delay: float = 0.55
@export var lineup_delay: float = 0.45
@export var taxi_acceleration: float = 95.0
@export var taxi_deceleration: float = 150.0

const MOTION_FX_DURATION := 0.72
const TOUCHDOWN_FX_DURATION := 0.96
const EXTERNAL_PUSHBACK_MIN_DISTANCE := 0.35
const NO_HEADING_OVERRIDE := 999999.0
const AIRCRAFT_PRESENTATION_SCALE := 1.15


var departure_route := PackedVector2Array()
var arrival_route := PackedVector2Array()
var predeparture_transfer_route := PackedVector2Array()
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
var social_visit := false
var social_visit_data: Dictionary = {}
var stand_uid := -1
var runway_uid := -1

var delay_remaining := 0.0
var flight_remaining := 0.0
var takeoff_velocity := 0.0
var taxi_current_speed := 0.0
var taxi_turn_rate_deg := 145.0
var approach_spawn_distance := 220.0
var climb_out_distance := 260.0
var approach_visual_lift := 48.0
var climb_visual_lift := 58.0
var departure_hold_short_index := -1
var arrival_runway_cleared := false
var turnaround_panel: PanelContainer
var turnaround_label: Label
var handling_action_button: Button
var manual_handling_enabled := false
var handling_automation_enabled := false
var pending_handling_action := ""
var taxi_traffic_controller: TaxiTrafficController
var taxi_holding := false
var taxi_hold_reason := ""
var motion_fx_kind := ""
var motion_fx_elapsed := 99.0
var motion_sample_position := Vector2.ZERO
var motion_sample_initialized := false
var externally_moving := false
var external_motion_speed := 0.0
var visual_clock := 0.0
var visual_redraw_accumulator := 0.0
var landing_roll_target_speed := 0.0


func _ready() -> void:
	_build_turnaround_status()
	_build_handling_action_button()
	motion_sample_position = global_position
	motion_sample_initialized = true


func configure_handling_mode(
	manual_enabled: bool,
	automation_enabled: bool = false
) -> void:
	manual_handling_enabled = manual_enabled
	handling_automation_enabled = (
		manual_enabled
		and automation_enabled
	)
	if not manual_handling_enabled:
		clear_handling_action()
	_sync_handling_action_transform()


func uses_manual_handling() -> bool:
	return manual_handling_enabled


func uses_handling_automation() -> bool:
	return (
		manual_handling_enabled
		and handling_automation_enabled
	)


func set_handling_automation_enabled(
	enabled: bool
) -> void:
	handling_automation_enabled = (
		manual_handling_enabled
		and enabled
	)


func set_handling_action(
	action: String
) -> void:
	pending_handling_action = action.to_upper()
	if handling_action_button == null:
		return

	if pending_handling_action.is_empty():
		handling_action_button.visible = false
		return

	handling_action_button.text = _handling_action_label(
		pending_handling_action
	)
	handling_action_button.visible = visible
	_sync_handling_action_transform()


func clear_handling_action() -> void:
	pending_handling_action = ""
	if handling_action_button != null:
		handling_action_button.visible = false


func get_handling_action() -> String:
	return pending_handling_action


func get_handling_action_snapshot() -> Dictionary:
	return {
		"manual": manual_handling_enabled,
		"automation": handling_automation_enabled,
		"automation_scope": aircraft_size,
		"action": pending_handling_action,
		"visible": (
			handling_action_button != null
			and handling_action_button.visible
		)
	}


func stage_for_manual_arrival() -> bool:
	if not manual_handling_enabled:
		return false
	if arrival_route.size() < 4:
		return false

	var runway_start := arrival_route[0]
	var runway_next := arrival_route[1]
	var outward := (
		runway_start - runway_next
	).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2(-1, 0)

	position = (
		runway_start
		+ outward * approach_spawn_distance
	)
	var final_direction := (
		runway_start - position
	).normalized()
	if final_direction != Vector2.ZERO:
		rotation = final_direction.angle()

	visible = true
	route_index = -1
	arrival_runway_cleared = false
	motion_sample_position = global_position
	motion_sample_initialized = true
	_set_state("HOLDING_FOR_ARRIVAL")
	set_turnaround_status(
		"Arrival ready\nTap LAND",
		"warning"
	)
	set_handling_action("LAND")
	return true


func continue_manual_taxi_in() -> bool:
	if (
		not manual_handling_enabled
		or state != "WAITING_TAXI_IN"
	):
		return false
	clear_handling_action()
	taxi_current_speed = 0.0
	_set_state("TAXIING_IN")
	return true


func _handling_action_label(
	action: String
) -> String:
	match action:
		"LAND":
			return "✈  LAND"
		"TAXI":
			return "↗  TAXI"
		"UNLOAD":
			return "↓  UNLOAD"
		"SERVICE":
			return "⚙  SERVICE"
		"LOAD":
			return "↑  LOAD"
		"SEND":
			return "✈  SEND"
		_:
			return action


func _build_handling_action_button() -> void:
	handling_action_button = Button.new()
	handling_action_button.custom_minimum_size = Vector2(
		92,
		34
	)
	handling_action_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	handling_action_button.focus_mode = (
		Control.FOCUS_NONE
	)
	handling_action_button.z_index = 170

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("0b3e5a", 0.96)
	normal.border_color = Color("67d7ff")
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 9.0
	normal.content_margin_right = 9.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	normal.shadow_color = Color(0, 0, 0, 0.32)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("14618a", 0.98)
	hover.border_color = Color("a6ecff")

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("082b40", 0.98)

	handling_action_button.add_theme_stylebox_override(
		"normal",
		normal
	)
	handling_action_button.add_theme_stylebox_override(
		"hover",
		hover
	)
	handling_action_button.add_theme_stylebox_override(
		"pressed",
		pressed
	)
	handling_action_button.add_theme_color_override(
		"font_color",
		Color("f7fcff")
	)
	handling_action_button.add_theme_font_size_override(
		"font_size",
		11
	)
	handling_action_button.pressed.connect(
		_on_handling_action_pressed
	)
	add_child(handling_action_button)
	handling_action_button.visible = false
	_sync_handling_action_transform()


func _on_handling_action_pressed() -> void:
	if pending_handling_action.is_empty():
		return
	handling_action_requested.emit(
		self,
		pending_handling_action
	)


func _sync_handling_action_transform() -> void:
	if handling_action_button == null:
		return
	var visual_scale := get_visual_scale()
	var vertical_clearance := maxf(
		visual_scale - 1.0,
		0.0
	) * 34.0
	var airborne_extra := get_airborne_visual_lift()
	var anchor := Vector2(
		-46,
		-100
		- vertical_clearance
		- airborne_extra
	).rotated(
		-rotation
	)
	handling_action_button.position = anchor
	handling_action_button.rotation = -rotation
	var pulse := (
		0.90
		+ 0.10
		* sin(
			visual_clock * 4.8
		)
	)
	handling_action_button.modulate = Color(
		1.0,
		1.0,
		1.0,
		pulse
	)
	handling_action_button.visible = (
		visible
		and not pending_handling_action.is_empty()
	)


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


func get_visual_scale() -> float:
	if aircraft_type_id.is_empty():
		return 1.0

	var passengers := int(
		aircraft_profile.get("passengers", 0)
	)
	var base_scale := 1.0
	match aircraft_size:
		"M":
			if passengers <= 0:
				base_scale = 1.34
			else:
				var medium_progress := clampf(
					(float(passengers) - 40.0) / 48.0,
					0.0,
					1.0
				)
				base_scale = lerpf(
					1.26,
					1.46,
					medium_progress
				)
		"L":
			base_scale = 1.62
		"XL":
			base_scale = 1.82
		_:
			if passengers <= 0:
				base_scale = 1.0
			else:
				var small_progress := clampf(
					(float(passengers) - 8.0) / 24.0,
					0.0,
					1.0
				)
				base_scale = lerpf(
					0.96,
					1.12,
					small_progress
				)

	return base_scale * AIRCRAFT_PRESENTATION_SCALE


func get_visual_half_length() -> float:
	return 25.0 * get_visual_scale()


func get_visual_half_span() -> float:
	return 18.0 * get_visual_scale()


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
	approach_speed = maxf(
		float(profile.get("approach_speed", approach_speed)),
		1.0
	)
	landing_speed = maxf(
		float(profile.get("landing_speed", landing_speed)),
		1.0
	)
	takeoff_speed = maxf(
		float(profile.get("takeoff_speed", takeoff_speed)),
		1.0
	)
	takeoff_acceleration = maxf(
		float(
			profile.get(
				"takeoff_acceleration",
				takeoff_acceleration
			)
		),
		1.0
	)
	approach_spawn_distance = maxf(
		float(
			profile.get(
				"approach_spawn_distance",
				approach_spawn_distance
			)
		),
		120.0
	)
	climb_out_distance = maxf(
		float(
			profile.get(
				"climb_out_distance",
				climb_out_distance
			)
		),
		160.0
	)
	approach_visual_lift = maxf(
		float(
			profile.get(
				"approach_visual_lift",
				approach_visual_lift
			)
		),
		0.0
	)
	climb_visual_lift = maxf(
		float(
			profile.get(
				"climb_visual_lift",
				climb_visual_lift
			)
		),
		0.0
	)
	taxi_turn_rate_deg = TaxiMotionRules.turn_rate_degrees(
		aircraft_size,
		profile
	)
	_sync_turnaround_status_transform()
	_sync_handling_action_transform()
	queue_redraw()


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


func configure_social_visit(
	data: Dictionary
) -> void:
	social_visit = not data.is_empty()
	social_visit_data = data.duplicate(true)
	queue_redraw()


func is_social_visitor() -> bool:
	return social_visit


func get_social_visit_data() -> Dictionary:
	return social_visit_data.duplicate(true)


func prepare_social_inbound() -> void:
	if not social_visit:
		return
	visible = false
	_set_state("HOLDING_FOR_ARRIVAL")


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

	var scale := get_visual_scale()

	var base := Vector2.ZERO
	match service_type:
		"passenger":
			base = Vector2(12, -38)
		"cargo":
			base = Vector2(-12, 36)
		"cleaning":
			base = Vector2(-16, -34)
		"catering":
			base = Vector2(16, 34)
		"fuel":
			base = Vector2(-4, -44)
		"pushback":
			base = Vector2(42, 0)
		_:
			base = Vector2(0, 38)

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


func reserve_pushback_path() -> Dictionary:
	var target := get_pushback_target_position()
	if taxi_traffic_controller == null:
		_set_taxi_hold(false, "")
		return {
			"allowed": true,
			"reason": "",
			"target": target
		}

	var result := taxi_traffic_controller.request_segment(
		self,
		global_position,
		target
	)
	var allowed := bool(result.get("allowed", false))
	if allowed:
		_set_taxi_hold(false, "")
	else:
		_set_taxi_hold(
			true,
			String(result.get("reason", "traffic"))
		)
	result["target"] = target
	return result


func release_pushback_path() -> void:
	_release_taxi_segment()
	if state == "PUSHBACK_PREP":
		_set_taxi_hold(false, "")


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
	var compact_text := text.replace("\n", " • ").strip_edges()
	if compact_text.length() > 28:
		var priority_suffix := ""
		for segment_variant in compact_text.split(" • "):
			var segment := String(segment_variant)
			if segment.contains("WAIT"):
				priority_suffix = " • " + segment
				break
		if priority_suffix.is_empty():
			for keyword in ["READY", "RUNWAY"]:
				if compact_text.contains(keyword):
					priority_suffix = " • " + keyword
					break
		var prefix_limit := maxi(
			27 - priority_suffix.length(),
			12
		)
		compact_text = (
			compact_text.substr(0, prefix_limit).strip_edges()
			+ "…"
			+ priority_suffix
		)
	turnaround_label.text = compact_text
	turnaround_panel.visible = not compact_text.is_empty()
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
	turnaround_panel.custom_minimum_size = Vector2(118, 30)
	turnaround_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turnaround_panel.z_index = 160
	var style := StyleBoxFlat.new()
	style.bg_color = Color("062a40", 0.94)
	style.border_color = Color("27b8e5")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
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
	turnaround_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	turnaround_label.clip_text = true
	turnaround_label.add_theme_font_size_override(
		"font_size",
		10
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
	var visual_scale := get_visual_scale()
	var vertical_clearance := maxf(
		visual_scale - 1.0,
		0.0
	) * 34.0
	var anchor := Vector2(
		-59,
		-58 - vertical_clearance
	).rotated(-rotation)
	turnaround_panel.position = anchor
	turnaround_panel.rotation = -rotation
	_sync_handling_action_transform()


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
		"WAITING_PASSENGERS",
		"WAITING_UNLOAD",
		"WAITING_SERVICE"
	]


func set_departure_route(
	points: PackedVector2Array,
	size_class: String = "S",
	assigned_stand_uid: int = -1,
	assigned_runway_uid: int = -1
) -> void:
	aircraft_size = size_class
	_sync_turnaround_status_transform()
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


func set_predeparture_transfer_route(
	points: PackedVector2Array
) -> bool:
	if points.size() < 2:
		return false
	predeparture_transfer_route = TaxiMotionRules.refined_route(
		points,
		aircraft_size,
		aircraft_profile
	)
	if predeparture_transfer_route.size() < 2:
		predeparture_transfer_route = points.duplicate()
	route_index = 0
	taxi_current_speed = 0.0
	visible = true
	position = predeparture_transfer_route[0]
	var first_direction := (
		predeparture_transfer_route[1]
		- predeparture_transfer_route[0]
	).normalized()
	if first_direction != Vector2.ZERO:
		rotation = first_direction.angle()
	_set_state("TAXIING_TO_STAND")
	set_turnaround_status(
		"Leaving hangar\nTaxi to load stand"
	)
	return true


func _process_predeparture_transfer(delta: float) -> void:
	if (
		predeparture_transfer_route.size() < 2
		or route_index >= predeparture_transfer_route.size() - 1
	):
		taxi_current_speed = 0.0
		_align_to_route_endpoint(predeparture_transfer_route)
		predeparture_transfer_route = PackedVector2Array()
		_set_state("WAITING_FUEL")
		predeparture_transfer_completed.emit()
		return

	var target_index := route_index + 1
	if not _request_taxi_segment(
		predeparture_transfer_route[route_index],
		predeparture_transfer_route[target_index]
	):
		taxi_current_speed = _approach_taxi_speed(
			taxi_current_speed,
			0.0,
			delta
		)
		return

	var target_speed := TaxiMotionRules.speed_for_target(
		predeparture_transfer_route,
		route_index,
		target_index,
		taxi_speed
	)
	if target_index >= predeparture_transfer_route.size() - 1:
		target_speed = minf(target_speed, taxi_speed * 0.54)
		target_speed *= TaxiMotionRules.braking_speed_factor(
			position.distance_to(
				predeparture_transfer_route[target_index]
			),
			aircraft_size,
			aircraft_profile,
			0.30
		)
	taxi_current_speed = _approach_taxi_speed(
		taxi_current_speed,
		target_speed,
		delta
	)
	if _move_toward_point(
		predeparture_transfer_route[target_index],
		taxi_current_speed,
		delta,
		taxi_turn_rate_deg,
		_taxi_heading_for_route(
			predeparture_transfer_route,
			target_index
		)
	):
		route_index = target_index
		_release_taxi_segment()
		if route_index >= predeparture_transfer_route.size() - 1:
			taxi_current_speed = 0.0
			_align_to_route_endpoint(predeparture_transfer_route)
			predeparture_transfer_route = PackedVector2Array()
			_set_state("WAITING_FUEL")
			predeparture_transfer_completed.emit()


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

	clear_handling_action()
	var runway_start := arrival_route[0]
	var runway_next := arrival_route[1]
	var outward := (runway_start - runway_next).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2(-1, 0)

	position = (
		runway_start
		+ outward * approach_spawn_distance
	)
	var final_direction := (
		runway_start - position
	).normalized()
	if final_direction != Vector2.ZERO:
		rotation = final_direction.angle()
	visible = true
	route_index = -1
	arrival_runway_cleared = false
	motion_sample_position = global_position
	motion_sample_initialized = true
	_set_state("APPROACH")


func _process(delta: float) -> void:
	visual_clock += delta
	_update_external_motion_feedback(delta)
	if _uses_live_aircraft_fx():
		visual_redraw_accumulator += delta
		if visual_redraw_accumulator >= 0.05:
			visual_redraw_accumulator = 0.0
			queue_redraw()
	else:
		visual_redraw_accumulator = 0.0
	if not motion_fx_kind.is_empty():
		motion_fx_elapsed += delta
		if motion_fx_elapsed >= _motion_fx_duration():
			motion_fx_kind = ""
		queue_redraw()

	_sync_turnaround_status_transform()
	_sync_handling_action_transform()
	match state:
		"TAXIING_TO_STAND":
			_process_predeparture_transfer(delta)

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

	motion_sample_position = global_position
	motion_sample_initialized = true


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
	if target_index >= departure_hold_short_index:
		target_speed *= TaxiMotionRules.braking_speed_factor(
			position.distance_to(
				departure_route[target_index]
			),
			aircraft_size,
			aircraft_profile,
			0.30
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
		taxi_turn_rate_deg,
		_taxi_heading_for_route(
			departure_route,
			target_index
		)
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
		_release_taxi_segment()
		delay_remaining = lineup_delay
		_set_state("LINE_UP")
		return

	# Runway clearance is not permission to drive through conflicting
	# taxi traffic. Reserve the hold-short -> runway-entry corridor so
	# another aircraft cannot cross the nose while this aircraft lines up.
	if not _request_taxi_segment(
		departure_route[route_index],
		departure_route[runway_entry_index]
	):
		taxi_current_speed = _approach_taxi_speed(
			taxi_current_speed,
			0.0,
			delta
		)
		return

	var target_speed := taxi_speed * 0.62
	target_speed *= TaxiMotionRules.braking_speed_factor(
		position.distance_to(
			departure_route[runway_entry_index]
		),
		aircraft_size,
		aircraft_profile,
		0.58
	)
	taxi_current_speed = _approach_taxi_speed(
		taxi_current_speed,
		target_speed,
		delta
	)
	if _move_toward_point(
		departure_route[runway_entry_index],
		taxi_current_speed,
		delta,
		taxi_turn_rate_deg,
		_departure_runway_heading()
	):
		route_index = runway_entry_index
		taxi_current_speed = 0.0
		_release_taxi_segment()
		delay_remaining = lineup_delay
		_set_state("LINE_UP")


func _process_takeoff_roll(delta: float) -> void:
	if departure_route.size() < 2:
		takeoff_velocity = 0.0
		return

	var runway_end_index := departure_route.size() - 1
	takeoff_velocity = minf(
		takeoff_velocity
		+ takeoff_acceleration * delta,
		takeoff_speed
	)

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

		departure_route.append(
			departure_route[runway_end_index]
			+ direction * climb_out_distance
		)
		_set_state("CLIMBING")


func _process_climb(delta: float) -> void:
	if departure_route.is_empty():
		return

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

	var threshold := arrival_route[0]
	var distance_to_threshold := position.distance_to(
		threshold
	)
	var approach_ratio := clampf(
		distance_to_threshold
		/ maxf(
			approach_spawn_distance,
			1.0
		),
		0.0,
		1.0
	)
	# Ease from cruise-like final-approach speed into landing speed instead
	# of snapping to a slower velocity at the runway threshold.
	var current_approach_speed := lerpf(
		landing_speed,
		approach_speed,
		approach_ratio
	)

	if _move_toward_point(
		threshold,
		current_approach_speed,
		delta,
		125.0
	):
		route_index = 0
		_set_state("LANDING_ROLL")


func _process_landing_roll(delta: float) -> void:
	if arrival_route.size() < 2:
		return

	var runway_exit_index := 1
	var threshold := arrival_route[0]
	var runway_exit := arrival_route[runway_exit_index]
	var rollout_length := maxf(
		threshold.distance_to(runway_exit),
		1.0
	)
	var remaining := position.distance_to(runway_exit)
	var rollout_ratio := clampf(
		remaining / rollout_length,
		0.0,
		1.0
	)
	var rollout_floor := taxi_speed * 0.78
	var current_speed := lerpf(
		rollout_floor,
		landing_speed,
		rollout_ratio
	)
	landing_roll_target_speed = current_speed
	if _move_toward_point(
		runway_exit,
		current_speed,
		delta,
		190.0
	):
		route_index = runway_exit_index
		if not arrival_runway_cleared:
			arrival_runway_cleared = true
			runway_cleared.emit()

		if (
			manual_handling_enabled
			and not handling_automation_enabled
		):
			taxi_current_speed = 0.0
			_set_state("WAITING_TAXI_IN")
			set_turnaround_status(
				"Runway clear\nTap TAXI",
				"warning"
			)
			set_handling_action("TAXI")
		else:
			_set_state("TAXIING_IN")


func _process_taxi_in(delta: float) -> void:
	if route_index >= arrival_route.size() - 1:
		taxi_current_speed = 0.0
		_align_to_route_endpoint(arrival_route)
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

	# Final stand approach slows progressively rather than switching to one
	# fixed slow speed at the last waypoint.
	if target_index >= arrival_route.size() - 1:
		target_speed = minf(
			target_speed,
			taxi_speed * 0.54
		)
		target_speed *= TaxiMotionRules.braking_speed_factor(
			position.distance_to(
				arrival_route[target_index]
			),
			aircraft_size,
			aircraft_profile,
			0.26
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
		taxi_turn_rate_deg,
		_taxi_heading_for_route(
			arrival_route,
			target_index
		)
	):
		route_index = target_index
		_release_taxi_segment()

		if not arrival_runway_cleared and route_index >= 2:
			arrival_runway_cleared = true
			runway_cleared.emit()

		if route_index >= arrival_route.size() - 1:
			taxi_current_speed = 0.0
			_align_to_route_endpoint(arrival_route)
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
	elif state in [
		"TAXIING_TO_STAND",
		"TAXIING_OUT",
		"TAXIING_IN"
	]:
		clear_turnaround_status()


func _move_toward_point(
	target: Vector2,
	speed: float,
	delta: float,
	turn_rate_degrees: float = -1.0,
	heading_override: float = NO_HEADING_OVERRIDE
) -> bool:
	var to_target := target - position
	var distance := to_target.length()
	if distance <= maxf(speed, 1.0) * delta:
		position = target
		if to_target.length() > 0.001:
			var target_heading := to_target.angle()
			if absf(heading_override) < 1000.0:
				target_heading = heading_override
			_rotate_toward_heading(
				target_heading,
				delta,
				turn_rate_degrees
			)
		queue_redraw()
		return true

	var direction := to_target.normalized()
	position += direction * maxf(speed, 1.0) * delta
	var target_heading := direction.angle()
	if absf(heading_override) < 1000.0:
		target_heading = heading_override
	_rotate_toward_heading(
		target_heading,
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


func _taxi_heading_for_route(
	route: PackedVector2Array,
	target_index: int
) -> float:
	return TaxiMotionRules.lookahead_heading(
		route,
		position,
		target_index,
		aircraft_size,
		aircraft_profile
	)


func _departure_runway_heading() -> float:
	if departure_route.size() < 2:
		return NO_HEADING_OVERRIDE
	var runway_end := departure_route[
		departure_route.size() - 1
	]
	var runway_entry := departure_route[
		departure_route.size() - 2
	]
	var direction := (
		runway_end - runway_entry
	).normalized()
	if direction == Vector2.ZERO:
		return NO_HEADING_OVERRIDE
	return direction.angle()


func _align_to_route_endpoint(
	route: PackedVector2Array
) -> void:
	if route.size() < 2:
		return
	rotation = TaxiMotionRules.endpoint_heading(route)
	queue_redraw()


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
	var previous_state := state
	state = new_state

	match new_state:
		"TAXIING_TO_STAND", "TAXIING_OUT":
			_start_motion_fx("taxi_start")
		"TAKEOFF_ROLL":
			_start_motion_fx("takeoff_start")
		"CLIMBING":
			_start_motion_fx("rotation")
		"LANDING_ROLL":
			_start_motion_fx("touchdown")
		"TAXIING_IN":
			if previous_state in [
				"LANDING_ROLL",
				"WAITING_TAXI_IN"
			]:
				_start_motion_fx("runway_exit")
		"PARKED":
			if previous_state == "TAXIING_IN":
				_start_motion_fx("stand_stop")

	if new_state not in [
		"TAXIING_TO_STAND",
		"TAXIING_OUT",
		"TAXIING_IN",
		"ENTERING_RUNWAY"
	]:
		_release_taxi_segment()
		_set_taxi_hold(false, "")
	if new_state in [
		"TAXIING_TO_STAND",
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


func _start_motion_fx(kind: String) -> void:
	motion_fx_kind = kind
	motion_fx_elapsed = 0.0
	queue_redraw()


func _motion_fx_duration() -> float:
	if motion_fx_kind == "touchdown":
		return TOUCHDOWN_FX_DURATION
	return MOTION_FX_DURATION


func _update_external_motion_feedback(delta: float) -> void:
	if not motion_sample_initialized:
		motion_sample_position = global_position
		motion_sample_initialized = true
		externally_moving = false
		external_motion_speed = 0.0
		return

	var distance := global_position.distance_to(
		motion_sample_position
	)
	external_motion_speed = (
		distance / maxf(delta, 0.001)
	)
	externally_moving = (
		state == "PUSHBACK_PREP"
		and distance >= EXTERNAL_PUSHBACK_MIN_DISTANCE
	)
	if externally_moving and motion_fx_kind != "pushback":
		_start_motion_fx("pushback")


func _airborne_shadow_factor() -> float:
	if (
		state == "HOLDING_FOR_ARRIVAL"
		and visible
		and not arrival_route.is_empty()
	):
		return 1.0
	if state == "APPROACH" and not arrival_route.is_empty():
		return clampf(
			position.distance_to(arrival_route[0])
			/ maxf(
				approach_spawn_distance,
				1.0
			),
			0.0,
			1.0
		)
	if state == "CLIMBING" and not departure_route.is_empty():
		var climb_target := departure_route[
			departure_route.size() - 1
		]
		return 1.0 - clampf(
			position.distance_to(climb_target)
			/ maxf(
				climb_out_distance,
				1.0
			),
			0.0,
			1.0
		)
	return 0.0


func get_airborne_visual_lift() -> float:
	var airborne := _airborne_shadow_factor()
	if state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH"
	]:
		return approach_visual_lift * airborne
	if state == "CLIMBING":
		return climb_visual_lift * airborne
	return 0.0


func get_airborne_visual_local_offset() -> Vector2:
	return Vector2(
		0,
		-get_airborne_visual_lift()
	).rotated(
		-global_rotation
	)


func get_flight_presentation_snapshot() -> Dictionary:
	return {
		"aircraft_type_id": aircraft_type_id,
		"state": state,
		"visible": visible,
		"approach_spawn_distance": approach_spawn_distance,
		"climb_out_distance": climb_out_distance,
		"approach_speed": approach_speed,
		"landing_speed": landing_speed,
		"takeoff_speed": takeoff_speed,
		"takeoff_acceleration": takeoff_acceleration,
		"airborne_factor": _airborne_shadow_factor(),
		"visual_lift": get_airborne_visual_lift()
	}


func get_motion_feedback_snapshot() -> Dictionary:
	return {
		"kind": motion_fx_kind,
		"elapsed": motion_fx_elapsed,
		"active": not motion_fx_kind.is_empty(),
		"pushback_motion": externally_moving,
		"external_speed": external_motion_speed,
		"shadow_airborne_factor": _airborne_shadow_factor(),
		"visual_lift": get_airborne_visual_lift(),
		"approach_spawn_distance": approach_spawn_distance,
		"climb_out_distance": climb_out_distance,
		"handling_action": pending_handling_action,
		"manual_handling": manual_handling_enabled,
		"handling_automation": handling_automation_enabled,
		"visual_clock": visual_clock,
		"landing_roll_target_speed": landing_roll_target_speed,
		"takeoff_speed_ratio": clampf(
			takeoff_velocity / maxf(takeoff_speed, 1.0),
			0.0,
			1.0
		),
		"production_motion_art": true,
		"motion_art_frames": AircraftMotionArt.frame_count()
	}


func _draw() -> void:
	_draw_shadow()
	_draw_motion_feedback()

	var visual_scale := get_visual_scale()
	draw_set_transform(
		get_airborne_visual_local_offset(),
		0.0,
		Vector2.ONE * visual_scale
	)

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

	if (
		event_featured
		and state not in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]
	):
		_draw_event_badge()
	elif (
		social_visit
		and state not in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]
	):
		_draw_social_badge()

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
		"WAITING_TAXI_IN", "WAITING_UNLOAD", "WAITING_SERVICE":
			draw_circle(Vector2(-2, -26), 6.0, Color("ffc66a"))

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_social_badge() -> void:
	var center := Vector2(-2, -39)
	var relationship := String(
		social_visit_data.get("relationship", "friend")
	)
	var fill := (
		Color("9b6bd6")
		if relationship == "alliance"
		else Color("4f9fc8")
	)
	draw_circle(center, 9.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 7.0, fill)
	draw_circle(center, 7.0, Color("eaf7ff"), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-5, 4),
		"A" if relationship == "alliance" else "F",
		HORIZONTAL_ALIGNMENT_CENTER,
		10.0,
		10,
		Color("ffffff")
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


func _draw_motion_feedback() -> void:
	var visual_scale := get_visual_scale()
	var progress := 1.0
	if not motion_fx_kind.is_empty():
		progress = clampf(
			motion_fx_elapsed / maxf(_motion_fx_duration(), 0.01),
			0.0,
			1.0
		)
	var fade := 1.0 - progress
	var main_gear_x := -4.0 * visual_scale
	var gear_span := 10.0 * visual_scale
	var tail_x := -get_visual_half_length() * 0.94

	match motion_fx_kind:
		"taxi_start":
			var taxi_texture := AircraftMotionArt.taxi_texture(progress)
			if taxi_texture != null:
				for side in [-1.0, 1.0]:
					_draw_motion_texture(
						taxi_texture,
						Vector2(
							main_gear_x - 7.0 * progress * visual_scale,
							gear_span * float(side)
						),
						Vector2(30, 22) * visual_scale,
						0.72 * fade
					)
			else:
				_draw_motion_fallback_puff(
					Vector2(main_gear_x, 0),
					5.0 * visual_scale,
					0.16 * fade
				)

		"takeoff_start":
			var wake := AircraftMotionArt.texture("takeoff_wake")
			if wake != null:
				_draw_motion_texture(
					wake,
					Vector2(tail_x - 16.0 * visual_scale, 0),
					Vector2(44, 34) * visual_scale,
					0.62 * fade
				)
			else:
				draw_line(
					Vector2(tail_x, 0),
					Vector2(tail_x - 24.0 * visual_scale, 0),
					Color(0.80, 0.92, 0.96, 0.16 * fade),
					1.4
				)

		"rotation":
			var lift_wake := AircraftMotionArt.texture("takeoff_wake")
			if lift_wake != null:
				_draw_motion_texture(
					lift_wake,
					Vector2(tail_x - 20.0 * visual_scale, 0),
					Vector2(52, 38) * visual_scale,
					0.55 * fade
				)

		"touchdown":
			var smoke := AircraftMotionArt.touchdown_texture(progress)
			if smoke != null:
				_draw_motion_texture(
					smoke,
					Vector2(
						main_gear_x - 8.0 * progress * visual_scale,
						0
					),
					Vector2(58, 42) * visual_scale,
					0.92 * fade
				)
			else:
				_draw_motion_fallback_puff(
					Vector2(main_gear_x, 0),
					10.0 * visual_scale,
					0.28 * fade
				)

		"runway_exit":
			var exit_puff := AircraftMotionArt.taxi_texture(progress)
			if exit_puff != null:
				_draw_motion_texture(
					exit_puff,
					Vector2(main_gear_x - 3.0, 0),
					Vector2(28, 20) * visual_scale,
					0.34 * fade
				)

		"stand_stop":
			var stop_texture := AircraftMotionArt.texture("stand_stop")
			if stop_texture != null:
				_draw_motion_texture(
					stop_texture,
					Vector2(main_gear_x - 2.0, 0),
					Vector2(30, 22) * visual_scale,
					0.56 * fade
				)

		"pushback":
			var pushback_texture := AircraftMotionArt.texture(
				"pushback_roll"
			)
			if pushback_texture != null:
				var pulse := 0.72 + 0.18 * sin(
					motion_fx_elapsed * 12.0
				)
				_draw_motion_texture(
					pushback_texture,
					Vector2(main_gear_x + 4.0 * visual_scale, 0),
					Vector2(34, 26) * visual_scale,
					pulse
				)

	if state == "TAKEOFF_ROLL":
		var speed_ratio := clampf(
			takeoff_velocity / maxf(takeoff_speed, 1.0),
			0.0,
			1.0
		)
		if speed_ratio > 0.20:
			var roll_wake := AircraftMotionArt.texture("takeoff_wake")
			if roll_wake != null:
				var wake_size := Vector2(
					40.0 + 30.0 * speed_ratio,
					30.0 + 14.0 * speed_ratio
				) * visual_scale
				_draw_motion_texture(
					roll_wake,
					Vector2(
						tail_x - 18.0 * speed_ratio * visual_scale,
						0
					),
					wake_size,
					0.28 + 0.32 * speed_ratio
				)

	if state == "PUSHBACK_PREP" and externally_moving:
		var live_pushback := AircraftMotionArt.texture("pushback_roll")
		if live_pushback != null:
			var speed_amount := clampf(
				external_motion_speed / 80.0,
				0.0,
				1.0
			)
			_draw_motion_texture(
				live_pushback,
				Vector2(13, 0) * visual_scale,
				Vector2(
					30.0 + 8.0 * speed_amount,
					24.0
				) * visual_scale,
				0.45 + 0.25 * speed_amount
			)

	if state in ["APPROACH", "CLIMBING"]:
		var airborne := _airborne_shadow_factor()
		var airborne_wake := AircraftMotionArt.texture("takeoff_wake")
		if airborne_wake != null and airborne > 0.04:
			var wake_size := Vector2(
				42.0 + airborne * 24.0,
				30.0 + airborne * 12.0
			) * visual_scale
			var wake_origin := (
				Vector2(
					-get_visual_half_length() * 0.88
					- 14.0 * airborne * visual_scale,
					0
				)
				+ get_airborne_visual_local_offset()
			)
			_draw_motion_texture(
				airborne_wake,
				wake_origin,
				wake_size,
				0.18 + airborne * 0.18
			)


func _draw_motion_texture(
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	alpha: float
) -> void:
	if texture == null:
		return
	draw_texture_rect(
		texture,
		Rect2(center - size * 0.5, size),
		false,
		Color(1, 1, 1, clampf(alpha, 0.0, 1.0))
	)


func _draw_motion_fallback_puff(
	center: Vector2,
	radius: float,
	alpha: float
) -> void:
	draw_circle(
		center,
		radius,
		Color(0.86, 0.90, 0.87, alpha)
	)


func _draw_shadow() -> void:
	if state == "EN_ROUTE":
		return

	var visual_scale := get_visual_scale()
	var airborne_factor := _airborne_shadow_factor()
	var shadow_offset := Vector2(4, 7).lerp(
		Vector2(18, 26),
		airborne_factor
	)
	var shadow_alpha := lerpf(1.0, 0.34, airborne_factor)
	draw_set_transform(
		shadow_offset * visual_scale,
		0.0,
		Vector2(
			visual_scale,
			visual_scale * 0.46
		)
	)

	# Two-layer aircraft-shaped shadow reads far better on the pale apron
	# than the old circular blob while remaining inexpensive to draw.
	# Approach/climb offset and softness now make altitude readable too.
	var soft_wing := PackedVector2Array([
		Vector2(7, -4),
		Vector2(-4, -23),
		Vector2(-12, -22),
		Vector2(-8, -4),
		Vector2(-8, 4),
		Vector2(-12, 22),
		Vector2(-4, 23),
		Vector2(7, 4)
	])
	draw_colored_polygon(
		soft_wing,
		Color(0, 0, 0, 0.11 * shadow_alpha)
	)

	var soft_fuselage := PackedVector2Array([
		Vector2(29, 0),
		Vector2(16, -7),
		Vector2(-19, -7),
		Vector2(-30, 0),
		Vector2(-19, 7),
		Vector2(16, 7)
	])
	draw_colored_polygon(
		soft_fuselage,
		Color(0, 0, 0, 0.15 * shadow_alpha)
	)
	draw_circle(
		Vector2(-1, 1),
		18.0,
		Color(0, 0, 0, 0.06 * shadow_alpha)
	)

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _uses_live_aircraft_fx() -> bool:
	if (
		aircraft_type_id not in [
			"pico_p8",
			"swift_s14",
			"comet_c22",
			"voyager_v32",
			"nimbus_n40",
			"arrow_a52",
			"atlas_a64",
			"falcon_f72",
			"horizon_h88"
		]
		or not visible
	):
		return false
	return state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH",
		"LANDING_ROLL",
		"WAITING_TAXI_IN",
		"TAXIING_IN",
		"PUSHBACK_PREP",
		"TAXIING_OUT",
		"HOLD_SHORT",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING"
	]


func get_visual_clock() -> float:
	return visual_clock


func _exit_tree() -> void:
	if is_instance_valid(taxi_traffic_controller):
		taxi_traffic_controller.unregister_aircraft(self)
