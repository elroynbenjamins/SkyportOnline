class_name CareerAircraft
extends AircraftPrototype

var direction_textures: Dictionary = {}
var last_direction := ""
var last_heading := INF

func configure_aircraft_type(type_id: String) -> void:
	super.configure_aircraft_type(type_id)
	direction_textures.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for direction in ["ne", "se", "sw", "nw"]:
		var path := "res://assets/pixel/aircraft/%s/%s_%s.png" % [type_id, type_id, direction]
		if ResourceLoader.exists(path):
			direction_textures[direction] = load(path)
	queue_redraw()

func get_directional_draw_width() -> float:
	# Aircraft should read as substantial airport objects, not tiny markers
	# beside the buildings. S-class gets the largest relative lift because it
	# is what players see during onboarding.
	var base_width := 88.0
	match aircraft_size:
		"M":
			base_width = 94.0
		"L":
			base_width = 106.0
		"XL":
			base_width = 118.0
	return base_width * get_visual_scale()


func get_interaction_radius() -> float:
	return maxf(
		super.get_interaction_radius(),
		get_directional_draw_width() * 0.54
	)


func get_directional_badge_center_y() -> float:
	return -maxf(
		39.0,
		get_directional_draw_width() * 0.40
	)


func get_directional_npc_badge_top_y() -> float:
	return -maxf(
		51.0,
		get_directional_draw_width() * 0.46
	)


static func direction_for(angle: float) -> String:
	var direction := Vector2.RIGHT.rotated(angle)
	if direction.x >= 0.0:
		return "se" if direction.y >= 0.0 else "ne"
	return "sw" if direction.y >= 0.0 else "nw"

func _process(delta: float) -> void:
	super._process(delta)
	var direction := direction_for(global_rotation)
	if direction != last_direction or absf(global_rotation - last_heading) > 0.001:
		last_direction = direction
		last_heading = global_rotation
		queue_redraw()

func _draw() -> void:
	var texture: Texture2D = direction_textures.get(direction_for(global_rotation))
	if texture == null:
		super._draw()
		return
	if state == "EN_ROUTE":
		return
	if (
		state == "HOLDING_FOR_ARRIVAL"
		and not visible
	):
		return
	_draw_shadow()
	_draw_motion_feedback()
	# Directional artwork is already isometric: cancel node rotation instead of rotating the image twice.
	draw_set_transform(
		get_airborne_visual_local_offset(),
		-global_rotation,
		Vector2.ONE
	)
	var width := get_directional_draw_width()
	var size := Vector2(
		width,
		width * float(texture.get_height())
		/ maxf(float(texture.get_width()), 1.0)
	)
	var tint := Color.WHITE
	if event_livery_enabled:
		tint = Color("fff0d9") if event_theme == "autumn" else Color("eaf7ff")
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	var draw_direction := direction_for(global_rotation)
	if aircraft_type_id == "pico_p8":
		_draw_pico_operating_fx(
			width,
			draw_direction
		)
	elif aircraft_type_id == "swift_s14":
		_draw_swift_operating_fx(
			width,
			draw_direction
		)
	elif aircraft_type_id == "comet_c22":
		_draw_comet_operating_fx(
			width,
			draw_direction
		)
	elif aircraft_type_id == "voyager_v32":
		_draw_voyager_operating_fx(
			width,
			draw_direction
		)
	elif aircraft_type_id == "nimbus_n40":
		_draw_nimbus_operating_fx(
			width,
			draw_direction
		)
	elif _is_m_class_jet():
		_draw_m_jet_operating_fx(
			width,
			draw_direction
		)
	if social_visit:
		_draw_social_badge()
	elif event_featured:
		_draw_event_badge()
	if state in ["UNLOADING", "SERVICING", "LOADING", "PUSHBACK_PREP", "WAITING_PASSENGERS", "HOLD_SHORT"]:
		var status_color := Color("69c9dd")
		if state in ["WAITING_PASSENGERS", "HOLD_SHORT"]:
			status_color = Color("ffc66a")
		var status_y := -maxf(24.0, width * 0.28)
		draw_circle(
			Vector2(-width * 0.38, status_y),
			4.0,
			status_color
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _pico_engine_running() -> bool:
	if aircraft_type_id != "pico_p8":
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


func _pico_engine_throttle() -> float:
	match state:
		"HOLDING_FOR_ARRIVAL", "APPROACH":
			return 0.88
		"LANDING_ROLL":
			return 0.68
		"WAITING_TAXI_IN", "TAXIING_IN":
			return 0.42
		"PUSHBACK_PREP":
			return 0.24
		"TAXIING_OUT":
			return 0.46
		"HOLD_SHORT":
			return 0.40
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			return 0.58
		"TAKEOFF_ROLL", "CLIMBING":
			return 1.0
		_:
			return 0.0


func _pico_landing_lights_on() -> bool:
	return state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH",
		"LANDING_ROLL",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING"
	]


