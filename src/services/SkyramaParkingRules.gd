class_name SkyramaParkingRules
extends RefCounted

# Service buildings limit concurrently RUNNING jobs. Finished aircraft may
# remain parked on their individual slabs without tying up a depot worker.
# They still occupy the physical bay until LOAD, SEND or HANGAR moves them.
static func select_available_pad(
	service_type: String,
	pads: Array[Dictionary],
	processing_capacity: int,
	occupants: Array[Dictionary]
) -> Dictionary:
	if processing_capacity <= 0:
		return {}

	var running_jobs := 0
	for occupant in occupants:
		var state := String(occupant.get("state", ""))
		if _is_processing(service_type, state):
			running_jobs += 1
	if running_jobs >= processing_capacity:
		return {}

	for pad in pads:
		var location: Vector2 = pad.get(
			"world_position", Vector2.ZERO
		)
		var in_use := false
		for occupant in occupants:
			var position: Vector2 = occupant.get(
				"world_position", Vector2.ZERO
			)
			if position.distance_to(location) < 3.0:
				in_use = true
				break
		if not in_use:
			return pad.duplicate(true)
	return {}


static func _is_processing(service_type: String, state: String) -> bool:
	match service_type:
		"fuel":
			return state == "SIMPLE_FUELING"
		"cargo":
			return state in [
				"SIMPLE_LOADING", "SIMPLE_UNLOADING"
			]
		_:
			return false
