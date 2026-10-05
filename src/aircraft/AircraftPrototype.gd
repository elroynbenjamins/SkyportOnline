class_name AircraftPrototype
extends Node2D

signal runway_cleared
signal hold_short_reached
signal departed
signal arrival_requested
signal arrival_completed
signal state_changed(state: String)

const WORLD_SPRITE_BASE_SIZE := 94.0
const ISO_HEADING_ANGLE := 0.463647609
static var _world_sprite_cache: Dictionary = {}

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
var social_visit := false
var social_visit_data: Dictionary = {}
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
			return 62.0
		"L":
			return 74.0
		"XL":
			return 86.0
		_:
			return 46.0



func get_world_sprite_direction(
	heading: float = INF
) -> String:
	var resolved_heading := heading
	if is_inf(resolved_heading):
		resolved_heading = rotation

	var candidates: Array = [
		["ne", -ISO_HEADING_ANGLE],
		["se", ISO_HEADING_ANGLE],
		["sw", PI - ISO_HEADING_ANGLE],
		["nw", -PI + ISO_HEADING_ANGLE]
	]
	var best_direction := "ne"
	var best_difference := INF
	for candidate_variant in candidates:
		var candidate: Array = candidate_variant
		var direction := String(candidate[0])
		var candidate_heading := float(candidate[1])
		var difference := absf(
			wrapf(
				resolved_heading - candidate_heading,
				-PI,
				PI
			)
		)
		if difference < best_difference:
			best_difference = difference
			best_direction = direction
	return best_direction


func get_world_sprite_path(
	direction: String = ""
) -> String:
	if aircraft_type_id.is_empty():
		return ""
	var resolved_direction := direction
	if resolved_direction.is_empty():
		resolved_direction = get_world_sprite_direction()
	if resolved_direction not in ["ne", "nw", "se", "sw"]:
		return ""
	return (
		"res://assets/pixel/aircraft/%s/%s_%s.png"
		% [
			aircraft_type_id,
			aircraft_type_id,
			resolved_direction
		]
	)


func has_world_sprite_set() -> bool:
	if aircraft_type_id.is_empty():
		return false
	for direction in ["ne", "nw", "se", "sw"]:
		if not ResourceLoader.exists(
			get_world_sprite_path(direction)
		):
			return false
	return true


func get_world_sprite_draw_size() -> Vector2:
	var diameter := (
		WORLD_SPRITE_BASE_SIZE
		* get_visual_scale()
	)
	return Vector2(diameter, diameter)


func _get_world_sprite_texture(
	direction: String
) -> Texture2D:
	var path := get_world_sprite_path(direction)
	if path.is_empty():
		return null
	if _world_sprite_cache.has(path):
		var cached = _world_sprite_cache[path]
		if cached is Texture2D:
			return cached as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if resource is Texture2D:
		_world_sprite_cache[path] = resource
		return resource as Texture2D
	return null


