class_name MissionPassRules
extends RefCounted

const DAILY_COUNT := 4
const WEEKLY_COUNT := 5
const SECONDS_PER_DAY := 86400
const SECONDS_PER_WEEK := 604800

static func ensure_state(state: Dictionary, unix_time: float, level: int) -> bool:
	if state.is_empty():
		return false
	var changed := false
	if not state.has("aero_tokens"):
		state["aero_tokens"] = int(state.get("gems", 0))
		changed = true
	if int(state.get("gems", 0)) != int(state.get("aero_tokens", 0)):
		state["gems"] = int(state.get("aero_tokens", 0))
		changed = true
	if not state.has("booster_inventory"):
		state["booster_inventory"] = {}
		changed = true
	if not state.has("active_boosters"):
		state["active_boosters"] = {}
		changed = true
	if not state.has("resource_choice_crates"):
		state["resource_choice_crates"] = 0
		changed = true
	if not state.has("pass_cosmetics"):
		state["pass_cosmetics"] = {}
		changed = true

	var day_key := _day_key(unix_time)
	var week_key := _week_key(unix_time)
	var month_key := _month_key(unix_time)
	var pass_state: Dictionary = state.get("mission_pass", {})
	if not pass_state.is_empty() and String(pass_state.get("month_key", "")) != month_key:
		_auto_claim_expiring_pass(state, pass_state)
	if String(pass_state.get("month_key", "")) != month_key:
		pass_state = {
			"month_key": month_key,
			"points": 0,
			"premium": false,
			"daily_key": "",
			"daily": [],
			"daily_bonus_awarded": false,
			"free_reroll_used": false,
			"ad_reroll_used": false,
			"daily_reroll_serial": 0,
			"weekly": [],
			"weeks_created": {},
			"weekly_bonus_awarded": {},
			"claimed_free": {},
			"claimed_premium": {}
		}
		state["mission_pass"] = pass_state
		changed = true

	if String(pass_state.get("daily_key", "")) != day_key:
		pass_state["daily_key"] = day_key
		pass_state["daily"] = _generate_missions(
			MissionPassCatalog.daily_templates(),
			DAILY_COUNT,
			level,
			"daily",
			day_key,
			String(state.get("airport_id", "airport"))
		)
		pass_state["daily_bonus_awarded"] = false
		pass_state["free_reroll_used"] = false
		pass_state["ad_reroll_used"] = false
		pass_state["daily_reroll_serial"] = 0
		changed = true

	var weeks_created: Dictionary = pass_state.get("weeks_created", {})
	var weekly: Array = pass_state.get("weekly", [])
	var current_week_index := _month_week_index(unix_time)
	for week_index in range(1, current_week_index + 1):
		var catchup_key := "%s-W%d" % [month_key, week_index]
		if bool(weeks_created.get(catchup_key, false)):
			continue
		weekly.append_array(_generate_missions(
			MissionPassCatalog.weekly_templates(),
			WEEKLY_COUNT,
			level,
			"weekly",
			catchup_key,
			String(state.get("airport_id", "airport"))
		))
		weeks_created[catchup_key] = true
		changed = true
	pass_state["weekly"] = weekly
	pass_state["weeks_created"] = weeks_created

	state["mission_pass"] = pass_state
	return changed

