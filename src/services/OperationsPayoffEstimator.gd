class_name OperationsPayoffEstimator
extends RefCounted

const SERVICE_TYPES: Array[String] = [
	"fuel",
	"passenger",
	"cargo",
	"cleaning",
	"catering",
	"pushback"
]


static func estimate(
	snapshot: Dictionary,
	grid: AirportGrid,
	resource_inventory: Dictionary,
	player_level: int,
	coins: int
) -> Dictionary:
	var candidates: Array[Dictionary] = []

	if grid == null:
		return {
			"ranked": candidates,
			"best_value": {},
			"best_affordable": {}
		}

	_add_service_upgrades(
		candidates,
		snapshot,
		grid,
		resource_inventory,
		coins
	)
	_add_passenger_upgrades(
		candidates,
		snapshot,
		grid,
		resource_inventory,
		coins
	)
	_add_atc_candidate(
		candidates,
		snapshot,
		grid,
		resource_inventory,
		player_level,
		coins
	)
	_add_stand_candidate(
		candidates,
		snapshot,
		player_level,
		coins
	)
	_add_runway_candidates(
		candidates,
		snapshot,
		grid,
		player_level,
		coins
	)

	for index in range(candidates.size()):
		candidates[index] = _finalize_candidate(
			candidates[index],
			resource_inventory,
			coins
		)

	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_score := float(
				a.get("payoff_score", 0.0)
			)
			var b_score := float(
				b.get("payoff_score", 0.0)
			)
			if absf(a_score - b_score) > 0.001:
				return a_score > b_score
			return float(
				a.get(
					"estimated_delay_saved_seconds",
					0.0
				)
			) > float(
				b.get(
					"estimated_delay_saved_seconds",
					0.0
				)
			)
	)

	var best_value: Dictionary = {}
	if not candidates.is_empty():
		best_value = candidates[0].duplicate(true)

	var best_affordable: Dictionary = {}
	for candidate in candidates:
		if bool(candidate.get("affordable_now", false)):
			best_affordable = candidate.duplicate(true)
			break

	return {
		"ranked": candidates,
		"best_value": best_value,
		"best_affordable": best_affordable
	}


static func _add_service_upgrades(
	candidates: Array[Dictionary],
	snapshot: Dictionary,
	grid: AirportGrid,
	resource_inventory: Dictionary,
	coins: int
) -> void:
	var services: Dictionary = snapshot.get(
		"services",
		{}
	)
	var unique_buildings: Dictionary = {}

	for service_type in SERVICE_TYPES:
		for size_class in ["S", "M"]:
			for station in grid.get_compatible_service_buildings(
				service_type,
				size_class
			):
				var uid := int(station.get("uid", -1))
				if uid < 0:
					continue
				unique_buildings[uid] = station.duplicate(true)

	for station_variant in unique_buildings.values():
		var station: Dictionary = station_variant
		var uid := int(station.get("uid", -1))
		var building_id := String(
			station.get("definition_id", "")
		)
		var level := int(
			station.get("upgrade_level", 1)
		)
		if not ServiceUpgradeCatalog.is_upgradeable(
			building_id
		):
			continue

		var next := ServiceUpgradeCatalog.get_next_level(
			building_id,
			level
		)
		if next.is_empty():
			continue

		var estimated_saved := 0.0
		var affected: Array[String] = []
		var improvement_parts: Array[String] = []

		for service_type in ServiceUpgradeCatalog.service_types(
			building_id
		):
			var current_stats := (
				ServiceUpgradeCatalog.effective_service_stats(
					building_id,
					service_type,
					level
				)
			)
			var next_stats := (
				ServiceUpgradeCatalog.effective_service_stats(
					building_id,
					service_type,
					level + 1
				)
			)
			if current_stats.is_empty() or next_stats.is_empty():
				continue

			var current_throughput := (
				float(
					current_stats.get(
						"service_speed",
						1.0
					)
				)
				* float(
					current_stats.get(
						"vehicle_capacity",
						1
					)
				)
			)
			var next_throughput := (
				float(
					next_stats.get(
						"service_speed",
						1.0
					)
				)
				* float(
					next_stats.get(
						"vehicle_capacity",
						1
					)
				)
			)
			if next_throughput <= current_throughput + 0.001:
				continue

			var service_stats: Dictionary = services.get(
				service_type,
				{}
			)
			var average_wait := float(
				service_stats.get(
					"average_wait_seconds",
					0.0
				)
			)
			var current_waiting := int(
				service_stats.get(
					"current_waiting",
					0
				)
			)
			var utilization := float(
				service_stats.get(
					"utilization_pct",
					0.0
				)
			) / 100.0

			var wait_basis := maxf(
				average_wait,
				float(current_waiting) * 1.5
			)
			var improvement_fraction := clampf(
				1.0
				- current_throughput
				/ next_throughput,
				0.0,
				0.80
			)
			var pressure := clampf(
				0.35 + utilization * 0.65,
				0.35,
				1.0
			)
			estimated_saved += (
				wait_basis
				* improvement_fraction
				* pressure
			)
			affected.append(service_type)
			improvement_parts.append(
				"%s %.2f→%.2f" % [
					service_type.capitalize(),
					current_throughput,
					next_throughput
				]
			)

		if estimated_saved <= 0.01:
			continue

		var definition := BuildingCatalog.get_definition(
			building_id
		)
		candidates.append({
			"id": "service:%d" % uid,
			"kind": "service_upgrade",
			"building_uid": uid,
			"building_id": building_id,
			"title": "Upgrade %s to Lv %d" % [
				String(
					definition.get(
						"name",
						building_id
					)
				),
				level + 1
			],
			"affected": affected,
			"detail": " • ".join(improvement_parts),
			"coin_cost": int(
				next.get("coin_cost", 0)
			),
			"resource_cost": (
				next.get("resource_cost", {}) as Dictionary
			).duplicate(true),
			"estimated_delay_saved_seconds": estimated_saved
		})


