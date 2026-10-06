class_name AllianceOperationsRules
extends RefCounted

const WEEK_SECONDS := 604800

const PROJECTS := [
	{
		"id": "airbridge",
		"name": "Regional Airbridge",
		"short_name": "Airbridge",
		"description": "Balanced alliance operations. Flights, visiting alliance aircraft and passenger support all contribute.",
		"flight_points": 1,
		"alliance_visit_points": 3,
		"alliance_gift_points": 1
	},
	{
		"id": "fleet_mobilization",
		"name": "Fleet Mobilization",
		"short_name": "Fleet Push",
		"description": "Keep alliance routes moving. Completed flights are the main source of project points.",
		"flight_points": 3,
		"alliance_visit_points": 2,
		"alliance_gift_points": 1
	},
	{
		"id": "host_network",
		"name": "Host Network",
		"short_name": "Host Network",
		"description": "Welcome alliance traffic. Servicing visiting alliance aircraft earns the largest contribution.",
		"flight_points": 1,
		"alliance_visit_points": 5,
		"alliance_gift_points": 2
	},
	{
		"id": "passenger_relief",
		"name": "Passenger Relief",
		"short_name": "Relief",
		"description": "Support the network with passengers. Alliance passenger gifts are heavily rewarded this week.",
		"flight_points": 1,
		"alliance_visit_points": 2,
		"alliance_gift_points": 4
	}
]

static func milestones() -> Array[Dictionary]:
	return [
		{
			"id": "regional_support",
			"name": "Regional Support",
			"target": 10,
			"personal_required": 2,
			"coins": 1500,
			"xp": 0
		},
		{
			"id": "network_push",
			"name": "Network Push",
			"target": 25,
			"personal_required": 5,
			"coins": 2500,
			"xp": 75
		},
		{
			"id": "airbridge_complete",
			"name": "Project Complete",
			"target": 50,
			"personal_required": 10,
			"coins": 5000,
			"xp": 150
		}
	]

static func week_key(unix_time: float) -> int:
	return int(floor(maxf(unix_time, 0.0) / float(WEEK_SECONDS)))

static func project_for_week(key: int) -> Dictionary:
	if PROJECTS.is_empty():
		return {}
	return (PROJECTS[posmod(key, PROJECTS.size())] as Dictionary).duplicate(true)

static func ensure_state(
	state: Dictionary,
	unix_time: float
) -> bool:
	var current_key := week_key(unix_time)
	var project := project_for_week(current_key)
	var project_id := String(project.get("id", "airbridge"))
	var alliance: Dictionary = state.get(
		"alliance_ops",
		{}
	).duplicate(true)
	if (
		alliance.is_empty()
		or int(alliance.get("week_key", -1)) != current_key
	):
		alliance = {
			"week_key": current_key,
			"project_id": project_id,
			"personal_points": 0,
			"server_total": 0,
			"alliance_total": 0,
			"contributions": {},
			"claimed": {}
		}
		state["alliance_ops"] = alliance
		return true

	if String(alliance.get("project_id", "")) != project_id:
		# Same-week legacy migration: attach the deterministic project
		# without resetting already-earned progress or rewards.
		alliance["project_id"] = project_id
		state["alliance_ops"] = alliance
		return true

	state["alliance_ops"] = alliance
	return false

static func record_action(
	state: Dictionary,
	action: String,
	amount: int,
	unix_time: float
) -> bool:
	if action.is_empty() or amount <= 0:
		return false
	ensure_state(state, unix_time)
	var alliance: Dictionary = state.get(
		"alliance_ops",
		{}
	).duplicate(true)
	var project := project_for_week(
		int(alliance.get("week_key", week_key(unix_time)))
	)
	var points_per_action := _point_values(project)
	if not points_per_action.has(action):
		return false
	var points := int(points_per_action[action]) * amount
	alliance["personal_points"] = (
		int(alliance.get("personal_points", 0))
		+ points
	)
	var contributions: Dictionary = (
		alliance.get("contributions", {}) as Dictionary
	).duplicate(true)
	contributions[action] = (
		int(contributions.get(action, 0))
		+ amount
	)
	alliance["contributions"] = contributions
	alliance["alliance_total"] = maxi(
		int(alliance.get("server_total", 0)),
		int(alliance.get("personal_points", 0))
	)
	state["alliance_ops"] = alliance
	return true

static func set_server_total(
	state: Dictionary,
	total: int,
	unix_time: float
) -> bool:
	ensure_state(state, unix_time)
	var alliance: Dictionary = state.get(
		"alliance_ops",
		{}
	).duplicate(true)
	var normalized := maxi(total, 0)
	if int(alliance.get("server_total", 0)) == normalized:
		return false
	alliance["server_total"] = normalized
	alliance["alliance_total"] = maxi(
		normalized,
		int(alliance.get("personal_points", 0))
	)
	state["alliance_ops"] = alliance
	return true