func _pico_propeller_center(
	direction: String,
	width: float
) -> Vector2:
	var normalized := Vector2(0.25, -0.18)
	match direction:
		"se":
			normalized = Vector2(0.27, 0.14)
		"sw":
			normalized = Vector2(-0.27, 0.14)
		"nw":
			normalized = Vector2(-0.25, -0.18)
	return normalized * width


func _pico_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.44, -0.23)
	var green := Vector2(0.45, 0.06)
	match direction:
		"se":
			red = Vector2(0.43, -0.18)
			green = Vector2(-0.45, 0.06)
		"sw":
			red = Vector2(0.43, 0.15)
			green = Vector2(-0.45, -0.12)
		"nw":
			red = Vector2(-0.43, 0.04)
			green = Vector2(0.44, -0.16)
	return {
		"red": red * width,
		"green": green * width
	}


func _draw_pico_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _pico_engine_running():
		return

	var throttle := _pico_engine_throttle()
	var clock := get_visual_clock()
	var prop_center := _pico_propeller_center(
		direction,
		width
	)
	var prop_radius := width * (
		0.080 + throttle * 0.025
	)

	# A soft disc plus rotating spokes makes the baked propeller read as live
	# without requiring another four-frame aircraft sprite set.
	draw_circle(
		prop_center,
		prop_radius,
		Color(
			0.84,
			0.91,
			0.94,
			0.07 + throttle * 0.08
		)
	)
	draw_arc(
		prop_center,
		prop_radius,
		0.0,
		TAU,
		22,
		Color(
			0.96,
			0.98,
			0.98,
			0.16 + throttle * 0.13
		),
		1.2
	)
	var spin_angle := clock * lerpf(
		8.0,
		24.0,
		throttle
	)
	for offset in [0.0, PI * 0.5]:
		var direction_vector := Vector2.RIGHT.rotated(
			spin_angle + float(offset)
		)
		draw_line(
			prop_center - direction_vector * prop_radius,
			prop_center + direction_vector * prop_radius,
			Color(
				0.98,
				0.94,
				0.72,
				0.22 + throttle * 0.18
			),
			1.25
		)

	var navigation := _pico_navigation_points(
		direction,
		width
	)
	var nav_pulse := (
		0.58
		+ 0.12
		* sin(
			clock * 5.2
		)
	)
	for entry in [
		{
			"position": navigation.get(
				"red",
				Vector2.ZERO
			),
			"color": Color(
				1.0,
				0.24,
				0.20,
				nav_pulse
			)
		},
		{
			"position": navigation.get(
				"green",
				Vector2.ZERO
			),
			"color": Color(
				0.22,
				1.0,
				0.54,
				nav_pulse
			)
		}
	]:
		var point: Vector2 = entry.get(
			"position",
			Vector2.ZERO
		)
		var color: Color = entry.get(
			"color",
			Color.WHITE
		)
		draw_circle(
			point,
			4.2,
			Color(
				color.r,
				color.g,
				color.b,
				color.a * 0.16
			)
		)
		draw_circle(
			point,
			1.65,
			color
		)

	var beacon_phase := fmod(
		clock,
		1.15
	)
	var beacon_on := (
		beacon_phase < 0.12
		or (
			beacon_phase > 0.23
			and beacon_phase < 0.31
		)
	)
	if beacon_on:
		var beacon := Vector2(
			0,
			-width * 0.06
		)
		draw_circle(
			beacon,
			5.0,
			Color(1.0, 0.14, 0.10, 0.12)
		)
		draw_circle(
			beacon,
			1.8,
			Color(1.0, 0.18, 0.14, 0.95)
		)

	var strobe_phase := fmod(
		clock,
		1.42
	)
	if strobe_phase < 0.07:
		for point_variant in navigation.values():
			var point: Vector2 = point_variant
			draw_circle(
				point,
				5.7,
				Color(0.92, 0.98, 1.0, 0.18)
			)
			draw_circle(
				point,
				2.0,
				Color(0.98, 1.0, 1.0, 0.98)
			)

	if _pico_landing_lights_on():
		var light_center := prop_center * 0.72
		draw_circle(
			light_center,
			6.8,
			Color(1.0, 0.94, 0.70, 0.08)
		)
		draw_circle(
			light_center,
			2.15,
			Color(1.0, 0.96, 0.80, 0.92)
		)


