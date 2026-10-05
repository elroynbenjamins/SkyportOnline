extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids := [
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
	var widths: Dictionary = {}
	var radii: Dictionary = {}

	var fleet := FleetScreen.new()
	root.add_child(fleet)
	await process_frame

	for aircraft_id_variant in ids:
		var aircraft_id := String(aircraft_id_variant)
		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)

		if plane.direction_textures.size() != 4:
			_fail(
				"%s should load all four directional production sprites."
				% aircraft_id
			)
			return

		for direction in ["ne", "se", "sw", "nw"]:
			if not plane.direction_textures.has(direction):
				_fail(
					"%s is missing %s directional art."
					% [aircraft_id, direction]
				)
				return
			var texture = plane.direction_textures[direction]
			if not (texture is Texture2D):
				_fail(
					"%s %s art should import as Texture2D."
					% [aircraft_id, direction]
				)
				return

		var expected_ne := (
			"res://assets/pixel/aircraft/%s/%s_ne.png"
			% [aircraft_id, aircraft_id]
		)
		var fleet_texture := fleet._aircraft_texture(
			aircraft_id
		)
		if fleet_texture == null:
			_fail(
				"Fleet screen should resolve production art for %s."
				% aircraft_id
			)
			return
		if String(fleet_texture.resource_path) != expected_ne:
			_fail(
				"Fleet and world should share the same %s NE art."
				% aircraft_id
			)
			return

		var width := plane.get_directional_draw_width()
		var radius := plane.get_interaction_radius()
		widths[aircraft_id] = width
		radii[aircraft_id] = radius

		if radius < width * 0.50:
			_fail(
				"%s click radius should cover at least half of the rendered width."
				% aircraft_id
			)
			return

		var badge_y := plane.get_directional_badge_center_y()
		if absf(badge_y) < width * 0.38:
			_fail(
				"%s social/event badge should clear the production sprite."
				% aircraft_id
			)
			return

		plane.queue_free()

	if not (
		float(widths["pico_p8"])
		< float(widths["swift_s14"])
		and float(widths["swift_s14"])
		< float(widths["comet_c22"])
		and float(widths["comet_c22"])
		< float(widths["voyager_v32"])
	):
		_fail("S-class directional art should scale Pico < Swift < Comet < Voyager.")
		return

	if not (
		float(widths["nimbus_n40"])
		< float(widths["arrow_a52"])
		and float(widths["arrow_a52"])
		< float(widths["atlas_a64"])
		and float(widths["atlas_a64"])
		< float(widths["falcon_f72"])
		and float(widths["falcon_f72"])
		< float(widths["horizon_h88"])
	):
		_fail("M-class directional art should scale Nimbus through Horizon.")
		return

	if float(widths["nimbus_n40"]) <= float(widths["voyager_v32"]):
		_fail("First M aircraft should be visually larger than the largest S aircraft.")
		return

	if CareerAircraft.direction_for(-PI * 0.25) != "ne":
		_fail("Negative diagonal heading should use NE art.")
		return
	if CareerAircraft.direction_for(PI * 0.25) != "se":
		_fail("Positive diagonal heading should use SE art.")
		return
	if CareerAircraft.direction_for(PI * 0.75) != "sw":
		_fail("South-west heading should use SW art.")
		return
	if CareerAircraft.direction_for(-PI * 0.75) != "nw":
		_fail("North-west heading should use NW art.")
		return

	var horizon := CareerAircraft.new()
	root.add_child(horizon)
	await process_frame
	horizon.configure_aircraft_type("horizon_h88")
	horizon.configure_social_visit({
		"relationship": "alliance"
	})
	var horizon_badge := horizon.get_directional_badge_center_y()
	if absf(horizon_badge) < float(widths["horizon_h88"]) * 0.38:
		_fail("Horizon alliance badge should sit above the large production sprite.")
		return
	var npc_badge := horizon.get_directional_npc_badge_top_y()
	if absf(npc_badge) <= absf(horizon_badge):
		_fail("NPC banner should sit above the circular social/event badge.")
		return

	print(
		(
			"AIRCRAFT_DIRECTIONAL_COVERAGE_OK types=9 "
			+ "pico=%.1f voyager=%.1f nimbus=%.1f horizon=%.1f "
			+ "horizon_hit=%.1f"
		) % [
			float(widths["pico_p8"]),
			float(widths["voyager_v32"]),
			float(widths["nimbus_n40"]),
			float(widths["horizon_h88"]),
			float(radii["horizon_h88"])
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
