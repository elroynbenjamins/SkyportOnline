extends SceneTree

var errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	var snapshot := grid.get_airfield_detail_snapshot()

	if int(snapshot.get("runways", 0)) != 1:
		_fail("Starter airport should retain one runway.")
	if int(snapshot.get("taxiway_tiles", 0)) != 3:
		_fail("Starter airport should retain three taxiway tiles.")
	if int(snapshot.get("service_road_tiles", 0)) != 10:
		_fail("Starter airport should retain ten service-road tiles.")
	if int(snapshot.get("taxiway_open_edges", 0)) <= 0:
		_fail("Taxiway detail pass should have open grass-facing edges to style.")
	if int(snapshot.get("service_road_open_edges", 0)) <= 0:
		_fail("Service-road detail pass should have open grass-facing edges to style.")
	if int(snapshot.get("service_barrier_candidates", 0)) <= 0:
		_fail("Starter service road should expose at least one safety-barrier candidate.")
	if int(snapshot.get("landside_scenery", 0)) < 9:
		_fail("Perimeter pass should include the extended landside/distant scenery set.")

	for path in [
		"res://assets/pixel/airport_v1/environment_conifer_cluster.svg",
		"res://assets/pixel/airport_v1/environment_distant_fields.svg"
	]:
		if not ResourceLoader.exists(path):
			_fail("Missing perimeter scenery asset: %s" % path)
			continue
		var resource = load(path)
		if not (resource is Texture2D):
			_fail("Perimeter scenery should load as Texture2D: %s" % path)

	var before := grid.export_airport_layout()
	var after := grid.export_airport_layout()
	if before != after:
		_fail("Airfield visual details must never mutate the airport layout.")

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return

	print(
		"AIRFIELD_PERIMETER_DETAIL_OK runways=%d taxi_open=%d service_open=%d barriers=%d scenery=%d"
		% [
			int(snapshot.get("runways", 0)),
			int(snapshot.get("taxiway_open_edges", 0)),
			int(snapshot.get("service_road_open_edges", 0)),
			int(snapshot.get("service_barrier_candidates", 0)),
			int(snapshot.get("landside_scenery", 0))
		]
	)
	quit(0)


func _fail(message: String) -> void:
	errors.append(message)
