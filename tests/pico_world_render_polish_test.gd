extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	plane.configure_skyrama_handling(true)
	if plane.direction_textures.size() != 4:
		_fail("The Pico must keep all four production pixel sprite directions.")
		return
	if plane.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
		_fail("Isometric aircraft art should preserve crisp pixel detail at zoom.")
		return

	plane.visible = true
	plane.rotation = -PI * 0.25
	plane.state = "SIMPLE_WAITING_LOAD"
	var ground := plane.get_directional_shadow_snapshot()
	if String(ground.get("direction")) != "ne":
		_fail("Silhouette shadow orientation must match the real plane sprite.")
		return
	if absf(float(ground.get("width", 0)) - plane.get_directional_draw_width()) > 0.01:
		_fail("Shadow must follow the configured sprite width, not a generic size.")
		return

	plane.set_arrival_route(PackedVector2Array([
		Vector2(0, 0), Vector2(100, 100)
	]), -1, -1)
	plane.begin_arrival_after_clearance()
	var approach := plane.get_directional_shadow_snapshot()
	if float(approach.get("opacity", 1.0)) >= float(ground.get("opacity", 0.0)):
		_fail("High approach shadows should be softer than ground-level shadows.")
		return
	if float(approach.get("flatten", 1.0)) >= float(ground.get("flatten", 0.0)):
		_fail("Approach shadow should become flatter as the plane gains height.")
		return

	var card := AircraftContextCard.new()
	root.add_child(card)
	await process_frame
	plane.state = "SIMPLE_WAITING_LOAD"
	card.show_aircraft(plane, {}, 30, 60)
	if not plane.selection_highlight_active:
		_fail("Selected plane should have a subtle mint world highlight.")
		return
	card.close_card()
	if plane.selection_highlight_active:
		_fail("Closing the aircraft card must also clear the world highlight.")
		return

	var hud = preload("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_handling_attention("SO-001", "LOAD", 2)
	if String(hud.handling_attention_button.get_meta("game_style_key", "")) != "hud_mint:compact":
		_fail("LOAD next-action shortcut should use mint rather than orange.")
		return
	hud.set_handling_attention("SO-001", "SEND")
	if String(hud.handling_attention_button.get_meta("game_style_key", "")) != "gold:compact":
		_fail("SEND next-action shortcut should use warm gold.")
		return
	hud._update_top_bar_layout(850)
	hud.set_handling_attention("SO-001", "LOAD", 3)
	if hud.handling_attention_button.text != "LOAD +2":
		_fail("Compact mobile HUD should show a concise next-action count.")
		return
	hud.set_operation_status("Service complete", "success")
	if hud.bottom_status_label.get_theme_color("font_color") != GameUIStyle.COLOR_SUCCESS:
		_fail("Positive airport status messages should use mint text.")
		return

	print("PICO_RENDER_REFINEMENT_OK 4_views=true pixel_crisp=true shadow=true selection=true next_hud=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
