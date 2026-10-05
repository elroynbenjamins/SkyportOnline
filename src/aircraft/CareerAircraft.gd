class_name CareerAircraft
extends AircraftPrototype

var direction_textures: Dictionary = {}
var last_direction := ""
var last_heading := INF

func configure_aircraft_type(type_id: String) -> void:
	super.configure_aircraft_type(type_id)
	direction_textures.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for direction in ["ne", "se", "sw", "nw"]:
		var path := "res://assets/pixel/aircraft/%s/%s_%s.png" % [type_id, type_id, direction]
		if ResourceLoader.exists(path):
			direction_textures[direction] = load(path)
	queue_redraw()

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
	if state in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL"]:
		return
	_draw_shadow()
	# Directional artwork is already isometric: cancel node rotation instead of rotating the image twice.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	var width := 108.0 if aircraft_size == "M" else 78.0
	var size := Vector2(width, width * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0))
	var tint := Color.WHITE
	if event_livery_enabled:
		tint = Color("fff0d9") if event_theme == "autumn" else Color("eaf7ff")
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	if social_visit:
		_draw_social_badge()
	elif event_featured:
		_draw_event_badge()
	if state in ["UNLOADING", "SERVICING", "LOADING", "PUSHBACK_PREP", "WAITING_PASSENGERS", "HOLD_SHORT"]:
		var status_color := Color("69c9dd")
		if state in ["WAITING_PASSENGERS", "HOLD_SHORT"]:
			status_color = Color("ffc66a")
		draw_circle(Vector2(-width * 0.38, -24), 4.0, status_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_social_badge() -> void:
	if String(social_visit_data.get("relationship", "")) != "npc":
		super._draw_social_badge()
		return
	var rect := Rect2(Vector2(-19, -51), Vector2(38, 17))
	draw_rect(rect, Color("203b35"))
	draw_rect(rect, Color("82d9a5"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-18, -38), "NPC", HORIZONTAL_ALIGNMENT_CENTER, 36, 11, Color("b9f3cf"))
