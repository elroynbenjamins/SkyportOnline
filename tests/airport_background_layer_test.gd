extends SceneTree

const BACKDROP_SCRIPT := preload("res://src/world/AirportBackdrop.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var backdrop = BACKDROP_SCRIPT.new()
	root.add_child(backdrop)
	await process_frame

	if backdrop.z_index >= 0:
		_fail("Airport background must render behind the gameplay grid.")
		return

	var snapshot: Dictionary = backdrop.get_visual_snapshot()
	if not bool(snapshot.get("production_environment_v2", false)):
		_fail("Airport background should use production environment-v2 assets.")
		return
	if not bool(snapshot.get("independent_from_airport_grid", false)):
		_fail("Background must remain independent from AirportGrid placement logic.")
		return
	if int(snapshot.get("airport_land_points", 0)) != 4:
		_fail("Airport background should expose one continuous four-point landmass.")
		return
	if int(snapshot.get("field_groups", 0)) < 4:
		_fail("Background should contain multiple authored distant-field groups.")
		return
	if int(snapshot.get("tree_groups", 0)) < 6:
		_fail("Background should contain a substantial tree-belt layer.")
		return
	if int(snapshot.get("road_sections", 0)) < 2:
		_fail("Background should contain the distant access-road network.")
		return

	for path in [
		"res://assets/production/environment_v2/distant_fields_v2.svg",
		"res://assets/production/environment_v2/tree_cluster_v2.svg",
		"res://assets/production/environment_v2/conifer_cluster_v2.svg",
		"res://assets/production/environment_v2/parking_lot_v2.svg",
		"res://assets/production/environment_v2/hedge_strip_v2.svg",
		"res://assets/production/environment_v2/entrance_sign_v2.svg"
	]:
		if not ResourceLoader.exists(path):
			_fail("Missing production background asset: %s" % path)
			return

	var scene_file := FileAccess.open(
		"res://src/main/Main.tscn",
		FileAccess.READ
	)
	if scene_file == null:
		_fail("Main scene should remain readable.")
		return
	var scene_text := scene_file.get_as_text()
	if not scene_text.contains("AirportBackdrop"):
		_fail("Main scene should include the AirportBackdrop node.")
		return
	var backdrop_node := scene_text.find(
		"[node name=\"AirportBackdrop\""
	)
	var grid_node := scene_text.find(
		"[node name=\"AirportGrid\""
	)
	if backdrop_node < 0 or grid_node < 0 or backdrop_node > grid_node:
		_fail("AirportBackdrop node should be declared before AirportGrid.")
		return
	if not scene_text.contains("zoom = Vector2(0.84, 0.84)"):
		_fail("Opening camera should be wide enough to reveal the background.")
		return

	print(
		"AIRPORT_BACKGROUND_OK environment_v2=true fields=4 trees=6 "
		+ "roads=2 independent_layer=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