static func record_event(
	state: Dictionary,
	event_kind: String,
	payload: Dictionary,
	unix_time: float,
	level: int
) -> Dictionary:
	ensure_state(state, unix_time, level)
	var pass_state: Dictionary = state.get("mission_pass", {})
	var result := {"changed": false, "points_added": 0, "completed": []}
	var daily: Array = pass_state.get("daily", [])
	var daily_result := _advance_missions(daily, event_kind, payload, MissionPassCatalog.DAILY_MISSION_POINTS)
	if bool(daily_result.get("changed", false)):
		result["changed"] = true
		result["points_added"] = int(result["points_added"]) + int(daily_result.get("points_added", 0))
		(result["completed"] as Array).append_array(daily_result.get("completed", []))
		pass_state["daily"] = daily

	if _all_awarded(daily) and not bool(pass_state.get("daily_bonus_awarded", false)):
		pass_state["daily_bonus_awarded"] = true
		result["points_added"] = int(result["points_added"]) + MissionPassCatalog.DAILY_COMPLETION_BONUS
		result["changed"] = true

	var weekly: Array = pass_state.get("weekly", [])
	var weekly_result := _advance_missions(weekly, event_kind, payload, MissionPassCatalog.WEEKLY_MISSION_POINTS)
	if bool(weekly_result.get("changed", false)):
		result["changed"] = true
		result["points_added"] = int(result["points_added"]) + int(weekly_result.get("points_added", 0))
		(result["completed"] as Array).append_array(weekly_result.get("completed", []))
		pass_state["weekly"] = weekly

	var weekly_bonus: Dictionary = pass_state.get("weekly_bonus_awarded", {})
	for week in pass_state.get("weeks_created", {}).keys():
		if bool(weekly_bonus.get(week, false)):
			continue
		var set_missions: Array = []
		for mission in weekly:
			if String(mission.get("period_key", "")) == String(week):
				set_missions.append(mission)
		if set_missions.size() == WEEKLY_COUNT and _all_awarded(set_missions):
			weekly_bonus[week] = true
			result["points_added"] = int(result["points_added"]) + MissionPassCatalog.WEEKLY_COMPLETION_BONUS
			result["changed"] = true
	pass_state["weekly_bonus_awarded"] = weekly_bonus

	if int(result["points_added"]) > 0:
		pass_state["points"] = int(pass_state.get("points", 0)) + int(result["points_added"])
	state["mission_pass"] = pass_state
	return result

static func reroll_daily(
	state: Dictionary,
	mission_id: String,
	use_ad: bool,
	unix_time: float,
	level: int
) -> bool:
	ensure_state(state, unix_time, level)
	var pass_state: Dictionary = state.get("mission_pass", {})
	if use_ad:
		if bool(pass_state.get("ad_reroll_used", false)):
			return false
	else:
		if bool(pass_state.get("free_reroll_used", false)):
			return false

	var daily: Array = pass_state.get("daily", [])
	var target_index := -1
	var used_templates: Dictionary = {}
	for index in range(daily.size()):
		var mission: Dictionary = daily[index]
		used_templates[String(mission.get("template_id", ""))] = true
		if String(mission.get("id", "")) == mission_id:
			if bool(mission.get("awarded", false)):
				return false
			target_index = index
	if target_index < 0:
		return false

	var eligible: Array[Dictionary] = []
	for template in MissionPassCatalog.daily_templates():
		if level < int(template.get("min_level", 1)):
			continue
		if used_templates.has(String(template.get("id", ""))):
			continue
		eligible.append(template)
	if eligible.is_empty():
		return false

	var serial := int(pass_state.get("daily_reroll_serial", 0)) + 1
	var seed := absi(hash("%s:%s:%d" % [
		String(state.get("airport_id", "airport")),
		String(pass_state.get("daily_key", "")),
		serial
	]))
	var template := eligible[seed % eligible.size()]
	daily[target_index] = _mission_from_template(
		template,
		level,
		"daily",
		String(pass_state.get("daily_key", "")),
		serial
	)
	pass_state["daily"] = daily
	pass_state["daily_reroll_serial"] = serial
	if use_ad:
		pass_state["ad_reroll_used"] = true
	else:
		pass_state["free_reroll_used"] = true
	state["mission_pass"] = pass_state
	return true

static func claim_pass_reward(
	state: Dictionary,
	tier_number: int,
	track: String
) -> Dictionary:
	if track not in ["free", "premium"]:
		return {}
	var pass_state: Dictionary = state.get("mission_pass", {})
	var tier := MissionPassCatalog.tier(tier_number)
	if tier.is_empty() or int(pass_state.get("points", 0)) < int(tier.get("points", 0)):
		return {}
	if track == "premium" and not bool(pass_state.get("premium", false)):
		return {}
	var claim_key: String = "claimed_" + String(track)
	var claimed: Dictionary = pass_state.get(claim_key, {})
	if bool(claimed.get(str(tier_number), false)):
		return {}

	var next := state.duplicate(true)
	var next_pass: Dictionary = next.get("mission_pass", {})
	var reward: Dictionary = tier.get(track, {})
	_apply_reward(next, reward)
	var next_claimed: Dictionary = next_pass.get(claim_key, {})
	next_claimed[str(tier_number)] = true
	next_pass[claim_key] = next_claimed
	next["mission_pass"] = next_pass
	_sync_aero_wallet(next)
	return next

