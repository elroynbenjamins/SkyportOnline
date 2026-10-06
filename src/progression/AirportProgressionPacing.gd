class_name AirportProgressionPacing
extends RefCounted

const MAX_LEVEL := 30
const MAX_FLEET_CAPACITY := 16

const STAGES := [
	{
		"id": "local_airfield",
		"name": "Local Airfield",
		"min_level": 1,
		"max_level": 3,
		"description": "Learn short routes, passenger supply and basic ground handling."
	},
	{
		"id": "growing_airport",
		"name": "Growing Airport",
		"min_level": 4,
		"max_level": 7,
		"description": "Expand the apron, specialize services and grow the small-aircraft fleet."
	},
	{
		"id": "busy_regional",
		"name": "Busy Regional Airport",
		"min_level": 8,
		"max_level": 11,
		"description": "Medium-aircraft preparation, Dispatch shifts and higher traffic density."
	},
	{
		"id": "regional_hub",
		"name": "Regional Hub",
		"min_level": 12,
		"max_level": 16,
		"description": "Second-runway growth, weekly challenges and Alliance operations."
	},
	{
		"id": "connected_hub",
		"name": "Connected Hub",
		"min_level": 17,
		"max_level": 21,
		"description": "Flagship regional aircraft and a wider international route network."
	},
	{
		"id": "logistics_airport",
		"name": "Logistics Airport",
		"min_level": 22,
		"max_level": 25,
		"description": "Cargo Charter and dedicated logistics land become core expansion goals."
	},
	{
		"id": "mature_airport",
		"name": "Mature Airport",
		"min_level": 26,
		"max_level": 30,
		"description": "High-capacity support districts and long-term airport optimization."
	}
]

# Capacity is deliberately tighter than the absolute technical maximum.
# It creates the Skyrama/Hay Day-style pattern of earning room for the next
# aircraft instead of buying the full V1 fleet immediately.
const FLEET_CAPACITY_BY_LEVEL := {
	1: 2,
	2: 3,
	4: 4,
	6: 5,
	8: 6,
	10: 7,
	12: 9,
	14: 10,
	15: 11,
	17: 12,
	19: 13,
	21: 14,
	24: 15,
	28: 16
}

static func stage_for_level(level: int) -> Dictionary:
	var bounded := clampi(level, 1, MAX_LEVEL)
	for stage_variant in STAGES:
		var stage: Dictionary = stage_variant
		if (
			bounded >= int(stage.get("min_level", 1))
			and bounded <= int(
				stage.get(
					"max_level",
					MAX_LEVEL
				)
			)
		):
			return stage.duplicate(true)
	return (STAGES[STAGES.size() - 1] as Dictionary).duplicate(true)

static func fleet_capacity_for_level(level: int) -> int:
	var bounded := clampi(level, 1, MAX_LEVEL)
	var capacity := 2
	for unlock_level_variant in FLEET_CAPACITY_BY_LEVEL.keys():
		var unlock_level := int(unlock_level_variant)
		if bounded >= unlock_level:
			capacity = maxi(
				capacity,
				int(FLEET_CAPACITY_BY_LEVEL[unlock_level])
			)
	return mini(
		capacity,
		MAX_FLEET_CAPACITY
	)

static func unlocks_at_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level < 1 or level > MAX_LEVEL:
		return result

	for profile_variant in AircraftCatalog.all():
		var profile: Dictionary = profile_variant
		if int(profile.get("unlock_level", 1)) == level:
			result.append({
				"kind": "aircraft",
				"name": String(profile.get("name", "Aircraft"))
			})

	for destination_variant in DestinationCatalog.all():
		var destination: Dictionary = destination_variant
		if int(destination.get("unlock_level", 1)) == level:
			result.append({
				"kind": "route",
				"name": "%s route" % String(
					destination.get("city", "Destination")
				)
			})

	for building_variant in BuildingCatalog.all():
		var building: Dictionary = building_variant
		if int(building.get("level", 1)) == level:
			result.append({
				"kind": "building",
				"name": String(building.get("name", "Building"))
			})

	for zone_variant in AirportExpansionCatalog.all():
		var zone: Dictionary = zone_variant
		if (
			String(zone.get("id", "")) != "home"
			and int(zone.get("level", 1)) == level
		):
			result.append({
				"kind": "land",
				"name": String(zone.get("name", "Expansion"))
			})

	for mode_id_variant in ActivityProgressionRules.definitions().keys():
		var mode_id := String(mode_id_variant)
		if ActivityProgressionRules.unlock_level(mode_id) == level:
			result.append({
				"kind": "activity",
				"name": String(
					ActivityProgressionRules.definition(mode_id).get(
						"title",
						mode_id
					)
				)
			})

	var previous_capacity := fleet_capacity_for_level(maxi(level - 1, 1))
	var capacity := fleet_capacity_for_level(level)
	if capacity > previous_capacity:
		result.append({
			"kind": "capacity",
			"name": "Fleet capacity %d" % capacity
		})
	return result

static func next_unlock(level: int) -> Dictionary:
	if level >= MAX_LEVEL:
		return {}
	for next_level in range(
		maxi(level + 1, 2),
		MAX_LEVEL + 1
	):
		var unlocks := unlocks_at_level(next_level)
		if not unlocks.is_empty():
			return {
				"level": next_level,
				"unlocks": unlocks
			}
	return {}

static func unlock_names(level: int) -> Array[String]:
	var names: Array[String] = []
	for unlock_variant in unlocks_at_level(level):
		var unlock: Dictionary = unlock_variant
		names.append(String(unlock.get("name", "Unlock")))
	return names

static func next_unlock_text(level: int) -> String:
	var next := next_unlock(level)
	if next.is_empty():
		return "All current V1 progression milestones unlocked."
	var names: Array[String] = []
	for unlock_variant in next.get("unlocks", []):
		var unlock: Dictionary = unlock_variant
		names.append(String(unlock.get("name", "Unlock")))
	return "LV %d • %s" % [
		int(next.get("level", level)),
		" • ".join(names)
	]
