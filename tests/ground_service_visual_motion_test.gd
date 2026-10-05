# Ground-service visual QA: presentation-only changes must not alter service logic.
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ordered_services := [
		"passenger",
		"fuel",
		"catering",
		"cleaning",
		"cargo",
		"pushback"
	]
	var widths: Dictionary = {}

	for service_type_variant in ordered_services:
		var service_type := String(service_type_variant)
		var profile := GroundServiceVehicleArt.visual_profile(
			service_type
		)
		var size: Vector2 = profile.get(
			"world_size",
			Vector2.ZERO
		)
		var radius := float(
			profile.get("shadow_radius", 0.0)
		)
		var aspect := float(
			profile.get("shadow_aspect", 0.0)
		)
		var bob := float(
			profile.get("motion_bob", 0.0)
		)

		if size.x <= 0.0 or size.y <= 0.0:
			_fail("%s should have a valid tuned world size." % service_type)
			return
		if radius < 13.0 or radius > 19.0:
			_fail("%s shadow radius should stay within the approved service range." % service_type)
			return
		if aspect < 0.28 or aspect > 0.50:
			_fail("%s should have a valid service-specific shadow aspect." % service_type)
			return
		if bob <= 0.0 or bob > 1.0:
			_fail("%s should have subtle but non-zero suspension motion." % service_type)
			return

		widths[service_type] = size.x

	if not (
		float(widths["passenger"]) > float(widths["fuel"])
		and float(widths["fuel"]) == float(widths["catering"])
		and float(widths["catering"]) > float(widths["cleaning"])
		and float(widths["cleaning"]) > float(widths["cargo"])
		and float(widths["cargo"]) > float(widths["pushback"])
	):
		_fail("Service vehicle world sizes should read bus > trucks > tugs.")
		return

	if (
		GroundServiceVehicleArt.shadow_aspect("pushback")
		<= GroundServiceVehicleArt.shadow_aspect("passenger")
	):
		_fail("Compact pushback tug should use a squarer shadow than the passenger bus.")
		return

	var straight_se_lean := GroundServiceVehicleArt.turn_lean(
		GroundServiceVehicleArt.ISO_HEADING_ANGLE
	)
	if absf(straight_se_lean) > 0.001:
		_fail("Exact SE isometric heading should not lean the service sprite.")
		return
	var turning_lean := GroundServiceVehicleArt.turn_lean(
		GroundServiceVehicleArt.ISO_HEADING_ANGLE + 0.22
	)
	if absf(turning_lean) <= 0.01:
		_fail("Intermediate service heading should expose subtle visual turn lean.")
		return
	if absf(turning_lean) > GroundServiceVehicleArt.MAX_TURN_LEAN + 0.001:
		_fail("Service turn lean should remain tightly capped.")
		return

	var cargo := GroundServiceVehiclePrototype.new()
	root.add_child(cargo)
	await process_frame
	cargo.drive_speed = 100.0
	cargo.start_service(
		PackedVector2Array([
			Vector2(0, 0),
			Vector2(10, 0),
			Vector2(10, 100)
		]),
		4.0,
		"cargo"
	)

	cargo._process(0.20)
	if cargo.phase != "OUTBOUND" or cargo.route_index != 1:
		_fail("Cargo tug should reach the first route corner while remaining outbound.")
		return
	if cargo.visual_motion_amount <= 0.0:
		_fail("Moving service vehicle should ramp into visual suspension motion.")
		return

	var before_turn := cargo.rotation
	cargo._process(0.05)
	var after_turn := cargo.rotation
	if after_turn <= before_turn:
		_fail("Service vehicle heading should begin turning toward the next apron segment.")
		return
	if after_turn >= PI * 0.5 - 0.01:
		_fail("Service vehicle heading should turn smoothly instead of snapping 90 degrees.")
		return

	var bob_limit := GroundServiceVehicleArt.motion_bob_amplitude("cargo")
	if absf(cargo._motion_bob_y()) > bob_limit + 0.01:
		_fail("Cargo suspension bob should stay within its tuned amplitude.")
		return
	if not cargo.has_method("_draw_service_beacon"):
		_fail("General service vehicles should retain their animated amber beacon.")
		return

	var fuel := FuelTruckPrototype.new()
	root.add_child(fuel)
	await process_frame
	fuel.drive_speed = 100.0
	fuel.start_service(
		PackedVector2Array([
			Vector2(0, 0),
			Vector2(10, 0),
			Vector2(10, -100)
		]),
		4.0
	)
	fuel._process(0.20)
	var fuel_before_turn := fuel.rotation
	fuel._process(0.05)
	if fuel.rotation >= fuel_before_turn:
		_fail("Fuel truck should smoothly turn toward a negative apron segment.")
		return
	if fuel.rotation <= -PI * 0.5 + 0.01:
		_fail("Fuel truck should not snap instantly to the next route heading.")
		return
	if fuel.visual_motion_amount <= 0.0:
		_fail("Fuel truck should use the same moving suspension presentation.")
		return
	if not fuel.has_method("_draw_service_beacon"):
		_fail("Fuel truck should retain its animated amber beacon.")
		return

	var atlas := GroundServiceVehicleArt.texture()
	if atlas == null:
		_fail("Ground-service production atlas should load.")
		return
	for service_type_variant in [
		"fuel",
		"passenger",
		"cargo",
		"cleaning",
		"catering",
		"pushback"
	]:
		var service_type := String(service_type_variant)
		for heading in [
			-PI * 0.25,
			PI * 0.25,
			PI * 0.75,
			-PI * 0.75
		]:
			var source := GroundServiceVehicleArt.source_rect(
				service_type,
				heading
			)
			if source.size != Vector2(256, 256):
				_fail("%s should retain full 256x256 directional atlas cells." % service_type)
				return

	print(
		(
			"GROUND_SERVICE_VISUAL_MOTION_OK "
			+ "bus=%.0f fuel=%.0f cleaning=%.0f cargo=%.0f tug=%.0f "
			+ "smooth_turn=true turn_lean=true beacon=true"
		) % [
			float(widths["passenger"]),
			float(widths["fuel"]),
			float(widths["cleaning"]),
			float(widths["cargo"]),
			float(widths["pushback"])
		]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
