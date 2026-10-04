class_name FleetRules
extends RefCounted


static func capacity_status(
	hangar_sources: Array[Dictionary],
	owned_aircraft: Array[Dictionary],
	candidate: Dictionary = {}
) -> Dictionary:
	var candidate_rank := -1
	var candidate_space := 0
	if not candidate.is_empty():
		candidate_rank = AircraftCatalog.size_rank(
			String(candidate.get("size_class", "S"))
		)
		candidate_space = maxi(int(candidate.get("hangar_space", 1)), 1)

	var maximum_rank := 0
	for source in hangar_sources:
		maximum_rank = maxi(
			maximum_rank,
			AircraftCatalog.size_rank(
				String(source.get("max_aircraft_size", "S"))
			)
		)
	for aircraft in owned_aircraft:
		maximum_rank = maxi(
			maximum_rank,
			AircraftCatalog.size_rank(
				String(aircraft.get("size_class", "S"))
			)
		)
	maximum_rank = maxi(maximum_rank, candidate_rank)

	var thresholds: Array[Dictionary] = []
	var allowed := true
	var blocking_size := ""

	for threshold in range(maximum_rank + 1):
		var capacity := 0
		for source in hangar_sources:
			if not bool(source.get("connected", true)):
				continue
			var max_rank := AircraftCatalog.size_rank(
				String(source.get("max_aircraft_size", "S"))
			)
			if max_rank >= threshold:
				capacity += maxi(int(source.get("capacity", 0)), 0)

		var used := 0
		for aircraft in owned_aircraft:
			var aircraft_rank := AircraftCatalog.size_rank(
				String(aircraft.get("size_class", "S"))
			)
			if aircraft_rank >= threshold:
				used += maxi(int(aircraft.get("hangar_space", 1)), 1)

		var projected := used
		if candidate_rank >= threshold:
			projected += candidate_space

		var threshold_allowed := projected <= capacity
		thresholds.append({
			"size_class": _size_for_rank(threshold),
			"capacity": capacity,
			"used": used,
			"projected": projected,
			"allowed": threshold_allowed
		})

		if not threshold_allowed and allowed:
			allowed = false
			blocking_size = _size_for_rank(threshold)

	var total_capacity := 0
	var total_used := 0
	if not thresholds.is_empty():
		total_capacity = int(thresholds[0].get("capacity", 0))
		total_used = int(thresholds[0].get("used", 0))

	return {
		"allowed": allowed,
		"blocking_size": blocking_size,
		"total_capacity": total_capacity,
		"total_used": total_used,
		"total_free": maxi(total_capacity - total_used, 0),
		"thresholds": thresholds
	}


static func _size_for_rank(rank: int) -> String:
	match rank:
		0:
			return "S"
		1:
			return "M"
		2:
			return "L"
		3:
			return "XL"
		_:
			return "?"