func _draw_world_aircraft_sprite() -> bool:
	if not has_world_sprite_set():
		return false

	var direction := get_world_sprite_direction()
	var texture := _get_world_sprite_texture(
		direction
	)
	if texture == null:
		return false

	var draw_size := get_world_sprite_draw_size()
	var aspect := (
		float(texture.get_width())
		/ maxf(float(texture.get_height()), 1.0)
	)
	draw_size.x *= aspect

	var modulate := Color.WHITE
	if event_livery_enabled:
		match event_theme:
			"autumn":
				modulate = Color(1.0, 0.94, 0.86, 1.0)
			"winter":
				modulate = Color(0.93, 0.98, 1.0, 1.0)

	# The PNGs are already authored at the four isometric headings.
	# Counter-rotate the Node2D so the chosen sprite stays screen-aligned;
	# physics/service geometry continues to use the true continuous heading.
	draw_set_transform(
		Vector2.ZERO,
		-rotation,
		Vector2.ONE
	)
	draw_texture_rect(
		texture,
		Rect2(
			-draw_size * 0.5,
			draw_size
		),
		false,
		modulate
	)
	_draw_world_sprite_overlay(
		draw_size
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
	return true


func _draw_world_sprite_overlay(
	draw_size: Vector2
) -> void:
	var top_y := -draw_size.y * 0.40
	var badge_center := Vector2(
		-draw_size.x * 0.27,
		top_y
	)

	if (
		event_featured
		and state not in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]
	):
		var fill := Color("e6a83f")
		match event_theme:
			"autumn":
				fill = Color("d66d30")
			"winter":
				fill = Color("3f8ebd")
		draw_circle(
			badge_center,
			9.0,
			Color(0, 0, 0, 0.35)
		)
		draw_circle(
			badge_center,
			7.0,
			fill
		)
		draw_circle(
			badge_center,
			7.0,
			Color("ffe3a1"),
			false,
			2.0
		)
	elif (
		social_visit
		and state not in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]
	):
		var relationship := String(
			social_visit_data.get(
				"relationship",
				"friend"
			)
		)
		var fill := (
			Color("9b6bd6")
			if relationship == "alliance"
			else Color("4f9fc8")
		)
		draw_circle(
			badge_center,
			9.0,
			Color(0, 0, 0, 0.35)
		)
		draw_circle(
			badge_center,
			7.0,
			fill
		)
		draw_circle(
			badge_center,
			7.0,
			Color("eaf7ff"),
			false,
			2.0
		)

	var indicator_color := Color(0, 0, 0, 0)
	match state:
		"WAITING_FUEL", "SERVICING":
			indicator_color = Color("f4c95d")
		"UNLOADING", "HOLDING_FOR_ARRIVAL":
			indicator_color = Color("d6a3ff")
		"LOADING":
			indicator_color = Color("69c9dd")
		"PUSHBACK_PREP", "READY_FOR_DEPARTURE":
			indicator_color = Color("76d39b")
		"READY_FOR_DESTINATION":
			indicator_color = Color("f0a6ff")
		"WAITING_PASSENGERS":
			indicator_color = Color("ff9f68")
		"HOLD_SHORT":
			indicator_color = Color("f3c969")
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			indicator_color = Color("78b7e8")

	if indicator_color.a > 0.0:
		var indicator := Vector2(
			draw_size.x * 0.24,
			top_y
		)
		draw_circle(
			indicator,
			6.0,
			Color(0, 0, 0, 0.34)
		)
		draw_circle(
			indicator,
			4.5,
			indicator_color
		)


func get_visual_scale() -> float:
	var passengers := int(
		aircraft_profile.get("passengers", 0)
	)
	match aircraft_size:
		"M":
			if passengers <= 0:
				return 1.34
			var medium_progress := clampf(
				(float(passengers) - 40.0) / 48.0,
				0.0,
				1.0
			)
			return lerpf(1.26, 1.46, medium_progress)
		"L":
			return 1.62
		"XL":
			return 1.82
		_:
			if passengers <= 0:
				return 1.0
			var small_progress := clampf(
				(float(passengers) - 8.0) / 24.0,
				0.0,
				1.0
			)
			return lerpf(0.96, 1.12, small_progress)