func get_pico_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(
		global_rotation
	)
	var throttle := _pico_engine_throttle()
	var beacon_phase := fmod(
		get_visual_clock(),
		1.15
	)
	return {
		"aircraft_type_id": aircraft_type_id,
		"direction": direction,
		"engine_running": _pico_engine_running(),
		"throttle": throttle,
		"propeller_center": _pico_propeller_center(
			direction,
			get_directional_draw_width()
		),
		"navigation_lights": _pico_engine_running(),
		"landing_lights": _pico_landing_lights_on(),
		"beacon_on": (
			beacon_phase < 0.12
			or (
				beacon_phase > 0.23
				and beacon_phase < 0.31
			)
		)
	}


func _swift_engine_running() -> bool:
	if aircraft_type_id != "swift_s14":
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


func _swift_engine_throttle() -> float:
	match state:
		"HOLDING_FOR_ARRIVAL", "APPROACH":
			return 0.84
		"LANDING_ROLL":
			return 0.65
		"WAITING_TAXI_IN", "TAXIING_IN":
			return 0.40
		"PUSHBACK_PREP":
			return 0.20
		"TAXIING_OUT":
			return 0.48
		"HOLD_SHORT":
			return 0.42
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			return 0.62
		"TAKEOFF_ROLL", "CLIMBING":
			return 1.0
		_:
			return 0.0


func _swift_landing_lights_on() -> bool:
	return state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH",
		"LANDING_ROLL",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING"
	]


func _swift_propeller_centers(
	direction: String,
	width: float
) -> Array[Vector2]:
	var left := Vector2(-0.13, -0.07)
	var right := Vector2(0.20, 0.08)
	match direction:
		"se":
			left = Vector2(-0.17, 0.03)
			right = Vector2(0.17, 0.16)
		"sw":
			left = Vector2(-0.17, 0.16)
			right = Vector2(0.17, 0.03)
		"nw":
			left = Vector2(-0.20, 0.08)
			right = Vector2(0.13, -0.07)
	return [
		left * width,
		right * width
	]


func _swift_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.46, -0.20)
	var green := Vector2(0.46, 0.06)
	match direction:
		"se":
			red = Vector2(0.46, -0.16)
			green = Vector2(-0.46, 0.07)
		"sw":
			red = Vector2(0.45, 0.14)
			green = Vector2(-0.45, -0.11)
		"nw":
			red = Vector2(-0.45, 0.05)
			green = Vector2(0.45, -0.15)
	return {
		"red": red * width,
		"green": green * width
	}


func _draw_turboprop_disc(
	center: Vector2,
	radius: float,
	throttle: float,
	clock: float,
	phase_offset: float = 0.0
) -> void:
	draw_circle(
		center,
		radius,
		Color(
			0.84,
			0.91,
			0.94,
			0.06 + throttle * 0.08
		)
	)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		22,
		Color(
			0.96,
			0.98,
			0.98,
			0.14 + throttle * 0.12
		),
		1.1
	)
	var spin_angle := (
		clock * lerpf(
			8.0,
			25.0,
			throttle
		)
		+ phase_offset
	)
	for offset in [0.0, PI * 0.5]:
		var direction_vector := Vector2.RIGHT.rotated(
			spin_angle + float(offset)
		)
		draw_line(
			center - direction_vector * radius,
			center + direction_vector * radius,
			Color(
				0.98,
				0.94,
				0.72,
				0.18 + throttle * 0.18
			),
			1.15
		)


