extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	if plane.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_fail("Pico pixel-art sprites should remain crisp at airport zoom levels.")
		return
	for heading in [-PI * 0.25, PI * 0.25, PI * 0.75, -PI * 0.75]:
		var direction := CareerAircraft.direction_for(heading)
		if not plane.direction_textures.has(direction):
			_fail("Pico must retain distinct production sprites for all headings.")
			return
		plane.global_rotation = heading
		plane.queue_redraw()

	# Artwork anchors must stay on the nose/wingtips in each raster view,
	# rather than drifting toward the fuselage when the sprite flips.
	var width := plane.get_directional_draw_width()
	var propellers: Dictionary = {}
	for direction in ["ne", "se", "sw", "nw"]:
		var prop: Vector2 = plane._pico_propeller_center(direction, width)
		var lights: Dictionary = plane._pico_navigation_points(direction, width)
		var red: Vector2 = lights.get("red", Vector2.ZERO)
		var green: Vector2 = lights.get("green", Vector2.ZERO)
		if prop.length() < width * 0.20 or prop.length() > width * 0.42:
			_fail("Pico propeller must sit near the visible nose: " + direction)
			return
		if absf(red.x - green.x) < width * 0.70:
			_fail("Wingtip lights should span the aircraft width: " + direction)
			return
		if absf(red.x) > width * 0.48 or absf(green.x) > width * 0.48:
			_fail("Wingtip lights should not sit outside the actual sprite: " + direction)
			return
		propellers[direction] = prop
	if propellers["ne"].x <= 0 or propellers["se"].x <= 0:
		_fail("Right-facing Pico sprites should retain their correct propeller anchors.")
		return
	if propellers["sw"].x >= 0 or propellers["nw"].x >= 0:
		_fail("Left-facing Pico sprites should retain their correct propeller anchors.")
		return
	plane._set_state("APPROACH")
	if not bool(plane.get_pico_visual_fx_snapshot().get("engine_running", false)):
		_fail("Pico propeller blur must run during the approach.")
		return
	plane._set_state("PARKED")
	if bool(plane.get_pico_visual_fx_snapshot().get("engine_running", true)):
		_fail("The parked Pico should keep the engine turned off.")
		return

	# Transparent production detail layers should exactly match the
	# existing approved Pico directional art; overlays never affect hitboxes.
	for direction in ["ne", "se", "sw", "nw"]:
		var base: Texture2D = plane.direction_textures.get(direction)
		var detail: Texture2D = plane.pico_detail_textures.get(direction)
		if base == null or detail == null:
			_fail("Pico must have base art and a refinement layer for " + direction)
			return
		if Vector2i(base.get_width(), base.get_height()) != Vector2i(
			detail.get_width(), detail.get_height()
		):
			_fail("Pico directional artwork and detail layers must match exactly: " + direction)
			return
	var untouched := CareerAircraft.new()
	root.add_child(untouched)
	await process_frame
	untouched.configure_aircraft_type("swift_s14")
	if not untouched.pico_detail_textures.is_empty():
		_fail("Pico cockpit/wing refinements must not alter other aircraft types.")
		return
	untouched.queue_free()

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	for icon_key in ["build", "fleet", "world", "tools", "fuel", "coins"]:
		if hud._hud_icon(icon_key) == null:
			_fail("Friendly HUD icons must remain rasterizable: " + icon_key)
			return

	print("PICO_HUD_VISUAL_REFINEMENT_OK headings=4 nearest=true detail_textures=4 hud_icons=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