static func claim_all_available(state: Dictionary) -> Dictionary:
	var pass_state: Dictionary = state.get("mission_pass", {})
	var points := int(pass_state.get("points", 0))
	var premium := bool(pass_state.get("premium", false))
	var next := state.duplicate(true)
	var changed := false
	for tier_number in range(1, MissionPassCatalog.TIERS + 1):
		var tier := MissionPassCatalog.tier(tier_number)
		if points < int(tier.get("points", 0)):
			break
		for track in ["free", "premium"]:
			if track == "premium" and not premium:
				continue
			var next_pass: Dictionary = next.get("mission_pass", {})
			var claim_key: String = "claimed_" + String(track)
			var claimed: Dictionary = next_pass.get(claim_key, {})
			if bool(claimed.get(str(tier_number), false)):
				continue
			_apply_reward(next, tier.get(track, {}))
			claimed[str(tier_number)] = true
			next_pass[claim_key] = claimed
			next["mission_pass"] = next_pass
			changed = true
	if not changed:
		return {}
	_sync_aero_wallet(next)
	return next

static func grant_verified_product(state: Dictionary, product_id: String) -> Dictionary:
	var product := MissionPassCatalog.product(product_id)
	if product.is_empty():
		return {}
	var next := state.duplicate(true)
	if bool(product.get("premium_pass", false)):
		var pass_state: Dictionary = next.get("mission_pass", {})
		pass_state["premium"] = true
		next["mission_pass"] = pass_state
	elif int(product.get("aero_tokens", 0)) > 0:
		next["aero_tokens"] = int(next.get("aero_tokens", next.get("gems", 0))) + int(product["aero_tokens"])
	else:
		return {}
	_sync_aero_wallet(next)
	return next

static func aero_tokens_for_level_range(old_level: int, new_level: int) -> int:
	if new_level <= old_level:
		return 0
	var total := 0
	for reached_level in range(maxi(old_level + 1, 2), new_level + 1):
		total += 1
		if reached_level % 5 == 0:
			total += 2
	return total



static func seconds_until_daily_reset(unix_time: float) -> int:
	var now := maxi(int(unix_time), 0)
	var elapsed_today := now % SECONDS_PER_DAY
	return SECONDS_PER_DAY - elapsed_today if elapsed_today > 0 else SECONDS_PER_DAY

