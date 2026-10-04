extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := [
		{
			"id": "small_hangar",
			"paths": [
				"res://assets/pixel/facilities_v1/small_hangar.svg",
				"res://assets/pixel/facilities_v1/small_hangar_b.svg"
			],
			"upgradeable": false
		},
		{
			"id": "basic_fuel",
			"paths": [
				"res://assets/pixel/facilities_v1/basic_fuel.svg",
				"res://assets/pixel/facilities_v1/basic_fuel_b.svg"
			],
			"upgradeable": true
		},
		{
			"id": "rapid_small_fuel",
			"paths": [
				"res://assets/pixel/facilities_v1/rapid_small_fuel.svg",
				"res://assets/pixel/facilities_v1/rapid_small_fuel_b.svg"
			],
			"upgradeable": true
		},
		{
			"id": "regional_fuel",
			"paths": [
				"res://assets/pixel/facilities_v1/regional_fuel.svg",
				"res://assets/pixel/facilities_v1/regional_fuel_b.svg"
			],
			"upgradeable": true
		},
		{
			"id": "rapid_regional_fuel",
			"paths": [
				"res://assets/pixel/facilities_v1/rapid_regional_fuel.svg",
				"res://assets/pixel/facilities_v1/rapid_regional_fuel_b.svg"
			],
			"upgradeable": true
		}
	]

	for item in expected:
		var building_id := String(item["id"])
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("Missing facility definition: %s" % building_id)
			return

		var paths: PackedStringArray = definition.get(
			"world_sprite_paths",
			PackedStringArray()
		)
		var expected_paths: Array = item["paths"]
		if paths.size() != expected_paths.size():
			_fail("%s should have two isometric sprite variants." % building_id)
			return

		for index in range(expected_paths.size()):
			var expected_path := String(expected_paths[index])
			if String(paths[index]) != expected_path:
				_fail("%s visual path mismatch." % building_id)
				return
			if not ResourceLoader.exists(expected_path):
				_fail("Missing facility sprite: %s" % expected_path)
				return
			var texture = load(expected_path)
			if not (texture is Texture2D):
				_fail("Facility sprite must import as Texture2D: %s" % expected_path)
				return

		if String(definition.get("icon_path", "")) != String(paths[0]):
			_fail("%s build icon should use its primary world art." % building_id)
			return

		var size: Vector2 = definition.get("world_sprite_size", Vector2.ZERO)
		if size.x <= 0.0 or size.y <= 0.0:
			_fail("%s needs positive sprite dimensions." % building_id)
			return

		if bool(item["upgradeable"]):
			if not ServiceUpgradeCatalog.is_upgradeable(building_id):
				_fail("%s should retain service upgrades." % building_id)
				return
			if ServiceUpgradeCatalog.max_level(building_id) < 4:
				_fail("%s should retain four upgrade levels." % building_id)
				return
			var stats := ServiceUpgradeCatalog.effective_service_stats(
				building_id,
				"fuel",
				1
			)
			if stats.is_empty():
				_fail("%s must still provide fuel service." % building_id)
				return
			if float(stats.get("service_speed", 0.0)) <= 0.0:
				_fail("%s fuel speed must remain positive." % building_id)
				return
			if int(stats.get("vehicle_capacity", 0)) <= 0:
				_fail("%s vehicle capacity must remain positive." % building_id)
				return

	var hangar := BuildingCatalog.get_definition("small_hangar")
	if String(hangar.get("description", "")).is_empty():
		_fail("Small Hangar gameplay definition should remain intact.")
		return
	if not bool(hangar.get("rotatable", false)):
		_fail("Small Hangar should remain rotatable.")
		return

	print(
		"Facility visuals passed: closed hangar plus four fuel tiers, "
		+ "with service upgrade behavior preserved."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