static func _add_passenger_upgrades(
	candidates: Array[Dictionary],
	snapshot: Dictionary,
	grid: AirportGrid,
	resource_inventory: Dictionary,
	coins: int
) -> void:
	var passenger: Dictionary = snapshot.get(
		"passengers",
		{}
	)
	var shortfall := maxi(
		int(
			passenger.get(
				"waiting_shortfall",
				0
			)
		),
		0
	)
	var waiting_aircraft := maxi(
		int(
			passenger.get(
				"waiting_aircraft",
				0
			)
		),
		0
	)
	if shortfall <= 0 and waiting_aircraft <= 0:
		return

	var current_total_ppm := maxf(
		float(
			passenger.get(
				"production_per_minute",
				0.0
			)
		),
		0.0
	)

	for building in grid.get_passenger_generator_buildings():
		var building_id := String(
			building.get("definition_id", "")
		)
		var level := int(
			building.get("upgrade_level", 1)
		)
		var next := PassengerUpgradeCatalog.get_next_level(
			building_id,
			level
		)
		if next.is_empty():
			continue

		var current_stats := PassengerUpgradeCatalog.passenger_stats(
			building_id,
			level
		)
		var next_stats := PassengerUpgradeCatalog.passenger_stats(
			building_id,
			level + 1
		)
		var ppm_gain := maxf(
			float(
				next_stats.get(
					"passengers_per_minute",
					0.0
				)
			)
			- float(
				current_stats.get(
					"passengers_per_minute",
					0.0
				)
			),
			0.0
		)
		var storage_gain := maxi(
			int(next_stats.get("storage", 0))
			- int(current_stats.get("storage", 0)),
			0
		)
		var new_total_ppm := current_total_ppm + ppm_gain
		var saved := 0.0

		if shortfall > 0 and current_total_ppm > 0.001:
			var current_recovery := (
				float(shortfall)
				/ current_total_ppm
				* 60.0
			)
			var next_recovery := current_recovery
			if new_total_ppm > 0.001:
				next_recovery = (
					float(shortfall)
					/ new_total_ppm
					* 60.0
				)
			saved += maxf(
				current_recovery - next_recovery,
				0.0
			)

		if waiting_aircraft > 0 and storage_gain > 0:
			saved += minf(
				float(storage_gain) * 0.20,
				float(waiting_aircraft) * 4.0
			)

		if saved <= 0.01:
			continue

		var definition := BuildingCatalog.get_definition(
			building_id
		)
		candidates.append({
			"id": "passenger:%d" % int(
				building.get("uid", -1)
			),
			"kind": "passenger_upgrade",
			"building_uid": int(
				building.get("uid", -1)
			),
			"building_id": building_id,
			"title": "Upgrade %s to Lv %d" % [
				String(
					definition.get(
						"name",
						building_id
					)
				),
				level + 1
			],
			"affected": ["passenger_stock"],
			"detail": "+%.1f pax/min • +%d storage" % [
				ppm_gain,
				storage_gain
			],
			"coin_cost": int(
				next.get("coin_cost", 0)
			),
			"resource_cost": (
				next.get("resource_cost", {}) as Dictionary
			).duplicate(true),
			"estimated_delay_saved_seconds": saved
		})