func _draw_swift_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _swift_engine_running():
		return

	var throttle := _swift_engine_throttle()
	var clock := get_visual_clock()
	var centers := _swift_propeller_centers(
		direction,
		width
	)
	var radius := width * (
		0.070 + throttle * 0.022
	)
	for index in range(centers.size()):
		_draw_turboprop_disc(
			centers[index],
			radius,
			throttle,
			clock,
			float(index) * 0.74
		)

	var navigation := _swift_navigation_points(
		direction,
		width
	)
	var nav_pulse := (
		0.58
		+ 0.12
		* sin(
			clock * 5.4
		)
	)
	for entry in [
		{
			"position": navigation.get(
				"red",
				Vector2.ZERO
			),
			"color": Color(
				1.0,
				0.24,
				0.20,
				nav_pulse
			)
		},
		{
			"position": navigation.get(
				"green",
				Vector2.ZERO
			),
			"color": Color(
				0.22,
				1.0,
				0.54,
				nav_pulse
			)
		}
	]:
		var point: Vector2 = entry.get(
			"position",
			Vector2.ZERO
		)
		var color: Color = entry.get(
			"color",
			Color.WHITE
		)
		draw_circle(
			point,
			4.0,
			Color(
				color.r,
				color.g,
				color.b,
				color.a * 0.15
			)
		)
		draw_circle(
			point,
			1.6,
			color
		)

	var beacon_phase := fmod(
		clock + 0.18,
		1.10
	)
	var beacon_on := (
		beacon_phase < 0.11
		or (
			beacon_phase > 0.22
			and beacon_phase < 0.30
		)
	)
	if beacon_on:
		draw_circle(
			Vector2(0, -width * 0.05),
			5.0,
			Color(1.0, 0.14, 0.10, 0.12)
		)
		draw_circle(
			Vector2(0, -width * 0.05),
			1.8,
			Color(1.0, 0.18, 0.14, 0.95)
		)

	var strobe_phase := fmod(
		clock + 0.11,
		1.36
	)
	if strobe_phase < 0.07:
		for point_variant in navigation.values():
			var point: Vector2 = point_variant
			draw_circle(
				point,
				5.5,
				Color(0.92, 0.98, 1.0, 0.18)
			)
			draw_circle(
				point,
				1.9,
				Color(0.98, 1.0, 1.0, 0.98)
			)

	if _swift_landing_lights_on():
		for center_variant in centers:
			var center: Vector2 = center_variant
			var light_center := center * 0.58
			draw_circle(
				light_center,
				6.0,
				Color(1.0, 0.94, 0.70, 0.07)
			)
			draw_circle(
				light_center,
				2.0,
				Color(1.0, 0.96, 0.80, 0.90)
			)


func get_swift_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(
		global_rotation
	)
	var centers := _swift_propeller_centers(
		direction,
		get_directional_draw_width()
	)
	return {
		"aircraft_type_id": aircraft_type_id,
		"direction": direction,
		"engine_running": _swift_engine_running(),
		"throttle": _swift_engine_throttle(),
		"propeller_centers": centers,
		"propeller_count": centers.size(),
		"navigation_lights": _swift_engine_running(),
		"landing_lights": _swift_landing_lights_on()
	}


func _comet_engine_running() -> bool:
	if aircraft_type_id != "comet_c22":
		return false
	return _pico_engine_throttle() > 0.0


func _comet_propeller_center(
	direction: String,
	width: float
) -> Vector2:
	var normalized := Vector2(0.27, -0.17)
	match direction:
		"se":
			normalized = Vector2(0.29, 0.13)
		"sw":
			normalized = Vector2(-0.29, 0.13)
		"nw":
			normalized = Vector2(-0.27, -0.17)
	return normalized * width


func _comet_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.45, -0.21)
	var green := Vector2(0.46, 0.05)
	match direction:
		"se":
			red = Vector2(0.45, -0.17)
			green = Vector2(-0.46, 0.06)
		"sw":
			red = Vector2(0.45, 0.14)
			green = Vector2(-0.45, -0.11)
		"nw":
			red = Vector2(-0.45, 0.04)
			green = Vector2(0.45, -0.16)
	return {"red": red * width, "green": green * width}