func get_visual_design() -> Dictionary:
	var design := {
		"family": "generic",
		"nose_x": 22.0,
		"tail_x": -25.0,
		"fuselage_half_width": 5.0,
		"wing_half_span": 18.0,
		"wing_root_front_x": 4.0,
		"wing_root_back_x": -7.0,
		"wing_tip_front_x": -5.0,
		"wing_tip_back_x": -12.0,
		"tail_half_span": 11.0,
		"tail_root_front_x": -14.0,
		"tail_root_back_x": -20.0,
		"tail_tip_front_x": -19.0,
		"tail_tip_back_x": -23.0,
		"engine_style": "jet",
		"engine_x": -2.0,
		"engine_y_ratio": 0.56,
		"window_count": 4,
		"winglets": false,
		"body_color": Color("f4f7f7"),
		"belly_color": Color("c6d2d5"),
		"wing_color": Color("dce8ea"),
		"tail_color": Color("5d90b8"),
		"accent_color": Color("4f91bd"),
		"cockpit_color": Color("31586f")
	}

	match aircraft_type_id:
		"pico_p8":
			design.merge({
				"family": "compact_prop",
				"nose_x": 19.5,
				"tail_x": -21.5,
				"fuselage_half_width": 5.1,
				"wing_half_span": 16.8,
				"wing_root_front_x": 3.0,
				"wing_root_back_x": -6.2,
				"wing_tip_front_x": -0.5,
				"wing_tip_back_x": -5.5,
				"tail_half_span": 8.8,
				"tail_root_front_x": -13.0,
				"tail_root_back_x": -18.0,
				"tail_tip_front_x": -17.0,
				"tail_tip_back_x": -20.0,
				"engine_style": "prop",
				"engine_x": 0.5,
				"engine_y_ratio": 0.54,
				"window_count": 3,
				"tail_color": Color("3f78a9"),
				"accent_color": Color("e3b64e"),
				"cockpit_color": Color("315a72")
			}, true)
		"swift_s14":
			design.merge({
				"family": "fast_prop",
				"nose_x": 21.0,
				"tail_x": -23.0,
				"fuselage_half_width": 4.8,
				"wing_half_span": 18.0,
				"wing_root_front_x": 5.0,
				"wing_root_back_x": -7.0,
				"wing_tip_front_x": -3.0,
				"wing_tip_back_x": -9.0,
				"tail_half_span": 9.4,
				"engine_style": "prop",
				"engine_x": 1.0,
				"engine_y_ratio": 0.56,
				"window_count": 4,
				"tail_color": Color("2f7f83"),
				"accent_color": Color("37aaa2"),
				"cockpit_color": Color("275b69")
			}, true)
		"comet_c22":
			design.merge({
				"family": "compact_jet",
				"nose_x": 22.5,
				"tail_x": -24.0,
				"fuselage_half_width": 5.1,
				"wing_half_span": 18.8,
				"wing_root_front_x": 5.4,
				"wing_root_back_x": -8.0,
				"wing_tip_front_x": -5.0,
				"wing_tip_back_x": -11.5,
				"tail_half_span": 10.0,
				"engine_style": "jet",
				"engine_x": -1.5,
				"window_count": 5,
				"tail_color": Color("b95d3c"),
				"accent_color": Color("e58845"),
				"cockpit_color": Color("355b70")
			}, true)
		"voyager_v32":
			design.merge({
				"family": "stretched_jet",
				"nose_x": 24.0,
				"tail_x": -26.0,
				"fuselage_half_width": 5.3,
				"wing_half_span": 20.0,
				"wing_root_front_x": 6.0,
				"wing_root_back_x": -8.7,
				"wing_tip_front_x": -6.2,
				"wing_tip_back_x": -13.4,
				"tail_half_span": 10.6,
				"engine_style": "jet",
				"engine_x": -2.0,
				"window_count": 6,
				"tail_color": Color("5d4f8e"),
				"accent_color": Color("7d6db6"),
				"cockpit_color": Color("365970")
			}, true)
		"nimbus_n40":
			design.merge({
				"family": "regional_jet",
				"nose_x": 24.2,
				"tail_x": -26.5,
				"fuselage_half_width": 5.7,
				"wing_half_span": 20.6,
				"wing_root_front_x": 6.6,
				"wing_root_back_x": -9.2,
				"wing_tip_front_x": -5.4,
				"wing_tip_back_x": -14.2,
				"tail_half_span": 11.0,
				"engine_style": "jet",
				"engine_x": -1.0,
				"window_count": 6,
				"tail_color": Color("347fa5"),
				"accent_color": Color("4aa8d4"),
				"cockpit_color": Color("2f596f")
			}, true)
		"arrow_a52":
			design.merge({
				"family": "fast_regional",
				"nose_x": 25.0,
				"tail_x": -27.0,
				"fuselage_half_width": 5.6,
				"wing_half_span": 21.2,
				"wing_root_front_x": 7.6,
				"wing_root_back_x": -9.4,
				"wing_tip_front_x": -7.5,
				"wing_tip_back_x": -16.2,
				"tail_half_span": 11.4,
				"engine_style": "jet",
				"engine_x": -0.5,
				"window_count": 7,
				"winglets": true,
				"tail_color": Color("a84540"),
				"accent_color": Color("d7645c"),
				"cockpit_color": Color("31586c")
			}, true)
		"atlas_a64":
			design.merge({
				"family": "wide_regional",
				"nose_x": 25.8,
				"tail_x": -27.8,
				"fuselage_half_width": 6.0,
				"wing_half_span": 22.0,
				"wing_root_front_x": 7.0,
				"wing_root_back_x": -10.2,
				"wing_tip_front_x": -5.2,
				"wing_tip_back_x": -15.6,
				"tail_half_span": 11.8,
				"engine_style": "jet",
				"engine_x": -1.8,
				"window_count": 8,
				"tail_color": Color("78642f"),
				"accent_color": Color("d4b24d"),
				"cockpit_color": Color("36596c")
			}, true)
		"falcon_f72":
			design.merge({
				"family": "performance_regional",
				"nose_x": 26.3,
				"tail_x": -28.3,
				"fuselage_half_width": 5.8,
				"wing_half_span": 22.4,
				"wing_root_front_x": 8.2,
				"wing_root_back_x": -10.2,
				"wing_tip_front_x": -8.3,
				"wing_tip_back_x": -17.4,
				"tail_half_span": 12.0,
				"engine_style": "jet",
				"engine_x": -0.3,
				"window_count": 8,
				"winglets": true,
				"tail_color": Color("29475f"),
				"accent_color": Color("3b6992"),
				"cockpit_color": Color("2c536a")
			}, true)
		"horizon_h88":
			design.merge({
				"family": "flagship_regional",
				"nose_x": 27.2,
				"tail_x": -28.8,
				"fuselage_half_width": 6.2,
				"wing_half_span": 23.0,
				"wing_root_front_x": 8.5,
				"wing_root_back_x": -11.0,
				"wing_tip_front_x": -7.8,
				"wing_tip_back_x": -18.2,
				"tail_half_span": 12.4,
				"engine_style": "jet",
				"engine_x": -0.8,
				"window_count": 9,
				"winglets": true,
				"tail_color": Color("205f78"),
				"accent_color": Color("27b7c7"),
				"cockpit_color": Color("294f65")
			}, true)

	return design


