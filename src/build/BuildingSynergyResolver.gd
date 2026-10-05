class_name BuildingSynergyResolver
extends RefCounted


static func passenger_for_building(
	grid: AirportGrid,
	building_uid: int
) -> Dictionary:
	if grid == null:
		return {}
	var building := grid.get_building(building_uid)
	if building.is_empty():
		return {}
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return {}
	return passenger_at(
		grid,
		definition,
		_center_tile(building, definition),
		building_uid
	)


static func passenger_at(
	grid: AirportGrid,
	receiver_definition: Dictionary,
	receiver_center_tile: Vector2,
	ignore_uid: int = -1
) -> Dictionary:
	var best_multiplier := 1.0
	var best_uid := -1
	var best_distance := INF
	var best_name := "Terminal"
	var best_radius := BuildingSynergyRules.DEFAULT_PASSENGER_RADIUS_TILES

	for provider in grid.placed_buildings:
		var provider_uid := int(provider.get("uid", -1))
		if provider_uid == ignore_uid:
			continue
		var provider_definition := BuildingCatalog.get_definition(
			String(provider.get("definition_id", ""))
		)
		if String(
			provider_definition.get("synergy_provider", "")
		) != "passenger_hub":
			continue
		var distance := receiver_center_tile.distance_to(
			_center_tile(provider, provider_definition)
		)
		var multiplier := BuildingSynergyRules.passenger_multiplier(
			receiver_definition,
			provider_definition,
			distance
		)
		if (
			multiplier > best_multiplier + 0.0001
			or (
				absf(multiplier - best_multiplier) <= 0.0001
				and multiplier > 1.0
				and distance < best_distance
			)
		):
			best_multiplier = multiplier
			best_uid = provider_uid
			best_distance = distance
			best_name = String(
				provider_definition.get("name", "Terminal")
			)
			best_radius = BuildingSynergyRules.passenger_radius(
				provider_definition
			)

	var active := best_multiplier > 1.0001
	return {
		"active": active,
		"kind": "passenger",
		"multiplier": best_multiplier,
		"bonus_pct": BuildingSynergyRules.bonus_percent(
			best_multiplier
		),
		"target_uid": best_uid,
		"target_uids": [best_uid] if best_uid >= 0 else [],
		"target_name": best_name,
		"distance_tiles": 0.0 if best_distance == INF else best_distance,
		"radius_tiles": best_radius,
		"preview_text": BuildingSynergyRules.passenger_preview_text(
			best_multiplier,
			best_name
		)
	}


static func service_for(
	grid: AirportGrid,
	station_uid: int,
	stand_uid: int
) -> Dictionary:
	if grid == null:
		return {}
	var station := grid.get_building(station_uid)
	var stand := grid.get_building(stand_uid)
	if station.is_empty() or stand.is_empty():
		return {}

	var station_definition := BuildingCatalog.get_definition(
		String(station.get("definition_id", ""))
	)
	var stand_definition := BuildingCatalog.get_definition(
		String(stand.get("definition_id", ""))
	)
	if (
		station_definition.is_empty()
		or stand_definition.is_empty()
		or not _definitions_share_aircraft_size(
			station_definition,
			stand_definition
		)
	):
		return {
			"active": false,
			"kind": "service",
			"multiplier": 1.0,
			"bonus_pct": 0,
			"target_uids": []
		}

	var distance := _center_tile(
		station,
		station_definition
	).distance_to(
		_center_tile(stand, stand_definition)
	)
	var multiplier := BuildingSynergyRules.service_multiplier(
		station_definition,
		distance
	)
	return {
		"active": multiplier > 1.0001,
		"kind": "service",
		"multiplier": multiplier,
		"bonus_pct": BuildingSynergyRules.bonus_percent(multiplier),
		"distance_tiles": distance,
		"radius_tiles": BuildingSynergyRules.service_radius(
			station_definition
		),
		"target_uid": stand_uid,
		"target_uids": [stand_uid],
		"target_name": String(
			stand_definition.get("name", "Stand")
		)
	}


static func service_coverage(
	grid: AirportGrid,
	station_uid: int
) -> Dictionary:
	if grid == null:
		return {}
	var station := grid.get_building(station_uid)
	if station.is_empty():
		return {}
	var definition := BuildingCatalog.get_definition(
		String(station.get("definition_id", ""))
	)
	if definition.is_empty():
		return {}
	return service_coverage_at(
		grid,
		definition,
		_center_tile(station, definition),
		station_uid
	)