func _draw_common_small_prop_lights(
	navigation: Dictionary,
	landing_centers: Array[Vector2],
	landing_on: bool,
	clock: float
) -> void:
	var nav_pulse := 0.58 + 0.12 * sin(clock * 5.3)
	for entry in [
		{
			"position": navigation.get("red", Vector2.ZERO),
			"color": Color(1.0, 0.24, 0.20, nav_pulse)
		},
		{
			"position": navigation.get("green", Vector2.ZERO),
			"color": Color(0.22, 1.0, 0.54, nav_pulse)
		}
	]:
		var point: Vector2 = entry.get("position", Vector2.ZERO)
		var color: Color = entry.get("color", Color.WHITE)
		draw_circle(
			point,
			4.0,
			Color(color.r, color.g, color.b, color.a * 0.15)
		)
		draw_circle(point, 1.6, color)

	var beacon_phase := fmod(clock + 0.09, 1.13)
	if (
		beacon_phase < 0.11
		or (
			beacon_phase > 0.22
			and beacon_phase < 0.30
		)
	):
		draw_circle(Vector2.ZERO, 4.8, Color(1.0, 0.14, 0.10, 0.12))
		draw_circle(Vector2.ZERO, 1.7, Color(1.0, 0.18, 0.14, 0.95))

	var strobe_phase := fmod(clock + 0.17, 1.39)
	if strobe_phase < 0.07:
		for point_variant in navigation.values():
			var point: Vector2 = point_variant
			draw_circle(point, 5.4, Color(0.92, 0.98, 1.0, 0.18))
			draw_circle(point, 1.9, Color(0.98, 1.0, 1.0, 0.98))

	if landing_on:
		for center_variant in landing_centers:
			var center: Vector2 = center_variant
			draw_circle(center, 6.0, Color(1.0, 0.94, 0.70, 0.07))
			draw_circle(center, 2.0, Color(1.0, 0.96, 0.80, 0.90))


func _draw_comet_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _comet_engine_running():
		return
	var throttle := _pico_engine_throttle()
	var clock := get_visual_clock()
	var center := _comet_propeller_center(direction, width)
	var radius := width * (0.076 + throttle * 0.024)
	_draw_turboprop_disc(center, radius, throttle, clock)
	var navigation := _comet_navigation_points(direction, width)
	_draw_common_small_prop_lights(
		navigation,
		[center * 0.70],
		_pico_landing_lights_on(),
		clock
	)


func get_comet_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(global_rotation)
	return {
		"aircraft_type_id": aircraft_type_id,
		"engine_running": _comet_engine_running(),
		"throttle": _pico_engine_throttle(),
		"propeller_count": 1,
		"propeller_center": _comet_propeller_center(
			direction,
			get_directional_draw_width()
		),
		"landing_lights": _pico_landing_lights_on()
	}


func _voyager_engine_running() -> bool:
	if aircraft_type_id != "voyager_v32":
		return false
	return _swift_engine_throttle() > 0.0


func _voyager_propeller_centers(
	direction: String,
	width: float
) -> Array[Vector2]:
	var left := Vector2(-0.15, -0.08)
	var right := Vector2(0.22, 0.08)
	match direction:
		"se":
			left = Vector2(-0.19, 0.04)
			right = Vector2(0.20, 0.17)
		"sw":
			left = Vector2(-0.20, 0.17)
			right = Vector2(0.19, 0.04)
		"nw":
			left = Vector2(-0.22, 0.08)
			right = Vector2(0.15, -0.08)
	return [left * width, right * width]


func _voyager_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.47, -0.20)
	var green := Vector2(0.47, 0.06)
	match direction:
		"se":
			red = Vector2(0.47, -0.16)
			green = Vector2(-0.47, 0.07)
		"sw":
			red = Vector2(0.46, 0.14)
			green = Vector2(-0.46, -0.11)
		"nw":
			red = Vector2(-0.46, 0.05)
			green = Vector2(0.46, -0.16)
	return {"red": red * width, "green": green * width}


func _draw_voyager_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _voyager_engine_running():
		return
	var throttle := _swift_engine_throttle()
	var clock := get_visual_clock()
	var centers := _voyager_propeller_centers(direction, width)
	var radius := width * (0.071 + throttle * 0.022)
	for index in range(centers.size()):
		_draw_turboprop_disc(
			centers[index],
			radius,
			throttle,
			clock,
			float(index) * 0.61
		)
	var navigation := _voyager_navigation_points(direction, width)
	var landing_centers: Array[Vector2] = []
	for center_variant in centers:
		var center: Vector2 = center_variant
		landing_centers.append(center * 0.58)
	_draw_common_small_prop_lights(
		navigation,
		landing_centers,
		_swift_landing_lights_on(),
		clock
	)


func get_voyager_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(global_rotation)
	var centers := _voyager_propeller_centers(
		direction,
		get_directional_draw_width()
	)
	return {
		"aircraft_type_id": aircraft_type_id,
		"engine_running": _voyager_engine_running(),
		"throttle": _swift_engine_throttle(),
		"propeller_count": centers.size(),
		"propeller_centers": centers,
		"landing_lights": _swift_landing_lights_on()
	}


func _nimbus_engine_running() -> bool:
	if aircraft_type_id != "nimbus_n40":
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


