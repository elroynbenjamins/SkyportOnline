extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := [
		{
			"id": "ground_ops_depot",
			"paths": [
				"res://assets/pixel/services_v1/ground_ops_depot.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "cleaning_center",
			"paths": [
				"res://assets/pixel/services_v1/cleaning_center.svg",
				"res://assets/pixel/services_v1/cleaning_center_b.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "passenger_service_hub",
			"paths": [
				"res://assets/pixel/services_v1/passenger_service_hub.svg",
				"res://assets/pixel/services_v1/passenger_service_hub_b.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "baggage_depot",
			"paths": [
				"res://assets/pixel/services_v1/baggage_depot.svg",
				"res://assets/pixel/services_v1/baggage_depot_b.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "catering_kitchen",
			"paths": [
				"res://assets/pixel/services_v1/catering_kitchen.svg",
				"res://assets/pixel/services_v1/catering_kitchen_b.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "tow_operations",
			"paths": [
				"res://assets/pixel/services_v1/tow_operations.svg",
				"res://assets/pixel/services_v1/tow_operations_b.svg"
			],
			"service_upgrade": true
		},
		{
			"id": "atc_tower",
			"paths": [
				"res://assets/pixel/services_v1/atc_tower.svg",
				"res://assets/pixel/services_v1/atc_tower_b.svg"
			],
			"service_upgrade": false
		}
	]

	for item in expected:
		var building_id := String(item["id"])
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("Missing building definition: %s" % building_id)
			return

		var expected_paths: Array = item["paths"]
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
			actual_paths.append(path)

		if actual_paths.size() != expected_paths.size():
			_fail(
				"%s expected %d visual variants, got %d."
				% [
					building_id,
					expected_paths.size(),
					actual_paths.size()
				]
			)
			return

		for index in range(expected_paths.size()):
			var expected_path := String(expected_paths[index])
			if actual_paths[index] != expected_path:
				_fail("%s visual path mismatch." % building_id)
				return
			if not ResourceLoader.exists(expected_path):
				_fail("Missing service building sprite: %s" % expected_path)
				return
			var texture = load(expected_path)
			if not (texture is Texture2D):
				_fail(
					"Service building sprite must import as Texture2D: %s"
					% expected_path
				)
				return

		var icon_path := String(definition.get("icon_path", ""))
		if icon_path != actual_paths[0]:
			_fail(
				"%s build icon should use its primary world sprite."
				% building_id
			)
			return

		var sprite_size: Vector2 = definition.get(
			"world_sprite_size",
			Vector2.ZERO
		)
		if sprite_size.x <= 0.0 or sprite_size.y <= 0.0:
			_fail("%s needs a positive world sprite size." % building_id)
			return

		if bool(item["service_upgrade"]):
			if not ServiceUpgradeCatalog.is_upgradeable(building_id):
				_fail("%s should keep service upgrades." % building_id)
				return
			if ServiceUpgradeCatalog.max_level(building_id) < 4:
				_fail(
					"%s should retain four internal upgrade levels."
					% building_id
				)
				return
		else:
			if not AirTrafficUpgradeCatalog.is_upgradeable(building_id):
				_fail("ATC Tower should retain air-traffic upgrades.")
				return
			if AirTrafficUpgradeCatalog.max_level(building_id) < 4:
				_fail("ATC Tower should retain four upgrade levels.")
				return

	print(
		"Service building visuals passed: 7 facilities, 13 sprite variants, "
		+ "and internal upgrade paths remain intact."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
