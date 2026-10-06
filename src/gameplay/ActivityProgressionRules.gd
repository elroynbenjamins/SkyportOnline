class_name ActivityProgressionRules
extends RefCounted

const EVENT_UNLOCK_LEVEL := 4
const DISPATCH_UNLOCK_LEVEL := 8
const CHALLENGE_UNLOCK_LEVEL := 12
const ALLIANCE_UNLOCK_LEVEL := 15

static func definitions() -> Dictionary:
	return {
		"missions": {
			"title": "Missions & Airport Pass",
			"unlock_level": 1,
			"mentor": "Mara • Airport Planner",
			"intro": "Daily and weekly missions reward normal airport play. Complete objectives, claim rewards and build progress through the monthly Airport Pass.",
			"tip": "Start here when you are unsure what to do next. Missions are guidance, not a separate grind."
		},
		"event": {
			"title": "Seasonal Events",
			"unlock_level": EVENT_UNLOCK_LEVEL,
			"mentor": "Mara • Airport Planner",
			"intro": "Limited events run in three phases. Current-phase quests, featured routes, an event shop and Alliance milestones give your normal airport a temporary seasonal focus.",
			"tip": "Event quests stay available after their phase moves into the archive, so you do not need to rush every objective immediately."
		},
		"dispatch": {
			"title": "Airport Dispatch",
			"unlock_level": DISPATCH_UNLOCK_LEVEL,
			"mentor": "Captain Tess",
			"intro": "Airport Dispatch is a three-minute live shift played on your real airport. Clean turnarounds, departures, returns and visitor service score points while taxi holds break your combo.",
			"tip": "Prepare passenger stock and clear congestion before starting. Bronze is 30, Silver 65 and Gold 105 points."
		},
		"challenge": {
			"title": "Weekly Airport Challenge",
			"unlock_level": CHALLENGE_UNLOCK_LEVEL,
			"mentor": "Captain Elise",
			"intro": "The Weekly Airport Challenge scores your normal passenger flights across the whole week. Its theme rotates, so some weeks favor passengers, distance, resources or visiting new countries.",
			"tip": "You never need to start a separate run. Keep flying normally and claim milestone rewards when they become ready."
		},
		"alliance": {
			"title": "Alliance Operations",
			"unlock_level": ALLIANCE_UNLOCK_LEVEL,
			"mentor": "Captain Nico",
			"intro": "Alliance Operations are cooperative weekly projects. Flights, serviced Alliance visitors and passenger support contribute different point values depending on the active project.",
			"tip": "Alliance-wide progress only pays out when you also meet the personal contribution requirement."
		},
		"charter": {
			"title": "Cargo Charter",
			"unlock_level": CharterRules.UNLOCK_LEVEL,
			"mentor": "Mara • Logistics Planner",
			"intro": "Cargo Charter opens the Logistics District and adds dedicated freight contracts. Express, Bulk and Resource Priority contracts trade speed, coins, XP and guaranteed country resources differently.",
			"tip": "The Logistics District must be purchased and clear of conflicting buildings before a Charter can begin."
		}
	}

static func definition(mode_id: String) -> Dictionary:
	var all := definitions()
	if not all.has(mode_id):
		return {}
	return (all[mode_id] as Dictionary).duplicate(true)

static func unlock_level(mode_id: String) -> int:
	return int(definition(mode_id).get("unlock_level", 1))

static func is_level_unlocked(mode_id: String, level: int) -> bool:
	return level >= unlock_level(mode_id)

static func tutorial_seen(state: Dictionary, mode_id: String) -> bool:
	var seen: Dictionary = state.get("activity_tutorials_seen", {})
	return bool(seen.get(mode_id, false))

static func mark_tutorial_seen(state: Dictionary, mode_id: String) -> bool:
	if definition(mode_id).is_empty():
		return false
	var seen: Dictionary = state.get(
		"activity_tutorials_seen",
		{}
	).duplicate(true)
	if bool(seen.get(mode_id, false)):
		return false
	seen[mode_id] = true
	state["activity_tutorials_seen"] = seen
	return true

static func is_newly_unlocked(
	state: Dictionary,
	mode_id: String,
	level: int
) -> bool:
	return (
		is_level_unlocked(mode_id, level)
		and not tutorial_seen(state, mode_id)
	)
