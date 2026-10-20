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

	var hud := preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	for icon_key in ["build", "fleet", "world", "tools", "fuel", "coins"]:
		if hud._hud_icon(icon_key) == null:
			_fail("Friendly HUD icons must remain rasterizable: " + icon_key)
			return

	print("PICO_HUD_VISUAL_REFINEMENT_OK headings=4 nearest=true hud_icons=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