static func _add_atc_candidate(
	candidates: Array[Dictionary],
	snapshot: Dictionary,
	grid: AirportGrid,
	resource_inventory: Dictionary,
	player_level: int,
	coins: int
) -> void:
	var runway: Dictionary = snapshot.get(
		"runway",
		{}
	)
	var average_wait := maxf(
		float(
			runway.get(
				"average_wait_seconds",
				0.0
			)
		),
		0.0
	)
	var separation_share := clampf(
		float(
			runway.get(
				"separation_delay_pct",
				0.0
			)
		) / 100.0,
		0.0,
		1.0
	)
	if average_wait <= 0.01 or separation_share <= 0.01:
		return

	var tower := grid.get_best_air_traffic_control()
	var current_multiplier := float(
		runway.get(
			"separation_multiplier",
			1.0
		)
	)
	var next_multiplier := current_multiplier
	var title := ""
	var coin_cost := 0
	var resource_cost: Dictionary = {}
	var building_uid := -1

	if tower.is_empty():
		var definition := BuildingCatalog.get_definition(
			"atc_tower"
		)
		if definition.is_empty():
			return
		if player_level < int(definition.get("level", 1)):
			return
		next_multiplier = AirTrafficUpgradeCatalog.separation_multiplier(
			"atc_tower",
			1
		)
		title = "Build Air Traffic Control Tower"
		coin_cost = int(definition.get("cost", 0))
	else:
		var level := int(
			tower.get("upgrade_level", 1)
		)
		var next := AirTrafficUpgradeCatalog.get_next_level(
			"atc_tower",
			level
		)
		if next.is_empty():
			return
		building_uid = int(tower.get("uid", -1))
		next_multiplier = float(
			next.get(
				"separation_multiplier",
				current_multiplier
			)
		)
		title = "Upgrade ATC Tower to Lv %d" % (
			level + 1
		)
		coin_cost = int(
			next.get("coin_cost", 0)
		)
		resource_cost = (
			next.get("resource_cost", {}) as Dictionary
		).duplicate(true)

	if next_multiplier >= current_multiplier - 0.001:
		return

	var separation_wait := average_wait * separation_share
	var reduction_fraction := clampf(
		1.0
		- next_multiplier / maxf(
			current_multiplier,
			0.001
		),
		0.0,
		0.80
	)
	var saved := separation_wait * reduction_fraction
	if saved <= 0.01:
		return

	candidates.append({
		"id": "atc",
		"kind": "atc",
		"building_uid": building_uid,
		"building_id": "atc_tower",
		"title": title,
		"affected": ["runway"],
		"detail": "Separation x%.2f → x%.2f" % [
			current_multiplier,
			next_multiplier
		],
		"coin_cost": coin_cost,
		"resource_cost": resource_cost,
		"estimated_delay_saved_seconds": saved
	})


static func _add_stand_candidate(
	candidates: Array[Dictionary],
	snapshot: Dictionary,
	player_level: int,
	coins: int
) -> void:
	var stands: Dictionary = snapshot.get(
		"stands",
		{}
	)
	var pending := maxi(
		int(
			stands.get(
				"pending_arrivals",
				0
			)
		),
		0
	)
	var max_hold := maxf(
		float(
			stands.get(
				"max_current_hold_seconds",
				0.0
			)
		),
		0.0
	)
	if pending <= 0 and max_hold <= 0.01:
		return

	var definition := BuildingCatalog.get_definition(
		"small_stand"
	)
	if definition.is_empty():
		return
	if player_level < int(definition.get("level", 1)):
		return

	var saved := maxf(
		max_hold,
		float(pending) * 6.0
	)
	candidates.append({
		"id": "build:small_stand",
		"kind": "stand",
		"building_id": "small_stand",
		"title": "Build Small Aircraft Stand",
		"affected": ["stands"],
		"detail": "Adds one S-aircraft parking/turnaround position",
		"coin_cost": int(definition.get("cost", 0)),
		"resource_cost": {},
		"estimated_delay_saved_seconds": saved
	})


