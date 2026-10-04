extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := [
		{
			"id": "bus_stop",
			"sprite": "res://assets/pixel/passenger_v1/bus_stop.svg",
			"rate": 0.8,
			"storage": 20
		},
		{
			"id": "small_hotel",
			"sprite": "res://assets/pixel/passenger_v1/small_hotel.svg",
			"rate": 1.4,
			"storage": 45
		},
		{
			"id": "residential_district",
			"sprite": "res://assets/pixel/passenger_v1/residential_district.svg",
			"rate": 0.9,
			"storage": 90
		},
		{
			"id": "shuttle_station",
			"sprite": "res://assets/pixel/passenger_v1/shuttle_station.svg",
			"rate": 2.8,
			"storage": 30
		},
		{
			"id": "train_station",
			"sprite": "res://assets/pixel/passenger_v1/train_station.svg",
			"rate": 3.2,
			"storage": 120
		}
	]

	for item in expected:
		var building_id := String(item["id"])
		var definition := BuildingCatalog.get_definition(building_id)
		if definition.is_empty():
			_fail("Missing passenger building: %s" % building_id)
			return
		if not bool(definition.get("passenger_generator", false)):
			_fail("%s must be a passenger generator." % building_id)
			return
		if bool(definition.get("rotatable", true)):
			_fail("%s should use one fixed isometric orientation." % building_id)
			return

		var sprite_path := String(
			definition.get("world_sprite_path", "")
		)
		if sprite_path != String(item["sprite"]):
			_fail("%s sprite path mismatch." % building_id)
			return
		if not ResourceLoader.exists(sprite_path):
			_fail("Missing passenger building sprite: %s" % sprite_path)
			return
		var texture = load(sprite_path)
		if not (texture is Texture2D):
			_fail("Passenger building sprite is not a Texture2D: %s" % sprite_path)
			return

		var stats := PassengerUpgradeCatalog.passenger_stats(
			building_id,
			1
		)
		if absf(
			float(stats.get("passengers_per_minute", 0.0))
			- float(item["rate"])
		) > 0.001:
			_fail("%s base passenger production mismatch." % building_id)
			return
		if int(stats.get("storage", 0)) != int(item["storage"]):
			_fail("%s base passenger storage mismatch." % building_id)
			return

		var levels := PassengerUpgradeCatalog.get_levels(building_id)
		if levels.size() < 3 and building_id != "shuttle_station":
			_fail("%s should have at least three internal upgrade levels." % building_id)
			return

		for level in levels:
			var resource_cost: Dictionary = level.get("resource_cost", {})
			for resource_id in resource_cost.keys():
				if CountryResourceCatalog.get_resource(
					String(resource_id)
				).is_empty():
					_fail(
						"%s upgrade references unknown resource %s."
						% [building_id, String(resource_id)]
					)
					return

	print(
		"Passenger building visuals passed: 5 pixel-art buildings, "
		+ "production/storage stats, and regional-resource upgrades."
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