func _nimbus_engine_throttle() -> float:
	match state:
		"HOLDING_FOR_ARRIVAL", "APPROACH":
			return 0.80
		"LANDING_ROLL":
			return 0.60
		"WAITING_TAXI_IN", "TAXIING_IN":
			return 0.34
		"PUSHBACK_PREP":
			return 0.16
		"TAXIING_OUT":
			return 0.38
		"HOLD_SHORT":
			return 0.34
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			return 0.54
		"TAKEOFF_ROLL", "CLIMBING":
			return 1.0
		_:
			return 0.0


func _nimbus_landing_lights_on() -> bool:
	return state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH",
		"LANDING_ROLL",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING"
	]


func _nimbus_propeller_centers(
	direction: String,
	width: float
) -> Array[Vector2]:
	var left := Vector2(-0.15, -0.02)
	var right := Vector2(0.24, 0.10)
	match direction:
		"se":
			left = Vector2(-0.20, 0.10)
			right = Vector2(0.15, 0.19)
		"sw":
			left = Vector2(-0.15, 0.19)
			right = Vector2(0.20, 0.10)
		"nw":
			left = Vector2(-0.24, 0.10)
			right = Vector2(0.15, -0.02)
	return [
		left * width,
		right * width
	]


func _nimbus_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.46, -0.18)
	var green := Vector2(0.46, 0.08)
	match direction:
		"se":
			red = Vector2(0.45, -0.16)
			green = Vector2(-0.46, 0.09)
		"sw":
			red = Vector2(0.45, 0.15)
			green = Vector2(-0.45, -0.11)
		"nw":
			red = Vector2(-0.45, 0.06)
			green = Vector2(0.45, -0.15)
	return {
		"red": red * width,
		"green": green * width
	}


func _draw_nimbus_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _nimbus_engine_running():
		return

	var throttle := _nimbus_engine_throttle()
	var clock := get_visual_clock()
	var centers := _nimbus_propeller_centers(
		direction,
		width
	)
	var radius := width * (
		0.062 + throttle * 0.020
	)
	for index in range(centers.size()):
		_draw_turboprop_disc(
			centers[index],
			radius,
			throttle,
			clock * 0.90,
			float(index) * 0.92
		)

	var navigation := _nimbus_navigation_points(
		direction,
		width
	)
	var nav_pulse := (
		0.60
		+ 0.10 * sin(clock * 4.7)
	)
	for entry in [
		{
			"position": navigation.get("red", Vector2.ZERO),
			"color": Color(1.0, 0.22, 0.18, nav_pulse)
		},
		{
			"position": navigation.get("green", Vector2.ZERO),
			"color": Color(0.20, 1.0, 0.50, nav_pulse)
		}
	]:
		var point: Vector2 = entry.get("position", Vector2.ZERO)
		var color: Color = entry.get("color", Color.WHITE)
		draw_circle(
			point,
			4.5,
			Color(color.r, color.g, color.b, color.a * 0.16)
		)
		draw_circle(point, 1.8, color)

	var beacon_phase := fmod(clock + 0.07, 1.18)
	if (
		beacon_phase < 0.12
		or (
			beacon_phase > 0.25
			and beacon_phase < 0.33
		)
	):
		var beacon := Vector2(0, -width * 0.045)
		draw_circle(beacon, 5.5, Color(1.0, 0.14, 0.10, 0.13))
		draw_circle(beacon, 1.9, Color(1.0, 0.18, 0.14, 0.96))

	var strobe_phase := fmod(clock + 0.15, 1.46)
	if strobe_phase < 0.07:
		for point_variant in navigation.values():
			var point: Vector2 = point_variant
			draw_circle(point, 6.0, Color(0.92, 0.98, 1.0, 0.18))
			draw_circle(point, 2.1, Color(0.98, 1.0, 1.0, 0.98))

	if _nimbus_landing_lights_on():
		for center_variant in centers:
			var center: Vector2 = center_variant
			var light_center := center * 0.56
			draw_circle(
				light_center,
				6.5,
				Color(1.0, 0.94, 0.70, 0.08)
			)
			draw_circle(
				light_center,
				2.1,
				Color(1.0, 0.96, 0.80, 0.92)
			)


func get_nimbus_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(global_rotation)
	var centers := _nimbus_propeller_centers(
		direction,
		get_directional_draw_width()
	)
	return {
		"aircraft_type_id": aircraft_type_id,
		"engine_running": _nimbus_engine_running(),
		"throttle": _nimbus_engine_throttle(),
		"propeller_count": centers.size(),
		"propeller_centers": centers,
		"landing_lights": _nimbus_landing_lights_on(),
		"size": aircraft_size
	}


