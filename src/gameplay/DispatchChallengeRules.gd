class_name DispatchChallengeRules
extends RefCounted

const UNLOCK_LEVEL := 12
const SHIFT_SECONDS := 180
const DAY_SECONDS := 86400
const COMBO_WINDOW_SECONDS := 30
const MAX_COMBO_BONUS := 4

const ACTION_POINTS := {
	"turnaround": 5,
	"departure": 8,
	"return": 12,
	"visitor_service": 10,
	"taxi_hold": -4
}

const TIERS := [
	{
		"id": "bronze",
		"name": "Bronze Dispatch",
		"target": 30,
		"coins": 500,
		"xp": 20
	},
	{
		"id": "silver",
		"name": "Silver Dispatch",
		"target": 65,
		"coins": 1200,
		"xp": 45
	},
	{
		"id": "gold",
		"name": "Gold Dispatch",
		"target": 105,
		"coins": 2500,
		"xp": 80
	}
]

static func is_unlocked(level: int) -> bool:
	return level >= UNLOCK_LEVEL

static func day_key(unix_time: float) -> int:
	return int(floor(maxf(unix_time, 0.0) / float(DAY_SECONDS)))

static func ensure_state(
	state: Dictionary,
	level: int,
	unix_time: float
) -> bool:
	if not is_unlocked(level):
		return false

	var changed := false
	var current_day := day_key(unix_time)
	var dispatch: Dictionary = state.get(
		"dispatch_challenge",
		{}
	).duplicate(true)
	if dispatch.is_empty():
		dispatch = {
			"day_key": current_day,
			"best_score": 0,
			"reward_claimed": false,
			"active": {}
		}
		changed = true
	elif int(dispatch.get("day_key", -1)) != current_day:
		var active: Dictionary = dispatch.get("active", {})
		if active.is_empty():
			dispatch["day_key"] = current_day
			dispatch["best_score"] = 0
			dispatch["reward_claimed"] = false
			changed = true

	state["dispatch_challenge"] = dispatch
	if advance(state, level, unix_time):
		changed = true
	return changed

static func start_shift(
	state: Dictionary,
	level: int,
	unix_time: float
) -> Dictionary:
	if not is_unlocked(level):
		return {}
	var next := state.duplicate(true)
	ensure_state(next, level, unix_time)
	var dispatch: Dictionary = next.get(
		"dispatch_challenge",
		{}
	).duplicate(true)
	if not (dispatch.get("active", {}) as Dictionary).is_empty():
		return {}

	var started_at := maxi(int(unix_time), 0)
	dispatch["active"] = {
		"status": "RUNNING",
		"started_at": started_at,
		"ends_at": started_at + SHIFT_SECONDS,
		"score": 0,
		"turnarounds": 0,
		"departures": 0,
		"returns": 0,
		"visitor_services": 0,
		"taxi_holds": 0,
		"clean_actions": 0,
		"combo_count": 0,
		"max_combo": 0,
		"combo_bonus": 0,
		"penalty_points": 0,
		"last_positive_at": -1
	}
	next["dispatch_challenge"] = dispatch
	return next

static func record_action(
	state: Dictionary,
	level: int,
	action: String,
	amount: int,
	unix_time: float
) -> int:
	if not is_unlocked(level) or amount <= 0:
		return 0
	ensure_state(state, level, unix_time)
	var dispatch: Dictionary = state.get(
		"dispatch_challenge",
		{}
	).duplicate(true)
	var active: Dictionary = dispatch.get("active", {}).duplicate(true)
	if active.is_empty() or String(active.get("status", "")) != "RUNNING":
		return 0

	if int(unix_time) >= int(active.get("ends_at", 0)):
		advance(state, level, unix_time)
		return 0
	if not ACTION_POINTS.has(action):
		return 0

	var total_delta := 0
	for index in range(amount):
		total_delta += _score_single_action(
			active,
			action,
			int(unix_time)
		)

	match action:
		"turnaround":
			active["turnarounds"] = int(active.get("turnarounds", 0)) + amount
		"departure":
			active["departures"] = int(active.get("departures", 0)) + amount
		"return":
			active["returns"] = int(active.get("returns", 0)) + amount
		"visitor_service":
			active["visitor_services"] = int(active.get("visitor_services", 0)) + amount
		"taxi_hold":
			active["taxi_holds"] = int(active.get("taxi_holds", 0)) + amount

	active["score"] = maxi(
		int(active.get("score", 0)) + total_delta,
		0
	)
	dispatch["active"] = active
	state["dispatch_challenge"] = dispatch
	return total_delta

static func advance(
	state: Dictionary,
	level: int,
	unix_time: float
) -> bool:
	if not is_unlocked(level):
		return false
	var dispatch: Dictionary = state.get(
		"dispatch_challenge",
		{}
	).duplicate(true)
	var active: Dictionary = dispatch.get("active", {}).duplicate(true)
	if active.is_empty() or String(active.get("status", "")) != "RUNNING":
		return false
	if int(unix_time) < int(active.get("ends_at", 0)):
		return false

	active["status"] = "READY"
	active["finished_at"] = int(active.get("ends_at", int(unix_time)))
	dispatch["active"] = active
	_next_best(dispatch, int(active.get("score", 0)))
	state["dispatch_challenge"] = dispatch
	return true

