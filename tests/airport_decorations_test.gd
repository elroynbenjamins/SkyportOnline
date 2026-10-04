extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := [
		{
			"id": "apron_light",
			"paths": [
				"res://assets/pixel/decor_v1/apron_light.svg"
			]
		},
		{
			"id": "taxiway_sign",
			"paths": [
				"res://assets/pixel/decor_v1/taxiway_sign.svg",
				"res://assets/pixel/decor_v1/taxiway_sign_b.svg"
			]
		},
		{
			"id": "perimeter_fence",
			"paths": [
				"res://assets/pixel/decor_v1/perimeter_fence.svg",
				"res://assets/pixel/decor_v1/perimeter_fence_b.svg"
			]
		},
		{
			"id": "tree_planter",
			"paths": [
				"res://assets/pixel/decor_v1/tree_planter.svg"
			]
		},
		{
			"id": "airport_bench",
			"paths": [
				"res://assets/pixel/decor_v1/airport_bench.svg"
			]
		},
		{
			"id": "service_props",
			"paths": [
				"res://assets/pixel/decor_v1/service_props.svg",
				"res://assets/pixel/decor_v1/service_props_b.svg"
			]
		},
		{
			"id": "radar_mast",
			"paths": [
				"res://assets/pixel/decor_v1/radar_mast.svg"
			]
		}
	]

	var menu_ids: Array[String] = []
	for definition in BuildingCatalog.get_menu_definitions():
		menu_ids.append(String(definition.get("id", "")))

	for item in expected:
		var building_id := String(item["id"])
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("Missing decoration definition: %s" % building_id)
			return
		if String(definition.get("category", "")) != "Decorations":
			_fail("%s should be in the Decorations category." % building_id)
			return
		if not bool(definition.get("cosmetic_only", false)):
			_fail("%s must remain cosmetic-only." % building_id)
			return
		if not bool(definition.get("preserve_ground", false)):
			_fail("%s should preserve the surface underneath it." % building_id)
			return
		if not menu_ids.has(building_id):
			_fail("%s should appear in the normal build catalog." % building_id)
			return
		if bool(definition.get("passenger_generator", false)):
			_fail("%s must not produce passengers." % building_id)
			return
		if not String(definition.get("service", "")).is_empty():
			_fail("%s must not provide a ground service." % building_id)
			return
		var services: Dictionary = definition.get("services", {})
		if not services.is_empty():
			_fail("%s must not provide multi-service capacity." % building_id)
			return
		if bool(definition.get("air_traffic_control", false)):
			_fail("%s must not change ATC throughput." % building_id)
			return

		var footprint: Vector2i = definition.get(
			"footprint",
			Vector2i.ZERO
		)
		if footprint != Vector2i(1, 1):
			_fail("%s should stay a compact 1x1 prop." % building_id)
			return

		var actual_paths: Array[String] = []
		var single_path := String(
			definition.get("world_sprite_path", "")
		)
		if not single_path.is_empty():
			actual_paths.append(single_path)
		var variants: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		for path in variants:
			actual_paths.append(String(path))

		var expected_paths: Array = item["paths"]
		if actual_paths.size() != expected_paths.size():
			_fail("%s sprite variant count mismatch." % building_id)
			return

		for index in range(expected_paths.size()):
			var expected_path := String(expected_paths[index])
			if actual_paths[index] != expected_path:
				_fail("%s sprite path mismatch." % building_id)
				return
			if not ResourceLoader.exists(expected_path):
				_fail("Missing decoration sprite: %s" % expected_path)
				return
			var texture = load(expected_path)
			if not (texture is Texture2D):
				_fail(
					"Decoration sprite must import as Texture2D: %s"
					% expected_path
				)
				return

		if String(definition.get("icon_path", "")) != actual_paths[0]:
			_fail("%s build icon should match primary art." % building_id)
			return

		if int(definition.get("cost", -1)) < 0:
			_fail("%s should not have a negative build cost." % building_id)
			return

	print(
		"Airport decorations passed: 7 cosmetic props, 10 visual variants, "
		+ "ground preservation and build-tray visibility."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
