class_name AirportChallengeRules
extends RefCounted

const UNLOCK_LEVEL := 8
const WEEK_SECONDS := 604800
const MILESTONES := [
	{"id": "bronze", "name": "Bronze Wing", "target": 25, "coins": 1200, "xp": 40, "aero": 0},
	{"id": "silver", "name": "Silver Wing", "target": 55, "coins": 2400, "xp": 70, "aero": 0},
	{"id": "gold", "name": "Gold Wing", "target": 95, "coins": 4200, "xp": 110, "aero": 0},
	{"id": "captain", "name": "Captain's Mark", "target": 145, "coins": 6800, "xp": 170, "aero": 1},
	{"id": "ace", "name": "Airport Ace", "target": 210, "coins": 10000, "xp": 250, "aero": 2}
]

static func is_unlocked(level: int) -> bool:
	return level >= UNLOCK_LEVEL

static func week_key(now: float) -> int:
	return int(floor(now / float(WEEK_SECONDS)))

static func ensure_state(state: Dictionary, level: int, now: float) -> bool:
	if not is_unlocked(level):
		return false
	var current_key := week_key(now)
	var challenge: Dictionary = state.get("airport_challenge", {})
	if challenge.is_empty() or int(challenge.get("week_key", -1)) != current_key:
		state["airport_challenge"] = {
			"week_key": current_key,
			"score": 0,
			"flights": 0,
			"passengers": 0,
			"distance_km": 0,
			"resources": 0,
			"countries": {},
			"claimed": []
		}
		return true
	return false

static func record_flight(state: Dictionary, level: int, payload: Dictionary, now: float) -> int:
	if not is_unlocked(level):
		return 0
	ensure_state(state, level, now)
	var challenge: Dictionary = state.get("airport_challenge", {})
	var countries: Dictionary = challenge.get("countries", {})
	var country := String(payload.get("country", ""))
	var new_country := not country.is_empty() and not countries.has(country)
	if not country.is_empty():
		countries[country] = true

	var passengers := maxi(int(payload.get("passengers", 0)), 0)
	var distance_km := maxi(int(payload.get("distance_km", 0)), 0)
	var resources := maxi(int(payload.get("resources", 0)), 0)
	var points := 5
	points += mini(int(distance_km / 500), 4)
	points += mini(int(passengers / 25), 3)
	if resources > 0:
		points += 1
	if new_country:
		points += 2

	challenge["score"] = int(challenge.get("score", 0)) + points
	challenge["flights"] = int(challenge.get("flights", 0)) + 1
	challenge["passengers"] = int(challenge.get("passengers", 0)) + passengers
	challenge["distance_km"] = int(challenge.get("distance_km", 0)) + distance_km
	challenge["resources"] = int(challenge.get("resources", 0)) + resources
	challenge["countries"] = countries
	state["airport_challenge"] = challenge
	return points

static func claim_milestone(state: Dictionary, level: int, milestone_id: String, now: float) -> Dictionary:
	if not is_unlocked(level):
		return {}
	ensure_state(state, level, now)
	var milestone := _milestone(milestone_id)
	if milestone.is_empty():
		return {}
	var challenge: Dictionary = state.get("airport_challenge", {})
	var claimed: Array = challenge.get("claimed", [])
	if claimed.has(milestone_id) or int(challenge.get("score", 0)) < int(milestone.get("target", 0)):
		return {}

	var next := state.duplicate(true)
	var next_challenge: Dictionary = next.get("airport_challenge", {})
	var next_claimed: Array = next_challenge.get("claimed", [])
	next_claimed.append(milestone_id)
	next_challenge["claimed"] = next_claimed
	next["airport_challenge"] = next_challenge
	next["coins"] = int(next.get("coins", 0)) + int(milestone.get("coins", 0))
	next["xp"] = int(next.get("xp", 0)) + int(milestone.get("xp", 0))
	var aero := int(milestone.get("aero", 0))
	if aero > 0:
		next["aero_tokens"] = int(next.get("aero_tokens", next.get("gems", 0))) + aero
		next["gems"] = int(next.get("aero_tokens", 0))
	return {
		"state": next,
		"reward": milestone.duplicate(true)
	}

static func snapshot(state: Dictionary, level: int, now: float) -> Dictionary:
	var unlocked := is_unlocked(level)
	if unlocked:
		ensure_state(state, level, now)
	var challenge: Dictionary = state.get("airport_challenge", {})
	var score := int(challenge.get("score", 0))
	var claimed: Array = challenge.get("claimed", [])
	var rows: Array[Dictionary] = []
	for milestone_variant in MILESTONES:
		var milestone: Dictionary = milestone_variant
		var row := milestone.duplicate(true)
		row["claimed"] = claimed.has(String(milestone.get("id", "")))
		row["claimable"] = score >= int(milestone.get("target", 0)) and not bool(row["claimed"])
		rows.append(row)

	var next_target := 0
	for row in rows:
		if score < int(row.get("target", 0)):
			next_target = int(row.get("target", 0))
			break
	return {
		"unlocked": unlocked,
		"unlock_level": UNLOCK_LEVEL,
		"score": score,
		"next_target": next_target,
		"seconds_remaining": _seconds_remaining(now),
		"flights": int(challenge.get("flights", 0)),
		"passengers": int(challenge.get("passengers", 0)),
		"distance_km": int(challenge.get("distance_km", 0)),
		"resources": int(challenge.get("resources", 0)),
		"countries": (challenge.get("countries", {}) as Dictionary).size(),
		"milestones": rows
	}

static func claimable_count(state: Dictionary, level: int, now: float) -> int:
	var data := snapshot(state, level, now)
	var total := 0
	for milestone_variant in data.get("milestones", []):
		if bool((milestone_variant as Dictionary).get("claimable", false)):
			total += 1
	return total

static func _milestone(id: String) -> Dictionary:
	for milestone_variant in MILESTONES:
		var milestone: Dictionary = milestone_variant
		if String(milestone.get("id", "")) == id:
			return milestone
	return {}

static func _seconds_remaining(now: float) -> int:
	var start := week_key(now) * WEEK_SECONDS
	return maxi((start + WEEK_SECONDS) - int(now), 0)