static func building_summary(
	grid: AirportGrid,
	building_uid: int
) -> Dictionary:
	if grid == null:
		return {}
	var building := grid.get_building(building_uid)
	if building.is_empty():
		return {}
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if definition.is_empty():
		return {}

	if String(
		definition.get("synergy_receiver", "")
	) == "passenger_hub":
		return passenger_for_building(grid, building_uid)

	if String(
		definition.get("synergy_provider", "")
	) == "passenger_hub":
		return passenger_provider_coverage(
			grid,
			building_uid
		)

	if float(
		definition.get("local_service_bonus", 0.0)
	) > 0.0:
		return service_coverage(grid, building_uid)

	if String(
		definition.get("id", "")
	).contains("stand"):
		return stand_service_summary(
			grid,
			building_uid
		)

	return {}


static func preview_summary(
	grid: AirportGrid,
	building_id: String,
	origin: Vector2i,
	rotation: int,
	ignore_uid: int = -1
) -> Dictionary:
	if grid == null:
		return {}
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty() or origin.x < 0 or origin.y < 0:
		return {}

	var center_tile := _center_tile_at(
		definition,
		origin,
		rotation
	)

	if String(
		definition.get("synergy_receiver", "")
	) == "passenger_hub":
		return passenger_at(
			grid,
			definition,
			center_tile,
			ignore_uid
		)

	if String(
		definition.get("synergy_provider", "")
	) == "passenger_hub":
		return passenger_provider_coverage_at(
			grid,
			definition,
			center_tile,
			ignore_uid
		)

	if float(
		definition.get("local_service_bonus", 0.0)
	) > 0.0:
		return service_coverage_at(
			grid,
			definition,
			center_tile,
			ignore_uid
		)

	if building_id.contains("stand"):
		return stand_service_at(
			grid,
			definition,
			center_tile,
			ignore_uid
		)

	return {}


static func passenger_provider_coverage(
	grid: AirportGrid,
	provider_uid: int
) -> Dictionary:
	var provider := grid.get_building(provider_uid)
	if provider.is_empty():
		return {}
	var definition := BuildingCatalog.get_definition(
		String(provider.get("definition_id", ""))
	)
	if definition.is_empty():
		return {}
	return passenger_provider_coverage_at(
		grid,
		definition,
		_center_tile(provider, definition),
		provider_uid
	)


static func passenger_provider_coverage_at(
	grid: AirportGrid,
	provider_definition: Dictionary,
	provider_center_tile: Vector2,
	ignore_uid: int = -1
) -> Dictionary:
	var targets: Array[int] = []
	var max_bonus := 0

	for building in grid.placed_buildings:
		var uid := int(building.get("uid", -1))
		if uid == ignore_uid:
			continue
		var definition := BuildingCatalog.get_definition(
			String(building.get("definition_id", ""))
		)
		if String(
			definition.get("synergy_receiver", "")
		) != "passenger_hub":
			continue

		var distance := provider_center_tile.distance_to(
			_center_tile(building, definition)
		)
		var multiplier := BuildingSynergyRules.passenger_multiplier(
			definition,
			provider_definition,
			distance
		)
		if multiplier <= 1.0001:
			continue
		targets.append(uid)
		max_bonus = maxi(
			max_bonus,
			BuildingSynergyRules.bonus_percent(multiplier)
		)

	var text := "No passenger buildings in synergy range"
	if not targets.is_empty():
		text = "Boosts %d passenger building%s nearby" % [
			targets.size(),
			"" if targets.size() == 1 else "s"
		]

	return {
		"active": not targets.is_empty(),
		"kind": "passenger",
		"covered_count": targets.size(),
		"bonus_pct": max_bonus,
		"target_uids": targets,
		"radius_tiles": BuildingSynergyRules.passenger_radius(
			provider_definition
		),
		"preview_text": text
	}


