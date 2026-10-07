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

	if GroundServiceMotionRules.corner_radius("passenger") <= GroundServiceMotionRules.corner_radius("cargo"):
		_fail("Passenger bus should use a wider road corner than the cargo tug.")
		return
	if GroundServiceMotionRules.turn_rate_degrees("pushback") <= GroundServiceMotionRules.turn_rate_degrees("passenger"):
		_fail("Pushback tug should steer more tightly than the passenger bus.")
		return
	if GroundServiceMotionRules.braking_distance("fuel") <= GroundServiceMotionRules.braking_distance("cargo"):
		_fail("Fuel truck should begin braking earlier than the compact cargo tug.")
		return
	var early_distance := GroundServiceMotionRules.distance_progress_for_time(
		0.05,
		"cargo"
	)
	var middle_distance := GroundServiceMotionRules.distance_progress_for_time(
		0.50,
		"cargo"
	)
	var late_distance := GroundServiceMotionRules.distance_progress_for_time(
		0.95,
		"cargo"
	)
	if not (early_distance < 0.05 and middle_distance > 0.45 and late_distance > 0.95):
		_fail("Service motion easing should accelerate early and brake late.")
		return

	var raw_service_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(80, 0),
		Vector2(80, 80)
	])
	var refined_service_route := GroundServiceMotionRules.refined_route(
		raw_service_route,
		"cargo"
	)
	if refined_service_route.size() <= raw_service_route.size():
		_fail("Service-road corner should gain smoothing points.")
		return
	if (
		refined_service_route[0] != raw_service_route[0]
		or refined_service_route[
			refined_service_route.size() - 1
		] != raw_service_route[raw_service_route.size() - 1]
	):
		_fail("Service-route smoothing should preserve facility and docking endpoints.")
		return

	var cargo := GroundServiceVehiclePrototype.new()
	root.add_child(cargo)
	await process_frame
	cargo.drive_speed = 100.0
	cargo.set_service_pose_rotation(PI * 0.5)
	cargo.start_service(
		PackedVector2Array([
			Vector2(0, 0),
			Vector2(80, 0),
			Vector2(80, 80)
		]),
		0.5,
		"cargo"
	)

	cargo._process(0.10)
	var cargo_motion := cargo.get_motion_snapshot()
	var expected_travel_duration := (
		GroundServiceMotionRules.route_length(
			PackedVector2Array([
				Vector2(0, 0),
				Vector2(80, 0),
				Vector2(80, 80)
			])
		) / cargo.drive_speed
	)
	if absf(
		float(cargo_motion.get("travel_duration", 0.0))
		- expected_travel_duration
	) > 0.01:
		_fail("Visual easing must preserve the legacy service travel duration.")
		return
	if cargo.phase != "OUTBOUND":
		_fail("Cargo tug should begin in the outbound road-following phase.")
		return
	if float(cargo_motion.get("current_speed", 0.0)) <= 0.0:
		_fail("Cargo tug should accelerate progressively from rest.")
		return
	if not bool(cargo_motion.get("production_road_following", false)):
		_fail("Cargo tug should report production service-road following.")
		return
	if cargo.visual_motion_amount <= 0.0:
		_fail("Moving service vehicle should ramp into visual suspension motion.")
		return

	var saw_corner := false
	var saw_anticipation := false
	for _step in range(80):
		var before_rotation := cargo.rotation
		cargo._process(0.05)
		if cargo.route_index > 0:
			saw_corner = true
		if cargo.rotation > before_rotation + 0.001:
			saw_anticipation = true
		if cargo.phase == "SERVICING":
			break

	if not saw_corner:
		_fail("Cargo tug should advance through the service-road corner.")
		return
	if not saw_anticipation:
		_fail("Service vehicle nose should anticipate the next road segment.")
		return
	if cargo.phase != "SERVICING":
		_fail("Cargo tug should reach the aircraft docking point.")
		return
	if absf(cargo.rotation - PI * 0.5) > 0.01:
		_fail("Service vehicle should finish on its authored aircraft docking heading.")
		return
	if cargo.current_drive_speed > 0.01:
		_fail("Service vehicle should fully stop before service begins.")
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
			Vector2(80, 0),
			Vector2(80, -80)
		]),
		4.0
	)
	fuel._process(0.10)
	var fuel_motion := fuel.get_motion_snapshot()
	if float(fuel_motion.get("current_speed", 0.0)) <= 0.0:
		_fail("Fuel truck should accelerate progressively from rest.")
		return
	var fuel_turned := false
	for _step in range(50):
		var before_heading := fuel.rotation
		fuel._process(0.05)
		if fuel.rotation < before_heading - 0.001:
			fuel_turned = true
			break
	if not fuel_turned:
		_fail("Fuel truck should anticipate and smoothly enter its negative road turn.")
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

	if not GroundServiceVehicleArt.ATLAS_PATH.ends_with("ground_service_v2/skyport_ground_service_atlas_v2.svg"):
		_fail("Ground-service fleet should use the stylized v2 production atlas.")
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
			+ "road_following=true timing_stable=true acceleration=true braking=true smooth_turn=true turn_lean=true beacon=true"
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