static func seconds_until_next_week_set(unix_time: float) -> int:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	var day := maxi(int(date.get("day", 1)), 1)
	if day >= 29:
		return seconds_until_month_reset(unix_time)
	var boundary_day := 8
	if day >= 22:
		boundary_day = 29
	elif day >= 15:
		boundary_day = 22
	elif day >= 8:
		boundary_day = 15
	var target := {
		"year": int(date.get("year", 1970)),
		"month": int(date.get("month", 1)),
		"day": boundary_day,
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	return maxi(int(Time.get_unix_time_from_datetime_dict(target)) - int(unix_time), 0)

static func seconds_until_month_reset(unix_time: float) -> int:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	var year := int(date.get("year", 1970))
	var month := int(date.get("month", 1)) + 1
	if month > 12:
		month = 1
		year += 1
	var target := {
		"year": year,
		"month": month,
		"day": 1,
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	return maxi(int(Time.get_unix_time_from_datetime_dict(target)) - int(unix_time), 0)

static func format_remaining(seconds: int) -> String:
	var remaining := maxi(seconds, 0)
	var days := int(remaining / SECONDS_PER_DAY)
	var hours := int((remaining % SECONDS_PER_DAY) / 3600)
	var minutes := int((remaining % 3600) / 60)
	if days > 0:
		return "%dd %02dh" % [days, hours]
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes

static func pass_level(state: Dictionary) -> int:
	var pass_state: Dictionary = state.get("mission_pass", {})
	return mini(
		int(floor(float(pass_state.get("points", 0)) / float(MissionPassCatalog.POINTS_PER_TIER))),
		MissionPassCatalog.TIERS
	)

static func claimable_count(state: Dictionary) -> int:
	var pass_state: Dictionary = state.get("mission_pass", {})
	var points := int(pass_state.get("points", 0))
	var premium := bool(pass_state.get("premium", false))
	var count := 0
	for tier_number in range(1, MissionPassCatalog.TIERS + 1):
		var tier := MissionPassCatalog.tier(tier_number)
		if points < int(tier.get("points", 0)):
			break
		if not bool((pass_state.get("claimed_free", {}) as Dictionary).get(str(tier_number), false)):
			count += 1
		if premium and not bool((pass_state.get("claimed_premium", {}) as Dictionary).get(str(tier_number), false)):
			count += 1
	return count

static func completed_daily_count(state: Dictionary) -> int:
	var count := 0
	for mission in (state.get("mission_pass", {}) as Dictionary).get("daily", []):
		if bool(mission.get("awarded", false)):
			count += 1
	return count

static func current_week_completed_count(state: Dictionary, unix_time: float) -> int:
	var key := _week_key(unix_time)
	var count := 0
	for mission in (state.get("mission_pass", {}) as Dictionary).get("weekly", []):
		if String(mission.get("period_key", "")) == key and bool(mission.get("awarded", false)):
			count += 1
	return count

static func _advance_missions(
	missions: Array,
	event_kind: String,
	payload: Dictionary,
	point_value: int
) -> Dictionary:
	var result := {"changed": false, "points_added": 0, "completed": []}
	for index in range(missions.size()):
		var mission: Dictionary = missions[index]
		if bool(mission.get("awarded", false)):
			continue
		var increment := 0
		var metric := String(mission.get("metric", ""))
		match metric:
			"flights":
				if event_kind == "flight":
					increment = 1
			"passengers":
				if event_kind == "flight":
					increment = maxi(int(payload.get("passengers", 0)), 0)
			"coins":
				if event_kind in ["flight", "npc_service"]:
					increment = maxi(int(payload.get("coins", 0)), 0)
			"xp":
				if event_kind in ["flight", "npc_service"]:
					increment = maxi(int(payload.get("xp", 0)), 0)
			"npc_services":
				if event_kind == "npc_service":
					increment = 1
			"passive_passengers":
				if event_kind == "passive_passengers":
					increment = maxi(int(payload.get("amount", 0)), 0)
			"flight_minutes":
				if event_kind == "flight":
					increment = maxi(int(payload.get("flight_minutes", 0)), 0)
			"flight_distance":
				if event_kind == "flight":
					increment = maxi(int(payload.get("distance_km", 0)), 0)
			"mastery_minutes":
				if event_kind == "flight":
					increment = maxi(int(payload.get("mastery_minutes", 0)), 0)
			"resources":
				if event_kind == "flight":
					increment = maxi(int(payload.get("resources", 0)), 0)
			"unique_countries":
				if event_kind == "flight":
					var country := String(payload.get("country", ""))
					if not country.is_empty():
						var seen: Dictionary = mission.get("seen", {})
						if not bool(seen.get(country, false)):
							seen[country] = true
							mission["seen"] = seen
							increment = 1
		if increment <= 0:
			continue
		var target := maxi(int(mission.get("target", 1)), 1)
		mission["progress"] = mini(int(mission.get("progress", 0)) + increment, target)
		missions[index] = mission
		result["changed"] = true
		if int(mission["progress"]) >= target:
			mission["completed"] = true
			mission["awarded"] = true
			result["points_added"] = int(result["points_added"]) + point_value
			(result["completed"] as Array).append(String(mission.get("id", "")))
		missions[index] = mission
	return result

static func _all_awarded(missions: Array) -> bool:
	if missions.is_empty():
		return false
	for mission in missions:
		if not bool(mission.get("awarded", false)):
			return false
	return true

static func _generate_missions(
	templates: Array[Dictionary],
	count: int,
	level: int,
	period_type: String,
	period_key: String,
	airport_id: String
) -> Array:
	var eligible: Array[Dictionary] = []
	for template in templates:
		if level >= int(template.get("min_level", 1)):
			eligible.append(template)
	var result: Array = []
	if eligible.is_empty():
		return result
	var start := absi(hash("%s:%s:%s" % [airport_id, period_type, period_key])) % eligible.size()
	for offset in range(mini(count, eligible.size())):
		var template := eligible[(start + offset) % eligible.size()]
		result.append(_mission_from_template(template, level, period_type, period_key, 0))
	return result

static func _mission_from_template(
	template: Dictionary,
	level: int,
	period_type: String,
	period_key: String,
	serial: int
) -> Dictionary:
	var target := MissionPassCatalog.target_for(template, level)
	var suffix := ":%d" % serial if serial > 0 else ""
	return {
		"id": "%s:%s:%s%s" % [period_type, period_key, String(template.get("id", "mission")), suffix],
		"template_id": String(template.get("id", "")),
		"period_type": period_type,
		"period_key": period_key,
		"metric": String(template.get("metric", "")),
		"title": String(template.get("title", "Mission")),
		"description": MissionPassCatalog.mission_text(String(template.get("metric", "")), target),
		"target": target,
		"progress": 0,
		"completed": false,
		"awarded": false,
		"seen": {}
	}

static func _auto_claim_expiring_pass(state: Dictionary, pass_state: Dictionary) -> void:
	var points := int(pass_state.get("points", 0))
	var premium := bool(pass_state.get("premium", false))
	var claimed_free: Dictionary = pass_state.get("claimed_free", {})
	var claimed_premium: Dictionary = pass_state.get("claimed_premium", {})
	for tier_number in range(1, MissionPassCatalog.TIERS + 1):
		var tier := MissionPassCatalog.tier(tier_number)
		if points < int(tier.get("points", 0)):
			break
		if not bool(claimed_free.get(str(tier_number), false)):
			_apply_reward(state, tier.get("free", {}))
			claimed_free[str(tier_number)] = true
		if premium and not bool(claimed_premium.get(str(tier_number), false)):
			_apply_reward(state, tier.get("premium", {}))
			claimed_premium[str(tier_number)] = true
	pass_state["claimed_free"] = claimed_free
	pass_state["claimed_premium"] = claimed_premium
	state["mission_pass"] = pass_state
	_sync_aero_wallet(state)

static func _apply_reward(state: Dictionary, reward: Dictionary) -> void:
	var grants: Dictionary = reward.get("grants", {})
	state["coins"] = int(state.get("coins", 0)) + maxi(int(grants.get("coins", 0)), 0)
	state["xp"] = int(state.get("xp", 0)) + maxi(int(grants.get("xp", 0)), 0)
	state["pending_passengers"] = int(state.get("pending_passengers", 0)) + maxi(int(grants.get("passengers", 0)), 0)
	state["aero_tokens"] = int(state.get("aero_tokens", state.get("gems", 0))) + maxi(int(grants.get("aero_tokens", 0)), 0)
	state["resource_choice_crates"] = int(state.get("resource_choice_crates", 0)) + maxi(int(grants.get("resource_crates", 0)), 0)
	var boosters: Dictionary = state.get("booster_inventory", {})
	for key in ["booster_ground_crew", "booster_tailwind", "booster_gold", "booster_xp", "booster_passengers"]:
		var amount := maxi(int(grants.get(key, 0)), 0)
		if amount > 0:
			boosters[key] = int(boosters.get(key, 0)) + amount
	state["booster_inventory"] = boosters
	var cosmetics: Dictionary = state.get("pass_cosmetics", {})
	var month := String((state.get("mission_pass", {}) as Dictionary).get("month_key", "season"))
	if int(grants.get("cosmetic_free", 0)) > 0:
		cosmetics[month + ":free_decoration"] = true
	if int(grants.get("cosmetic_premium", 0)) > 0:
		cosmetics[month + ":premium_set"] = true
	state["pass_cosmetics"] = cosmetics

static func _sync_aero_wallet(state: Dictionary) -> void:
	state["gems"] = int(state.get("aero_tokens", state.get("gems", 0)))

static func _day_key(unix_time: float) -> String:
	return Time.get_date_string_from_unix_time(int(unix_time))

static func _month_key(unix_time: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d" % [int(date.get("year", 1970)), int(date.get("month", 1))]

static func _week_key(unix_time: float) -> String:
	return "%s-W%d" % [_month_key(unix_time), _month_week_index(unix_time)]

static func _month_week_index(unix_time: float) -> int:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return clampi(int(floor(float(maxi(int(date.get("day", 1)), 1) - 1) / 7.0)) + 1, 1, 5)
