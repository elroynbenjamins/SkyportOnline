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
	var scales: Dictionary = {}

	for aircraft_id in ids:
		var plane := AircraftPrototype.new()
		root.add_child(plane)
		await process_frame
		plane.configure_aircraft_type(aircraft_id)

		var profile := AircraftCatalog.get_profile(
			aircraft_id
		)
		var scale := plane.get_visual_scale()
		scales[aircraft_id] = scale

		if scale <= 0.0:
			_fail("%s should have a positive visual scale." % aircraft_id)
			return
		if (
			plane.get_visual_half_length()
			>= plane.get_interaction_radius()
		):
			_fail(
				"%s visual length should stay inside its interaction radius."
				% aircraft_id
			)
			return

		var fuel_anchor := plane.get_service_docking_local_offset(
			"fuel"
		)
		if fuel_anchor.length() <= plane.get_visual_half_span():
			_fail(
				"%s fuel docking point should remain outside the visible wing span."
				% aircraft_id
			)
			return

		plane.queue_free()

	if not (
		float(scales["pico_p8"])
		< float(scales["swift_s14"])
		and float(scales["swift_s14"])
		< float(scales["comet_c22"])
		and float(scales["comet_c22"])
		< float(scales["voyager_v32"])
	):
		_fail("S aircraft visual scale should grow with capacity.")
		return

	if not (
		float(scales["nimbus_n40"])
		< float(scales["arrow_a52"])
		and float(scales["arrow_a52"])
		< float(scales["atlas_a64"])
		and float(scales["atlas_a64"])
		< float(scales["falcon_f72"])
		and float(scales["falcon_f72"])
		< float(scales["horizon_h88"])
	):
		_fail("M aircraft visual scale should grow with capacity.")
		return

	if (
		float(scales["nimbus_n40"])
		<= float(scales["voyager_v32"])
	):
		_fail(
			"First M aircraft should be visibly larger than the largest S aircraft."
		)
		return

	var generic := AircraftPrototype.new()
	root.add_child(generic)
	await process_frame
	if not is_equal_approx(
		generic.get_visual_scale(),
		1.0
	):
		_fail("Unconfigured generic aircraft should preserve the legacy 1.0 scale.")
		return

	generic.configure_aircraft_type("voyager_v32")
	generic.set_turnaround_status("READY", "success")
	var small_anchor_y := generic.turnaround_panel.position.y

	generic.configure_aircraft_type("horizon_h88")
	generic.set_turnaround_status("READY", "success")
	var medium_anchor_y := generic.turnaround_panel.position.y
	if medium_anchor_y >= small_anchor_y:
		_fail(
			"Larger aircraft should push the compact status bubble farther above the sprite."
		)
		return

	var medium_shadow_scale := generic.get_visual_scale()
	if medium_shadow_scale < 1.25:
		_fail("M aircraft shadow scale should visibly exceed the S baseline.")
		return

	# Production aircraft should be visibly smaller than their source art,
	# without reducing the mobile tap target or changing size ordering.
	var world_plane := CareerAircraft.new()
	root.add_child(world_plane)
	await process_frame
	for aircraft_id in ["pico_p8", "voyager_v32", "nimbus_n40", "horizon_h88"]:
		world_plane.configure_aircraft_type(aircraft_id)
		var expected_world_scale := (
			float(scales[aircraft_id])
			* CareerAircraft.AIRPORT_WORLD_VISUAL_SCALE
		)
		if not is_equal_approx(
			world_plane.get_visual_scale(),
			expected_world_scale
		):
			_fail("%s must use the world aircraft art multiplier." % aircraft_id)
			return
		var minimum_hit_radius := 44.0 if world_plane.aircraft_size == "M" else 36.0
		if world_plane.get_interaction_radius() < minimum_hit_radius:
			_fail("%s must keep its original mobile interaction radius." % aircraft_id)
			return
		if (
			world_plane.get_directional_draw_width() * 0.5
			> world_plane.get_interaction_radius()
		):
			_fail("%s sprite must remain inside the interaction target." % aircraft_id)
			return
	world_plane.queue_free()

	print(
		"AIRCRAFT_VISUAL_SCALE_OK pico=%.2f voyager=%.2f nimbus=%.2f horizon=%.2f"
		% [
			float(scales["pico_p8"]),
			float(scales["voyager_v32"]),
			float(scales["nimbus_n40"]),
			float(scales["horizon_h88"])
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