func _is_m_class_jet() -> bool:
	return aircraft_type_id in [
		"arrow_a52",
		"atlas_a64",
		"falcon_f72",
		"horizon_h88"
	]


func _m_jet_engine_running() -> bool:
	if not _is_m_class_jet():
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


func _m_jet_throttle() -> float:
	match state:
		"HOLDING_FOR_ARRIVAL", "APPROACH":
			return 0.68
		"LANDING_ROLL":
			return 0.44
		"WAITING_TAXI_IN", "TAXIING_IN":
			return 0.24
		"PUSHBACK_PREP":
			return 0.12
		"TAXIING_OUT":
			return 0.28
		"HOLD_SHORT":
			return 0.24
		"CLEARED", "ENTERING_RUNWAY", "LINE_UP":
			return 0.42
		"TAKEOFF_ROLL", "CLIMBING":
			return 1.0
		_:
			return 0.0


func _m_jet_landing_lights_on() -> bool:
	return state in [
		"HOLDING_FOR_ARRIVAL",
		"APPROACH",
		"LANDING_ROLL",
		"CLEARED",
		"ENTERING_RUNWAY",
		"LINE_UP",
		"TAKEOFF_ROLL",
		"CLIMBING"
	]


func _m_jet_engine_centers(
	direction: String,
	width: float
) -> Array[Vector2]:
	var left := Vector2(-0.13, -0.01)
	var right := Vector2(0.18, 0.10)
	match direction:
		"se":
			left = Vector2(-0.18, 0.08)
			right = Vector2(0.14, 0.17)
		"sw":
			left = Vector2(-0.14, 0.17)
			right = Vector2(0.18, 0.08)
		"nw":
			left = Vector2(-0.18, 0.10)
			right = Vector2(0.13, -0.01)

	var spread := 1.0
	match aircraft_type_id:
		"atlas_a64":
			spread = 1.04
		"falcon_f72":
			spread = 1.02
		"horizon_h88":
			spread = 1.06
	return [
		left * width * spread,
		right * width * spread
	]


func _m_jet_navigation_points(
	direction: String,
	width: float
) -> Dictionary:
	var red := Vector2(-0.47, -0.18)
	var green := Vector2(0.47, 0.08)
	match direction:
		"se":
			red = Vector2(0.46, -0.16)
			green = Vector2(-0.47, 0.09)
		"sw":
			red = Vector2(0.46, 0.15)
			green = Vector2(-0.46, -0.11)
		"nw":
			red = Vector2(-0.46, 0.06)
			green = Vector2(0.46, -0.15)
	return {
		"red": red * width,
		"green": green * width
	}


func _m_jet_performance_factor() -> float:
	match aircraft_type_id:
		"arrow_a52":
			return 1.06
		"atlas_a64":
			return 0.88
		"falcon_f72":
			return 1.12
		"horizon_h88":
			return 0.98
		_:
			return 1.0


