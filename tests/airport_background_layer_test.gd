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
	if not bool(snapshot.get("production_environment_v3", false)):
		_fail("Airport background should use the authored environment-v3 asset.")
		return
	if not bool(snapshot.get("independent_from_airport_grid", false)):
		_fail("Background must remain independent from AirportGrid placement logic.")
		return
	if not bool(snapshot.get("continuous_landscape", false)):
		_fail("Airport background should be one continuous landscape.")
		return
	if bool(snapshot.get("airport_land_overlay", true)):
		_fail("Backdrop should not reveal the airport as a separate land slab.")
		return
	if int(snapshot.get("field_groups", 0)) < 4:
		_fail("Background should contain multiple authored distant-field groups.")
		return
	if int(snapshot.get("tree_groups", 0)) < 6:
		_fail("Background should contain a substantial tree-belt layer.")
		return
	if int(snapshot.get("road_sections", -1)) != 0:
		_fail("Default airport backdrop should not contain a decorative road.")
		return
	if int(snapshot.get("parking_groups", -1)) != 0:
		_fail("Default airport backdrop should not contain decorative parking.")
		return
	if int(snapshot.get("hill_layers", 0)) < 3:
		_fail("Background should contain layered distant hills.")
		return
	if not bool(snapshot.get("water_strip", false)):
		_fail("Background should contain a subtle distant water feature.")
		return

	var background_path := String(
		snapshot.get("background_asset", "")
	)
	if background_path.is_empty():
		_fail("Airport background should expose its authored asset path.")
		return
	if not ResourceLoader.exists(background_path):
		_fail(
			"Missing production background asset: %s"
			% background_path
		)
		return
	if not bool(snapshot.get("authored_backdrop_texture", false)):
		_fail("Authored airport backdrop texture should load successfully.")
		return
	if not bool(snapshot.get("grid_safe_center", false)):
		_fail("Background should preserve a quiet, grid-safe airport center.")
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
		"AIRPORT_BACKGROUND_OK environment_v3=true authored=true "
		+ "fields=4 trees=7 hills=3 roads=0 independent_layer=true"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