static func claim_milestone(
	state: Dictionary,
	milestone_id: String,
	unix_time: float
) -> Dictionary:
	if milestone_id.is_empty():
		return {}
	var next := state.duplicate(true)
	ensure_state(next, unix_time)
	var alliance: Dictionary = next.get(
		"alliance_ops",
		{}
	).duplicate(true)
	var milestone := _milestone_by_id(milestone_id)
	if milestone.is_empty():
		return {}
	var claimed: Dictionary = (
		alliance.get("claimed", {}) as Dictionary
	).duplicate(true)
	if bool(claimed.get(milestone_id, false)):
		return {}
	if (
		int(alliance.get("alliance_total", 0))
		< int(milestone.get("target", 0))
	):
		return {}
	if (
		int(alliance.get("personal_points", 0))
		< int(milestone.get("personal_required", 0))
	):
		return {}
	claimed[milestone_id] = true
	alliance["claimed"] = claimed
	next["alliance_ops"] = alliance
	var coins := maxi(int(milestone.get("coins", 0)), 0)
	var xp := maxi(int(milestone.get("xp", 0)), 0)
	next["coins"] = int(next.get("coins", 0)) + coins
	next["xp"] = int(next.get("xp", 0)) + xp
	return {
		"state": next,
		"reward": {
			"id": milestone_id,
			"name": String(
				milestone.get("name", "Alliance milestone")
			),
			"coins": coins,
			"xp": xp,
			"project_name": String(
				project_for_week(
					int(alliance.get(
						"week_key",
						week_key(unix_time)
					))
				).get("name", "Alliance Operations")
			)
		}
	}

static func snapshot(
	state: Dictionary,
	unix_time: float,
	provider_connected: bool,
	local_simulation: bool
) -> Dictionary:
	var copy := state.duplicate(true)
	ensure_state(copy, unix_time)
	var alliance: Dictionary = copy.get("alliance_ops", {})
	var current_key := int(
		alliance.get("week_key", week_key(unix_time))
	)
	var project := project_for_week(current_key)
	var point_values := _point_values(project)
	var entries: Array[Dictionary] = []
	for milestone_variant in milestones():
		var milestone: Dictionary = milestone_variant.duplicate(true)
		var id := String(milestone.get("id", ""))
		var claimed: Dictionary = alliance.get("claimed", {})
		milestone["claimed"] = bool(claimed.get(id, false))
		milestone["reached"] = (
			int(alliance.get("alliance_total", 0))
			>= int(milestone.get("target", 0))
		)
		milestone["personal_ready"] = (
			int(alliance.get("personal_points", 0))
			>= int(milestone.get("personal_required", 0))
		)
		milestone["claimable"] = (
			bool(milestone["reached"])
			and bool(milestone["personal_ready"])
			and not bool(milestone["claimed"])
		)
		entries.append(milestone)

	var seconds_remaining := maxi(
		(current_key + 1) * WEEK_SECONDS - int(unix_time),
		0
	)
	return {
		"week_key": current_key,
		"seconds_remaining": seconds_remaining,
		"project_id": String(project.get("id", "airbridge")),
		"project_name": String(
			project.get("name", "Regional Airbridge")
		),
		"project_short_name": String(
			project.get("short_name", "Airbridge")
		),
		"project_description": String(
			project.get("description", "")
		),
		"next_project_name": String(
			project_for_week(current_key + 1).get(
				"name",
				"Alliance Operations"
			)
		),
		"point_values": point_values,
		"personal_points": int(
			alliance.get("personal_points", 0)
		),
		"alliance_total": int(
			alliance.get("alliance_total", 0)
		),
		"server_total": int(
			alliance.get("server_total", 0)
		),
		"contributions": (
			alliance.get("contributions", {}) as Dictionary
		).duplicate(true),
		"milestones": entries,
		"provider_connected": provider_connected,
		"local_simulation": local_simulation
	}

static func claimable_count(
	state: Dictionary,
	unix_time: float
) -> int:
	var data := snapshot(state, unix_time, false, true)
	var total := 0
	for milestone_variant in data.get("milestones", []):
		var milestone: Dictionary = milestone_variant
		if bool(milestone.get("claimable", false)):
			total += 1
	return total

static func _point_values(project: Dictionary) -> Dictionary:
	return {
		"flight": maxi(
			int(project.get("flight_points", 1)),
			0
		),
		"alliance_visit": maxi(
			int(project.get("alliance_visit_points", 3)),
			0
		),
		"alliance_gift": maxi(
			int(project.get("alliance_gift_points", 1)),
			0
		)
	}

static func _milestone_by_id(
	milestone_id: String
) -> Dictionary:
	for milestone_variant in milestones():
		var milestone: Dictionary = milestone_variant
		if String(milestone.get("id", "")) == milestone_id:
			return milestone.duplicate(true)
	return {}