static func service_coverage_at(
	grid: AirportGrid,
	station_definition: Dictionary,
	station_center_tile: Vector2,
	ignore_uid: int = -1
) -> Dictionary:
	var targets: Array[int] = []
	var bonus_multiplier := 1.0 + clampf(
		float(
			station_definition.get(
				"local_service_bonus",
				0.0
			)
		),
		0.0,
		0.30
	)
	var radius := BuildingSynergyRules.service_radius(
		station_definition
	)

	for stand in grid.placed_buildings:
		var stand_uid := int(stand.get("uid", -1))
		if stand_uid == ignore_uid:
			continue
		var stand_definition := BuildingCatalog.get_definition(
			String(stand.get("definition_id", ""))
		)
		if not String(
			stand_definition.get("id", "")
		).contains("stand"):
			continue
		if not _definitions_share_aircraft_size(
			station_definition,
			stand_definition
		):
			continue

		var distance := station_center_tile.distance_to(
			_center_tile(stand, stand_definition)
		)
		if distance <= radius + 0.001:
			targets.append(stand_uid)

	return {
		"active": not targets.is_empty(),
		"kind": "service",
		"covered_count": targets.size(),
		"multiplier": bonus_multiplier,
		"bonus_pct": BuildingSynergyRules.bonus_percent(
			bonus_multiplier
		),
		"target_uids": targets,
		"radius_tiles": radius,
		"preview_text": BuildingSynergyRules.service_preview_text(
			bonus_multiplier,
			targets.size()
		)
	}


static func stand_service_summary(
	grid: AirportGrid,
	stand_uid: int
) -> Dictionary:
	var stand := grid.get_building(stand_uid)
	if stand.is_empty():
		return {}
	var definition := BuildingCatalog.get_definition(
		String(stand.get("definition_id", ""))
	)
	if definition.is_empty():
		return {}
	return stand_service_at(
		grid,
		definition,
		_center_tile(stand, definition),
		stand_uid
	)


static func stand_service_at(
	grid: AirportGrid,
	stand_definition: Dictionary,
	stand_center_tile: Vector2,
	ignore_uid: int = -1
) -> Dictionary:
	var targets: Array[int] = []
	var max_bonus := 0

	for station in grid.placed_buildings:
		var uid := int(station.get("uid", -1))
		if uid == ignore_uid:
			continue
		var definition := BuildingCatalog.get_definition(
			String(station.get("definition_id", ""))
		)
		if float(
			definition.get("local_service_bonus", 0.0)
		) <= 0.0:
			continue
		if not _definitions_share_aircraft_size(
			definition,
			stand_definition
		):
			continue

		var distance := stand_center_tile.distance_to(
			_center_tile(station, definition)
		)
		var multiplier := BuildingSynergyRules.service_multiplier(
			definition,
			distance
		)
		if multiplier <= 1.0001:
			continue

		targets.append(uid)
		max_bonus = maxi(
			max_bonus,
			BuildingSynergyRules.bonus_percent(multiplier)
		)

	var text := "No nearby local service bonus"
	if not targets.is_empty():
		text = "%d nearby service facilit%s" % [
			targets.size(),
			"y" if targets.size() == 1 else "ies"
		]

	return {
		"active": not targets.is_empty(),
		"kind": "service",
		"covered_count": targets.size(),
		"bonus_pct": max_bonus,
		"target_uids": targets,
		"preview_text": text
	}


static func _center_tile(
	building: Dictionary,
	definition: Dictionary
) -> Vector2:
	return _center_tile_at(
		definition,
		building.get("origin", Vector2i.ZERO),
		int(building.get("rotation", 0))
	)


static func _center_tile_at(
	definition: Dictionary,
	origin: Vector2i,
	rotation: int
) -> Vector2:
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if (
		bool(definition.get("rotatable", false))
		and rotation % 2 == 1
	):
		footprint = Vector2i(
			footprint.y,
			footprint.x
		)
	return Vector2(
		float(origin.x) + float(footprint.x - 1) * 0.5,
		float(origin.y) + float(footprint.y - 1) * 0.5
	)


static func _definitions_share_aircraft_size(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_sizes: PackedStringArray = a.get(
		"sizes",
		PackedStringArray()
	)
	var b_sizes: PackedStringArray = b.get(
		"sizes",
		PackedStringArray()
	)
	if a_sizes.is_empty() or b_sizes.is_empty():
		return true
	for size in a_sizes:
		if b_sizes.has(size):
			return true
	return false
