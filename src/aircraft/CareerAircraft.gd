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
	var base_width := 78.0
	match aircraft_size:
		"M":
			base_width = 88.0
		"L":
			base_width = 96.0
		"XL":
			base_width = 104.0
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
	if aircraft_type_id == "pico_p8":
		_draw_pico_operating_fx(
			width,
			direction_for(global_rotation)
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