func get_visual_half_length() -> float:
	var design := get_visual_design()
	return maxf(
		absf(float(design.get("nose_x", 22.0))),
		absf(float(design.get("tail_x", -25.0)))
	) * get_visual_scale()


func get_visual_half_span() -> float:
	var design := get_visual_design()
	return float(
		design.get("wing_half_span", 18.0)
	) * get_visual_scale()


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
	_sync_turnaround_status_transform()
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
		_release_taxi_segment()
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

	if _draw_world_aircraft_sprite():
		return

	var visual_scale := get_visual_scale()
	var design := get_visual_design()
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE * visual_scale
	)

	var nose_x := float(design.get("nose_x", 22.0))
	var tail_x := float(design.get("tail_x", -25.0))
	var body_half := float(
		design.get("fuselage_half_width", 5.0)
	)
	var wing_span := float(
		design.get("wing_half_span", 18.0)
	)
	var wing_root_front := float(
		design.get("wing_root_front_x", 4.0)
	)
	var wing_root_back := float(
		design.get("wing_root_back_x", -7.0)
	)
	var wing_tip_front := float(
		design.get("wing_tip_front_x", -5.0)
	)
	var wing_tip_back := float(
		design.get("wing_tip_back_x", -12.0)
	)
	var tail_span := float(
		design.get("tail_half_span", 11.0)
	)
	var tail_root_front := float(
		design.get("tail_root_front_x", -14.0)
	)
	var tail_root_back := float(
		design.get("tail_root_back_x", -20.0)
	)
	var tail_tip_front := float(
		design.get("tail_tip_front_x", -19.0)
	)
	var tail_tip_back := float(
		design.get("tail_tip_back_x", -23.0)
	)

	var body_color: Color = design.get(
		"body_color",
		Color("f4f7f7")
	)
	var belly_color: Color = design.get(
		"belly_color",
		Color("c6d2d5")
	)
	var wing_color: Color = design.get(
		"wing_color",
		Color("dce8ea")
	)
	var tail_color: Color = design.get(
		"tail_color",
		Color("5d90b8")
	)
	var accent_color: Color = design.get(
		"accent_color",
		Color("4f91bd")
	)
	var cockpit_color: Color = design.get(
		"cockpit_color",
		Color("31586f")
	)

	if event_livery_enabled:
		match event_theme:
			"autumn":
				body_color = Color("f4e6d0")
				tail_color = Color("c35f2d")
				accent_color = Color("e5a23b")
			"winter":
				body_color = Color("f7fcff")
				tail_color = Color("c8373c")
				accent_color = Color("2f8f58")

	var wing := PackedVector2Array([
		Vector2(wing_root_front, -body_half * 0.72),
		Vector2(wing_tip_front, -wing_span),
		Vector2(wing_tip_back, -wing_span),
		Vector2(wing_root_back, -body_half * 0.82),
		Vector2(wing_root_back, body_half * 0.82),
		Vector2(wing_tip_back, wing_span),
		Vector2(wing_tip_front, wing_span),
		Vector2(wing_root_front, body_half * 0.72)
	])
	var wing_shadow := PackedVector2Array()
	for point_variant in wing:
		var point: Vector2 = point_variant
		wing_shadow.append(
			point + Vector2(1.5, 1.8)
		)
	draw_colored_polygon(
		wing_shadow,
		wing_color.darkened(0.30)
	)
	draw_colored_polygon(
		wing,
		wing_color
	)
	draw_line(
		Vector2(wing_root_front - 1.0, -body_half * 0.72),
		Vector2(wing_tip_front + 1.0, -wing_span + 1.5),
		wing_color.lightened(0.22),
		1.1
	)
	draw_line(
		Vector2(wing_root_front - 1.0, body_half * 0.72),
		Vector2(wing_tip_front + 1.0, wing_span - 1.5),
		wing_color.lightened(0.15),
		1.0
	)

	var tailplane := PackedVector2Array([
		Vector2(tail_root_front, -body_half * 0.68),
		Vector2(tail_tip_front, -tail_span),
		Vector2(tail_tip_back, -tail_span),
		Vector2(tail_root_back, -body_half * 0.72),
		Vector2(tail_root_back, body_half * 0.72),
		Vector2(tail_tip_back, tail_span),
		Vector2(tail_tip_front, tail_span),
		Vector2(tail_root_front, body_half * 0.68)
	])
	draw_colored_polygon(
		tailplane,
		wing_color.darkened(0.03)
	)

	_draw_aircraft_engines(
		design,
		body_half,
		wing_span,
		wing_color,
		accent_color
	)

	var fuselage := PackedVector2Array([
		Vector2(nose_x, 0),
		Vector2(nose_x - 7.0, -body_half * 0.66),
		Vector2(tail_x + 6.5, -body_half),
		Vector2(tail_x, 0),
		Vector2(tail_x + 6.5, body_half),
		Vector2(nose_x - 7.0, body_half * 0.66)
	])
	var belly := PackedVector2Array()
	for point_variant in fuselage:
		var point: Vector2 = point_variant
		belly.append(
			point + Vector2(0.6, 1.5)
		)
	draw_colored_polygon(
		belly,
		belly_color
	)
	draw_colored_polygon(
		fuselage,
		body_color
	)

	draw_line(
		Vector2(nose_x - 8.0, -body_half * 0.55),
		Vector2(tail_x + 7.5, -body_half * 0.72),
		body_color.lightened(0.25),
		1.2
	)
	draw_line(
		Vector2(nose_x - 7.0, body_half * 0.72),
		Vector2(tail_x + 8.0, body_half * 0.88),
		belly_color.darkened(0.12),
		1.0
	)

	var accent_y := body_half * 0.56
	draw_line(
		Vector2(tail_x + 6.5, accent_y),
		Vector2(nose_x - 7.5, accent_y * 0.60),
		accent_color,
		1.7
	)
	draw_line(
		Vector2(tail_x + 6.5, -accent_y),
		Vector2(nose_x - 7.5, -accent_y * 0.60),
		accent_color.lightened(0.10),
		1.1
	)

	var rear_fin := PackedVector2Array([
		Vector2(tail_x + 2.0, -2.2),
		Vector2(tail_x + 10.0, -2.2),
		Vector2(tail_x + 12.0, 0),
		Vector2(tail_x + 10.0, 2.2),
		Vector2(tail_x + 2.0, 2.2)
	])
	draw_colored_polygon(
		rear_fin,
		tail_color
	)

	var cockpit := PackedVector2Array([
		Vector2(nose_x - 1.8, 0),
		Vector2(nose_x - 6.0, -2.3),
		Vector2(nose_x - 8.2, -1.5),
		Vector2(nose_x - 8.2, 1.5),
		Vector2(nose_x - 6.0, 2.3)
	])
	draw_colored_polygon(
		cockpit,
		cockpit_color
	)
	draw_line(
		Vector2(nose_x - 5.7, -1.6),
		Vector2(nose_x - 2.7, -0.5),
		Color("9fd4e2", 0.85),
		1.0
	)

	_draw_aircraft_windows(
		design,
		nose_x,
		tail_x,
		body_half,
		cockpit_color
	)

	if bool(design.get("winglets", false)):
		_draw_aircraft_winglets(
			wing_tip_front,
			wing_tip_back,
			wing_span,
			accent_color
		)

	draw_circle(
		Vector2(wing_tip_front, -wing_span),
		1.25,
		Color("d84a4a")
	)
	draw_circle(
		Vector2(wing_tip_front, wing_span),
		1.25,
		Color("4fc27b")
	)
	draw_circle(
		Vector2(nose_x - 0.5, 0),
		1.15,
		Color("f7e5a8")
	)

	if event_livery_enabled and event_theme == "autumn":
		draw_line(
			Vector2(-9, -wing_span * 0.60),
			Vector2(2, -body_half),
			Color("a94b2b"),
			2.4
		)

	if event_livery_enabled and event_theme == "winter":
		draw_circle(
			Vector2(tail_x + 5.0, 0),
			2.4,
			Color("f2c94c")
		)
		draw_line(
			Vector2(-9, -wing_span * 0.58),
			Vector2(1, -body_half),
			Color("c8373c"),
			2.4
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

	var state_indicator_y := -maxf(
		26.0,
		wing_span + 7.0
	)
	match state:
		"WAITING_FUEL":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("f4c95d"))
		"UNLOADING":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("d6a3ff"))
		"SERVICING":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("f4c95d"))
		"LOADING":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("69c9dd"))
		"PUSHBACK_PREP":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("76d39b"))
		"READY_FOR_DESTINATION":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("f0a6ff"))
		"WAITING_PASSENGERS":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("ff9f68"))
		"READY_FOR_DEPARTURE":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("76d39b"))
		"HOLD_SHORT":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("f3c969"))
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("78b7e8"))
		"HOLDING_FOR_ARRIVAL":
			draw_circle(Vector2(-2, state_indicator_y), 5.2, Color("d6a3ff"))

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _draw_aircraft_engines(
	design: Dictionary,
	body_half: float,
	wing_span: float,
	wing_color: Color,
	accent_color: Color
) -> void:
	var style := String(
		design.get("engine_style", "jet")
	)
	var engine_x := float(
		design.get("engine_x", -2.0)
	)
	var engine_y := wing_span * float(
		design.get("engine_y_ratio", 0.56)
	)

	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var y: float = engine_y * side
		if style == "prop":
			var pod := PackedVector2Array([
				Vector2(engine_x + 4.0, y),
				Vector2(engine_x + 1.5, y - 2.5),
				Vector2(engine_x - 4.5, y - 2.1),
				Vector2(engine_x - 6.2, y),
				Vector2(engine_x - 4.5, y + 2.1),
				Vector2(engine_x + 1.5, y + 2.5)
			])
			draw_colored_polygon(
				pod,
				wing_color.darkened(0.12)
			)
			draw_line(
				Vector2(engine_x + 5.3, y - 5.0),
				Vector2(engine_x + 5.3, y + 5.0),
				Color("627076", 0.72),
				1.1
			)
			draw_circle(
				Vector2(engine_x + 5.3, y),
				1.35,
				accent_color.darkened(0.12)
			)
		else:
			var nacelle := PackedVector2Array([
				Vector2(engine_x + 4.5, y),
				Vector2(engine_x + 2.0, y - 2.2),
				Vector2(engine_x - 4.2, y - 2.0),
				Vector2(engine_x - 5.8, y),
				Vector2(engine_x - 4.2, y + 2.0),
				Vector2(engine_x + 2.0, y + 2.2)
			])
			draw_colored_polygon(
				nacelle,
				Color("b9c8cc")
			)
			draw_circle(
				Vector2(engine_x + 3.1, y),
				1.55,
				Color("3f555e")
			)
			draw_circle(
				Vector2(engine_x + 3.1, y),
				0.75,
				Color("9fd1dc")
			)

		draw_line(
			Vector2(engine_x - 1.0, y),
			Vector2(engine_x - 6.0, y),
			Color("5d6b70", 0.45),
			0.9
		)


