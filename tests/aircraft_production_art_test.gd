extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_families := {
		"pico_p8": "compact_prop",
		"swift_s14": "fast_prop",
		"comet_c22": "compact_jet",
		"voyager_v32": "stretched_jet",
		"nimbus_n40": "regional_jet",
		"arrow_a52": "fast_regional",
		"atlas_a64": "wide_regional",
		"falcon_f72": "performance_regional",
		"horizon_h88": "flagship_regional"
	}
	var seen_families: Dictionary = {}
	var seen_accents: Dictionary = {}
	var previous_windows := 0

	for aircraft_id_variant in expected_families.keys():
		var aircraft_id := String(aircraft_id_variant)
		var plane := AircraftPrototype.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)

		if not plane.has_world_sprite_set():
			_fail("%s should have all four production world sprites." % aircraft_id)
			return
		for direction in ["ne", "nw", "se", "sw"]:
			var sprite_path := plane.get_world_sprite_path(direction)
			if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
				_fail(
					"%s missing %s production sprite."
					% [aircraft_id, direction]
				)
				return
			var resource = load(sprite_path)
			if not (resource is Texture2D):
				_fail(
					"%s %s sprite should load as Texture2D."
					% [aircraft_id, direction]
				)
				return

		var design := plane.get_visual_design()
		var family := String(design.get("family", ""))
		if family != String(expected_families[aircraft_id]):
			_fail(
				"%s should use visual family %s, got %s."
				% [
					aircraft_id,
					String(expected_families[aircraft_id]),
					family
				]
			)
			return
		seen_families[family] = true

		var accent: Color = design.get(
			"accent_color",
			Color.WHITE
		)
		seen_accents[accent.to_html()] = true

		var engine_style := String(
			design.get("engine_style", "")
		)
		if aircraft_id in ["pico_p8", "swift_s14"]:
			if engine_style != "prop":
				_fail("%s should read visually as a prop aircraft." % aircraft_id)
				return
		elif engine_style != "jet":
			_fail("%s should read visually as a jet aircraft." % aircraft_id)
			return

		var nose_x := absf(
			float(design.get("nose_x", 0.0))
		)
		var tail_x := absf(
			float(design.get("tail_x", 0.0))
		)
		var wing_span := float(
			design.get("wing_half_span", 0.0)
		)
		if nose_x <= 0.0 or tail_x <= 0.0 or wing_span <= 0.0:
			_fail("%s should have complete aircraft geometry." % aircraft_id)
			return

		if (
			plane.get_visual_half_length()
			>= plane.get_interaction_radius()
		):
			_fail("%s visual length must stay inside interaction radius." % aircraft_id)
			return
		if (
			plane.get_visual_half_span()
			>= plane.get_interaction_radius()
		):
			_fail("%s visual span must stay inside interaction radius." % aircraft_id)
			return

		var windows := int(
			design.get("window_count", 0)
		)
		if windows < 2:
			_fail("%s should expose readable cabin-window detail." % aircraft_id)
			return
		if (
			aircraft_id == "horizon_h88"
			and windows <= previous_windows
		):
			_fail("Horizon H88 should carry the densest window treatment.")
			return
		previous_windows = maxi(previous_windows, windows)

		if (
			aircraft_id in ["arrow_a52", "falcon_f72", "horizon_h88"]
			and not bool(design.get("winglets", false))
		):
			_fail("%s should use the fast/flagship winglet treatment." % aircraft_id)
			return

		plane.queue_free()

	if seen_families.size() != 9:
		_fail("All nine V1 aircraft should have distinct visual families.")
		return
	if seen_accents.size() < 8:
		_fail("V1 aircraft should have strongly differentiated liveries.")
		return

	var pico := AircraftPrototype.new()
	var horizon := AircraftPrototype.new()
	root.add_child(pico)
	root.add_child(horizon)
	await process_frame
	pico.configure_aircraft_type("pico_p8")
	horizon.configure_aircraft_type("horizon_h88")

	if (
		horizon.get_visual_half_length()
		<= pico.get_visual_half_length() * 1.75
	):
		_fail("Flagship regional aircraft should read substantially larger than Pico P8.")
		return
	if (
		horizon.get_visual_half_span()
		<= pico.get_visual_half_span() * 1.75
	):
		_fail("Flagship regional wing span should read substantially larger than Pico P8.")
		return

	var horizon_design := horizon.get_visual_design()
	if String(horizon_design.get("engine_style", "")) != "jet":
		_fail("Horizon H88 should retain jet-engine treatment.")
		return

	var heading_probe := AircraftPrototype.new()
	root.add_child(heading_probe)
	await process_frame
	heading_probe.configure_aircraft_type("horizon_h88")
	if heading_probe.get_world_sprite_direction(-AircraftPrototype.ISO_HEADING_ANGLE) != "ne":
		_fail("NE isometric heading should resolve to the NE sprite.")
		return
	if heading_probe.get_world_sprite_direction(AircraftPrototype.ISO_HEADING_ANGLE) != "se":
		_fail("SE isometric heading should resolve to the SE sprite.")
		return
	if heading_probe.get_world_sprite_direction(PI - AircraftPrototype.ISO_HEADING_ANGLE) != "sw":
		_fail("SW isometric heading should resolve to the SW sprite.")
		return
	if heading_probe.get_world_sprite_direction(-PI + AircraftPrototype.ISO_HEADING_ANGLE) != "nw":
		_fail("NW isometric heading should resolve to the NW sprite.")
		return

	var world_size := heading_probe.get_world_sprite_draw_size()
	if world_size.x < 110.0 or world_size.y < 110.0:
		_fail("Horizon production sprite should read substantially larger at world scale.")
		return
	if world_size.x > 150.0 or world_size.y > 150.0:
		_fail("Horizon production sprite should remain appropriate for a medium stand.")
		return

	print(
		"AIRCRAFT_PRODUCTION_ART_OK families=%d liveries=%d pico_length=%.2f horizon_length=%.2f"
		% [
			seen_families.size(),
			seen_accents.size(),
			pico.get_visual_half_length(),
			horizon.get_visual_half_length()
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
