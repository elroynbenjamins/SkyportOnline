extends SceneTree


const EXPECTED := {
	"pico_p8": {
		"approach": 205.0,
		"landing": 148.0,
		"takeoff": 242.0,
		"spawn": 520.0,
		"climb": 540.0,
		"lift": 74.0
	},
	"swift_s14": {
		"approach": 218.0,
		"landing": 152.0,
		"takeoff": 252.0,
		"spawn": 545.0,
		"climb": 565.0,
		"lift": 76.0
	},
	"comet_c22": {
		"approach": 204.0,
		"landing": 147.0,
		"takeoff": 244.0,
		"spawn": 560.0,
		"climb": 585.0,
		"lift": 78.0
	},
	"voyager_v32": {
		"approach": 198.0,
		"landing": 144.0,
		"takeoff": 237.0,
		"spawn": 585.0,
		"climb": 610.0,
		"lift": 81.0
	}
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := PackedVector2Array([
		Vector2(100, 100),
		Vector2(280, 100),
		Vector2(340, 160),
		Vector2(400, 210)
	])

	for type_id_variant in EXPECTED.keys():
		var type_id := String(type_id_variant)
		var expected: Dictionary = EXPECTED[type_id_variant]
		var plane := CareerAircraft.new()
		root.add_child(plane)
		await process_frame
		plane.set_process(false)
		plane.configure_aircraft_type(type_id)
		plane.configure_handling_mode(true, false)
		plane.set_arrival_route(route, 1, 2)

		var snapshot := plane.get_flight_presentation_snapshot()
		if plane.aircraft_size != "S":
			_fail("%s should remain an S-class aircraft." % type_id)
			return
		if not is_equal_approx(
			float(snapshot.get("approach_speed", 0.0)),
			float(expected.get("approach", 0.0))
		):
			_fail("%s approach speed should use its tuned S-class profile." % type_id)
			return
		if not is_equal_approx(
			float(snapshot.get("landing_speed", 0.0)),
			float(expected.get("landing", 0.0))
		):
			_fail("%s landing speed should use its tuned S-class profile." % type_id)
			return
		if not is_equal_approx(
			float(snapshot.get("takeoff_speed", 0.0)),
			float(expected.get("takeoff", 0.0))
		):
			_fail("%s takeoff speed should use its tuned S-class profile." % type_id)
			return
		if not is_equal_approx(
			float(snapshot.get("approach_spawn_distance", 0.0)),
			float(expected.get("spawn", 0.0))
		):
			_fail("%s should use its tuned visible approach distance." % type_id)
			return
		if not is_equal_approx(
			float(snapshot.get("climb_out_distance", 0.0)),
			float(expected.get("climb", 0.0))
		):
			_fail("%s should use its tuned visible climb-out distance." % type_id)
			return

		if not plane.stage_for_manual_arrival():
			_fail("%s should use the manual LAND gate." % type_id)
			return
		if plane.get_handling_action() != "LAND":
			_fail("%s should expose LAND before entering approach." % type_id)
			return
		if not plane.visible:
			_fail("%s should be visible outside the airport before LAND." % type_id)
			return
		if plane.get_airborne_visual_lift() < float(expected.get("lift", 0.0)) * 0.95:
			_fail("%s should visibly read as airborne at the LAND gate." % type_id)
			return
		if String(
			plane.get_handling_action_snapshot().get(
				"automation_scope",
				""
			)
		) != "S":
			_fail("%s should remain in the S automation entitlement scope." % type_id)
			return

		var initial_distance := plane.position.distance_to(route[0])
		plane.clear_handling_action()
		plane.begin_arrival_after_clearance()
		plane._process(0.40)
		if plane.position.distance_to(route[0]) >= initial_distance:
			_fail("%s should advance visibly toward the runway on approach." % type_id)
			return
		plane.queue_free()

	var swift := AircraftCatalog.get_profile("swift_s14")
	var voyager := AircraftCatalog.get_profile("voyager_v32")
	if float(swift.get("approach_speed", 0.0)) <= float(voyager.get("approach_speed", 0.0)):
		_fail("Swift should preserve its fast short-route character on approach.")
		return
	if float(voyager.get("approach_spawn_distance", 0.0)) <= float(swift.get("approach_spawn_distance", 0.0)):
		_fail("Voyager should enter from farther out than the fast Swift.")
		return
	if float(voyager.get("climb_out_distance", 0.0)) <= float(swift.get("climb_out_distance", 0.0)):
		_fail("Voyager should retain a longer visible climb-out.")
		return

	print(
		"S_CLASS_FLIGHT_PRESENTATION_OK pico=true swift=true comet=true voyager=true "
		+ "manual_handling=true distinct_profiles=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