func _draw_aircraft_windows(
	design: Dictionary,
	nose_x: float,
	tail_x: float,
	body_half: float,
	cockpit_color: Color
) -> void:
	var count := maxi(
		int(design.get("window_count", 4)),
		2
	)
	var start_x := tail_x + 10.0
	var end_x := nose_x - 10.0
	if end_x <= start_x:
		return

	for index in range(count):
		var fraction := (
			0.5
			if count <= 1
			else float(index) / float(count - 1)
		)
		var x := lerpf(
			start_x,
			end_x,
			fraction
		)
		for side in [-1.0, 1.0]:
			draw_circle(
				Vector2(
					x,
					body_half * 0.72 * side
				),
				0.78,
				cockpit_color.lightened(0.08)
			)


func _draw_aircraft_winglets(
	wing_tip_front: float,
	wing_tip_back: float,
	wing_span: float,
	accent_color: Color
) -> void:
	var x := lerpf(
		wing_tip_front,
		wing_tip_back,
		0.45
	)
	draw_line(
		Vector2(x, -wing_span),
		Vector2(x - 1.5, -wing_span - 3.6),
		accent_color,
		1.8
	)
	draw_line(
		Vector2(x, wing_span),
		Vector2(x - 1.5, wing_span + 3.6),
		accent_color,
		1.8
	)