static func claim_result(
	state: Dictionary,
	level: int,
	unix_time: float
) -> Dictionary:
	if not is_unlocked(level):
		return {}
	var next := state.duplicate(true)
	ensure_state(next, level, unix_time)
	var dispatch: Dictionary = next.get(
		"dispatch_challenge",
		{}
	).duplicate(true)
	var active: Dictionary = dispatch.get("active", {}).duplicate(true)
	if active.is_empty() or String(active.get("status", "")) != "READY":
		return {}

	var score := int(active.get("score", 0))
	var tier := tier_for_score(score)
	var reward_available := (
		not tier.is_empty()
		and not bool(dispatch.get("reward_claimed", false))
	)
	var reward := {
		"score": score,
		"tier_id": String(tier.get("id", "")),
		"tier_name": String(tier.get("name", "No Medal")),
		"coins": 0,
		"xp": 0,
		"rewarded": false,
		"max_combo": int(active.get("max_combo", 0)),
		"combo_bonus": int(active.get("combo_bonus", 0)),
		"penalty_points": int(active.get("penalty_points", 0))
	}
	if reward_available:
		reward["coins"] = int(tier.get("coins", 0))
		reward["xp"] = int(tier.get("xp", 0))
		reward["rewarded"] = true
		next["coins"] = int(next.get("coins", 0)) + int(reward["coins"])
		next["xp"] = int(next.get("xp", 0)) + int(reward["xp"])
		dispatch["reward_claimed"] = true

	dispatch["active"] = {}
	dispatch["day_key"] = day_key(unix_time)
	_next_best(dispatch, score)
	next["dispatch_challenge"] = dispatch
	return {
		"state": next,
		"reward": reward
	}

static func snapshot(
	state: Dictionary,
	level: int,
	unix_time: float
) -> Dictionary:
	var unlocked := is_unlocked(level)
	var copy := state.duplicate(true)
	if unlocked:
		ensure_state(copy, level, unix_time)
	var dispatch: Dictionary = copy.get("dispatch_challenge", {})
	var active: Dictionary = (
		dispatch.get("active", {}) as Dictionary
	).duplicate(true)
	var status := String(active.get("status", "IDLE"))
	var remaining := 0
	if status == "RUNNING":
		remaining = maxi(
			int(active.get("ends_at", 0)) - int(unix_time),
			0
		)
	var score := int(active.get("score", 0))
	var tier := tier_for_score(score)
	var reward_claimed := bool(dispatch.get("reward_claimed", false))
	var next_tier := next_tier_after_score(score)
	return {
		"unlocked": unlocked,
		"unlock_level": UNLOCK_LEVEL,
		"shift_seconds": SHIFT_SECONDS,
		"combo_window_seconds": COMBO_WINDOW_SECONDS,
		"max_combo_bonus": MAX_COMBO_BONUS,
		"status": status,
		"remaining_seconds": remaining,
		"score": score,
		"tier_id": String(tier.get("id", "")),
		"tier_name": String(tier.get("name", "")),
		"next_tier_name": String(next_tier.get("name", "")),
		"next_tier_target": int(next_tier.get("target", 0)),
		"points_to_next_tier": (
			maxi(int(next_tier.get("target", 0)) - score, 0)
			if not next_tier.is_empty()
			else 0
		),
		"reward_claimed": reward_claimed,
		"reward_available": (
			status == "READY"
			and not tier.is_empty()
			and not reward_claimed
		),
		"best_score": int(dispatch.get("best_score", 0)),
		"turnarounds": int(active.get("turnarounds", 0)),
		"departures": int(active.get("departures", 0)),
		"returns": int(active.get("returns", 0)),
		"visitor_services": int(active.get("visitor_services", 0)),
		"taxi_holds": int(active.get("taxi_holds", 0)),
		"clean_actions": int(active.get("clean_actions", 0)),
		"combo_count": int(active.get("combo_count", 0)),
		"max_combo": int(active.get("max_combo", 0)),
		"combo_bonus": int(active.get("combo_bonus", 0)),
		"penalty_points": int(active.get("penalty_points", 0)),
		"tiers": TIERS.duplicate(true),
		"scoring": ACTION_POINTS.duplicate(true)
	}

static func tier_for_score(score: int) -> Dictionary:
	var result: Dictionary = {}
	for tier_variant in TIERS:
		var tier: Dictionary = tier_variant
		if score >= int(tier.get("target", 0)):
			result = tier.duplicate(true)
	return result

static func next_tier_after_score(score: int) -> Dictionary:
	for tier_variant in TIERS:
		var tier: Dictionary = tier_variant
		if score < int(tier.get("target", 0)):
			return tier.duplicate(true)
	return {}

static func _score_single_action(
	active: Dictionary,
	action: String,
	unix_time: int
) -> int:
	var base := int(ACTION_POINTS.get(action, 0))
	if base < 0:
		var penalty := absi(base)
		active["penalty_points"] = (
			int(active.get("penalty_points", 0))
			+ penalty
		)
		active["combo_count"] = 0
		active["last_positive_at"] = -1
		return base

	var last_positive := int(active.get("last_positive_at", -1))
	var combo := int(active.get("combo_count", 0))
	if (
		last_positive >= 0
		and unix_time - last_positive <= COMBO_WINDOW_SECONDS
	):
		combo += 1
	else:
		combo = 1

	var combo_bonus := mini(
		maxi(combo - 1, 0),
		MAX_COMBO_BONUS
	)
	active["combo_count"] = combo
	active["max_combo"] = maxi(
		int(active.get("max_combo", 0)),
		combo
	)
	active["combo_bonus"] = (
		int(active.get("combo_bonus", 0))
		+ combo_bonus
	)
	active["clean_actions"] = (
		int(active.get("clean_actions", 0))
		+ 1
	)
	active["last_positive_at"] = unix_time
	return base + combo_bonus

static func _next_best(
	dispatch: Dictionary,
	score: int
) -> void:
	dispatch["best_score"] = maxi(
		int(dispatch.get("best_score", 0)),
		score
	)