func _draw_m_jet_operating_fx(
	width: float,
	direction: String
) -> void:
	if not _m_jet_engine_running():
		return

	var clock := get_visual_clock()
	var throttle := _m_jet_throttle()
	var performance := _m_jet_performance_factor()
	var centers := _m_jet_engine_centers(
		direction,
		width
	)

	for index in range(centers.size()):
		var center := centers[index]
		var pulse := (
			0.78
			+ 0.22 * sin(
				clock * (8.0 + performance * 2.0)
				+ float(index) * 1.1
			)
		)
		var engine_glow := width * (
			0.022
			+ throttle * 0.010
		)
		draw_circle(
			center,
			engine_glow * 2.3,
			Color(
				0.58,
				0.80,
				0.92,
				0.035 + throttle * 0.055
			)
		)
		draw_circle(
			center,
			engine_glow,
			Color(
				0.84,
				0.93,
				0.98,
				0.14 + throttle * 0.18
			)
		)

		var exhaust_length := width * (
			0.09
			+ throttle * 0.12 * performance
		)
		var exhaust_dir := Vector2(-1, 0)
		for lane in [-1.0, 0.0, 1.0]:
			var offset := Vector2(
				0,
				float(lane) * width * 0.006
			)
			draw_line(
				center + offset,
				center
					+ exhaust_dir * exhaust_length
					+ offset,
				Color(
					0.70,
					0.88,
					0.96,
					(0.025 + throttle * 0.075)
					* pulse
				),
				1.0
			)

	var navigation := _m_jet_navigation_points(
		direction,
		width
	)
	var nav_alpha := (
		0.60
		+ 0.10 * sin(clock * 4.8)
	)
	for entry in [
		{
			"position": navigation.get("red", Vector2.ZERO),
			"color": Color(1.0, 0.22, 0.18, nav_alpha)
		},
		{
			"position": navigation.get("green", Vector2.ZERO),
			"color": Color(0.20, 1.0, 0.50, nav_alpha)
		}
	]:
		var point: Vector2 = entry.get("position", Vector2.ZERO)
		var color: Color = entry.get("color", Color.WHITE)
		draw_circle(
			point,
			4.8,
			Color(color.r, color.g, color.b, color.a * 0.16)
		)
		draw_circle(point, 1.9, color)

	var beacon_phase := fmod(
		clock + performance * 0.10,
		1.12
	)
	if (
		beacon_phase < 0.11
		or (
			beacon_phase > 0.23
			and beacon_phase < 0.31
		)
	):
		var beacon := Vector2(0, -width * 0.045)
		draw_circle(
			beacon,
			5.8,
			Color(1.0, 0.14, 0.10, 0.13)
		)
		draw_circle(
			beacon,
			2.0,
			Color(1.0, 0.18, 0.14, 0.96)
		)

	var strobe_phase := fmod(
		clock + 0.17,
		1.38
	)
	if strobe_phase < 0.07:
		for point_variant in navigation.values():
			var point: Vector2 = point_variant
			draw_circle(
				point,
				6.2,
				Color(0.92, 0.98, 1.0, 0.18)
			)
			draw_circle(
				point,
				2.2,
				Color(0.98, 1.0, 1.0, 0.98)
			)

	if _m_jet_landing_lights_on():
		for center_variant in centers:
			var center: Vector2 = center_variant
			var light_center := center * 0.52
			draw_circle(
				light_center,
				7.0,
				Color(1.0, 0.94, 0.70, 0.08)
			)
			draw_circle(
				light_center,
				2.25,
				Color(1.0, 0.96, 0.80, 0.94)
			)


func get_m_jet_visual_fx_snapshot() -> Dictionary:
	var direction := direction_for(global_rotation)
	var centers := _m_jet_engine_centers(
		direction,
		get_directional_draw_width()
	)
	return {
		"aircraft_type_id": aircraft_type_id,
		"engine_running": _m_jet_engine_running(),
		"throttle": _m_jet_throttle(),
		"engine_count": centers.size(),
		"engine_centers": centers,
		"landing_lights": _m_jet_landing_lights_on(),
		"performance_factor": _m_jet_performance_factor(),
		"size": aircraft_size
	}


func _draw_social_badge() -> void:
	var relationship := String(
		social_visit_data.get("relationship", "friend")
	)
	if relationship == "npc":
		var badge_y := get_directional_npc_badge_top_y()
		var rect := Rect2(
			Vector2(-19, badge_y),
			Vector2(38, 17)
		)
		draw_rect(rect, Color("203b35"))
		draw_rect(rect, Color("82d9a5"), false, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-18, badge_y + 13),
			"NPC",
			HORIZONTAL_ALIGNMENT_CENTER,
			36,
			11,
			Color("b9f3cf")
		)
		return

	var center := Vector2(
		-2,
		get_directional_badge_center_y()
	)
	var fill := (
		Color("9b6bd6")
		if relationship == "alliance"
		else Color("4f9fc8")
	)
	draw_circle(center, 9.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 7.0, fill)
	draw_circle(
		center,
		7.0,
		Color("eaf7ff"),
		false,
		2.0
	)
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
	var center := Vector2(
		-2,
		get_directional_badge_center_y()
	)
	var fill := Color("e6a83f")
	match event_theme:
		"autumn":
			fill = Color("d66d30")
		"winter":
			fill = Color("3f8ebd")

	draw_circle(center, 9.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 7.0, fill)
	draw_circle(
		center,
		7.0,
		Color("ffe3a1"),
		false,
		2.0
	)
	var diamond := PackedVector2Array([
		center + Vector2(0, -4),
		center + Vector2(4, 0),
		center + Vector2(0, 4),
		center + Vector2(-4, 0)
	])
	draw_colored_polygon(
		diamond,
		Color("fff0bd")
	)

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