func _draw_social_badge() -> void:
	var design := get_visual_design()
	var wing_span := float(
		design.get("wing_half_span", 18.0)
	)
	var center := Vector2(
		-2,
		-maxf(39.0, wing_span + 20.0)
	)
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
	var design := get_visual_design()
	var wing_span := float(
		design.get("wing_half_span", 18.0)
	)
	var center := Vector2(
		-2,
		-maxf(39.0, wing_span + 20.0)
	)
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
			center + Vector2(-18, -11),
			event_marker_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			36.0,
			10,
			Color("fff0bd")
		)


func _draw_shadow() -> void:
	if state in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]:
		return

	var design := get_visual_design()
	var visual_scale := get_visual_scale()
	var half_length := maxf(
		absf(float(design.get("nose_x", 22.0))),
		absf(float(design.get("tail_x", -25.0)))
	)
	var wing_span := float(
		design.get("wing_half_span", 18.0)
	)
	var shadow_radius := maxf(
		half_length * 0.82,
		17.0
	)
	var y_ratio := clampf(
		(wing_span / maxf(half_length, 1.0)) * 0.58,
		0.34,
		0.56
	)
	draw_set_transform(
		Vector2(2, 4) * visual_scale,
		0.0,
		Vector2(
			visual_scale,
			visual_scale * y_ratio
		)
	)
	draw_circle(
		Vector2.ZERO,
		shadow_radius,
		Color(0, 0, 0, 0.25)
	)
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _exit_tree() -> void:
	if is_instance_valid(taxi_traffic_controller):
		taxi_traffic_controller.unregister_aircraft(self)
