extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not PicoSpriteArt.uses_refined_art():
		_fail("Pico V2 transparent sprite atlas did not import.")
		return
	if not ResourceLoader.exists(PicoSpriteArt.ATLAS_PATH):
		_fail("The new sprite PNG should be a real imported production asset.")
		return

	var seen: Dictionary = {}
	for angle in ["ne", "se", "sw", "nw"]:
		var view := PicoSpriteArt.texture_for(angle)
		if not (view is AtlasTexture):
			_fail("Pico angle %s should be an atlas region." % angle)
			return
		var frame := view as AtlasTexture
		if frame.get_width() != 128 or frame.get_height() != 128:
			_fail("Pico V2 needs 128×128 sprites to respect the current plane scale.")
			return
		if frame.region.size != Vector2(128, 128):
			_fail("Atlas crops cannot bleed between Pico angles.")
			return
		if seen.has(frame.region):
			_fail("Each angle must have its own atlas region.")
			return
		seen[frame.region] = true
		if PicoSpriteArt.texture_for(angle) != frame:
			_fail("Direction texture should reuse its cached GPU resource.")
			return

	var plane := CareerAircraft.new()
	root.add_child(plane)
	await process_frame
	plane.configure_aircraft_type("pico_p8")
	for angle in ["ne", "se", "sw", "nw"]:
		if plane.direction_textures.get(angle) != PicoSpriteArt.texture_for(angle):
			_fail("World plane has different art than the Pico atlas: " + angle)
			return
	if plane.get_directional_draw_width() > 78.0:
		_fail("New pixel art must not enlarge the starting plane above its small stand.")
		return
	if plane.get_interaction_radius() < plane.get_directional_draw_width() * 0.5:
		_fail("Tapping the updated plane should still be reliable.")
		return

	var fleet := FleetScreen.new()
	root.add_child(fleet)
	await process_frame
	if fleet._aircraft_texture("pico_p8") != PicoSpriteArt.texture_for("ne"):
		_fail("Fleet screen should display the same new Pico artwork.")
		return
	var detail := AircraftContextCard.new()
	root.add_child(detail)
	await process_frame
	if detail._aircraft_texture("pico_p8") != PicoSpriteArt.texture_for("ne"):
		_fail("Aircraft selection card should display the same new Pico artwork.")
		return
	if PicoSpriteArt.texture_for("invalid") != null:
		_fail("Unknown angles should not silently pick the wrong plane view.")
		return

	print("PICO_SPRITE_V2_OK views=4 transparent_atlas=true scale_safe=true fleet=true details=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