static func _add_runway_candidates(
	candidates: Array[Dictionary],
	snapshot: Dictionary,
	grid: AirportGrid,
	player_level: int,
	coins: int
) -> void:
	var runway: Dictionary = snapshot.get(
		"runway",
		{}
	)
	var average_wait := maxf(
		float(
			runway.get(
				"average_wait_seconds",
				0.0
			)
		),
		0.0
	)
	var max_utilization := clampf(
		float(
			runway.get(
				"max_utilization_pct",
				0.0
			)
		) / 100.0,
		0.0,
		1.0
	)
	if average_wait <= 0.01 or max_utilization < 0.45:
		return

	var runway_count := maxi(
		grid.get_runway_buildings().size(),
		1
	)
	var base_saved := (
		average_wait
		* max_utilization
		/ float(runway_count + 1)
	)

	for building_id in ["short_runway", "regional_runway"]:
		var definition := BuildingCatalog.get_definition(
			building_id
		)
		if definition.is_empty():
			continue
		if player_level < int(definition.get("level", 1)):
			continue

		var coverage := (
			0.65
			if building_id == "short_runway"
			else 1.0
		)
		var saved := base_saved * coverage
		if saved <= 0.01:
			continue

		candidates.append({
			"id": "build:%s" % building_id,
			"kind": "runway",
			"building_id": building_id,
			"title": "Build %s" % String(
				definition.get(
					"name",
					building_id
				)
			),
			"affected": ["runway"],
			"detail": (
				"Estimated parallel runway relief; excludes parcel/taxiway cost"
			),
			"coin_cost": int(
				definition.get("cost", 0)
			),
			"resource_cost": {},
			"estimated_delay_saved_seconds": saved
		})


static func _finalize_candidate(
	candidate: Dictionary,
	resource_inventory: Dictionary,
	coins: int
) -> Dictionary:
	var result := candidate.duplicate(true)
	var coin_cost := maxi(
		int(result.get("coin_cost", 0)),
		0
	)
	var resource_cost: Dictionary = result.get(
		"resource_cost",
		{}
	)
	var resource_missing := 0
	var resource_required := 0
	var resource_owned_toward := 0
	var missing_resources: Array[Dictionary] = []

	for resource_id in resource_cost.keys():
		var needed := maxi(
			int(resource_cost[resource_id]),
			0
		)
		var owned := maxi(
			int(
				resource_inventory.get(
					resource_id,
					0
				)
			),
			0
		)
		resource_required += needed
		resource_owned_toward += mini(
			owned,
			needed
		)
		if owned < needed:
			resource_missing += needed - owned
			missing_resources.append({
				"id": String(resource_id),
				"needed": needed,
				"owned": owned,
				"missing": needed - owned
			})

	var readiness := 1.0
	if resource_required > 0:
		readiness = clampf(
			float(resource_owned_toward)
			/ float(resource_required),
			0.0,
			1.0
		)

	var saved := maxf(
		float(
			result.get(
				"estimated_delay_saved_seconds",
				0.0
			)
		),
		0.0
	)
	var per_10k := saved
	if coin_cost > 0:
		per_10k = (
			saved * 10000.0 / float(coin_cost)
		)

	var readiness_weight := (
		0.55 + readiness * 0.45
	)
	var payoff_score := per_10k * readiness_weight
	if coin_cost > coins:
		payoff_score *= 0.82

	result["resource_readiness_pct"] = readiness * 100.0
	result["resource_missing_total"] = resource_missing
	result["missing_resources"] = missing_resources
	result["coin_affordable"] = coins >= coin_cost
	result["resource_ready"] = resource_missing <= 0
	result["affordable_now"] = (
		coins >= coin_cost
		and resource_missing <= 0
	)
	result["delay_saved_per_10k"] = per_10k
	result["payoff_score"] = payoff_score
	return result
