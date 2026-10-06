extends "res://src/main/Main.gd"

# A narrow scene adapter keeps career/NPC state out of the large airport-operations controller.
var progression: Dictionary = {}
var progression_ready := false
var legacy_airport := false
var career_screen: AirportCareerScreen
var career_pin: Button
var mission_pass_screen: MissionPassScreen
var charter_screen: CharterScreen
var alliance_operations_screen: AllianceOperationsScreen
var airport_challenge_screen: AirportChallengeScreen
var dispatch_challenge_screen: DispatchChallengeScreen
var activities_hub_screen: ActivitiesHubScreen
var activity_intro_screen: ActivityIntroScreen
var mission_pin: Button
var mission_billing_bridge: MissionProductBillingBridge
var pending_mission_ad_id := ""
var npc_director := NpcTrafficDirector.new()
var deployed_owned: Dictionary = {}
var deploying := false
var checkpoint_elapsed := 0.0
var career_refresh_elapsed := 0.0
var restoring_wallet := false
var next_analytics_refresh_ms := 0
var last_booster_signature := -1

func _ready() -> void:
	legacy_airport = ProfileStore.has_airport()
	super._ready()

func _start_gameplay() -> void:
	if gameplay_started:
		return
	var airport_id := String(current_profile.get("airport_id", ""))
	progression = AirportProgressionStore.load_state(airport_id)
	if progression.is_empty():
		if AirportProgressionStore.has_state(airport_id):
			hud.set_operation_status("Career save could not be read. Your existing save has not been overwritten.", "warning")
			return
		progression = AirportProgressionRules.new_state(airport_id, 4 if legacy_airport else 1)
		progression["home_country_id"] = String(
			current_profile.get(
				"country_id",
				DestinationCatalog.DEFAULT_HOME_COUNTRY_ID
			)
		)
		progression["passenger_balance"] = float(current_profile.get("passenger_balance", 20))
		if not AirportProgressionStore.save_state(progression):
			hud.set_operation_status("Cannot save airport progression. Check device storage.", "warning")
			return
	var profile_home_country := String(
		current_profile.get(
			"country_id",
			DestinationCatalog.DEFAULT_HOME_COUNTRY_ID
		)
	)
	var home_state_changed := false
	if String(progression.get("home_country_id", "")).is_empty():
		progression["home_country_id"] = profile_home_country
		home_state_changed = true
	DestinationCatalog.configure_home_country(
		String(progression.get("home_country_id", profile_home_country))
	)
	var stored_level := AirportProgressionRules.level_for_xp(int(progression.get("xp", 0)))
	var mission_state_changed := MissionPassRules.ensure_state(
		progression,
		Time.get_unix_time_from_system(),
		stored_level
	)
	if home_state_changed:
		mission_state_changed = true
	var updated_level := AirportProgressionRules.level_for_xp(int(progression.get("xp", 0)))
	var rollover_aero := MissionPassRules.aero_tokens_for_level_range(
		stored_level,
		updated_level
	)
	if rollover_aero > 0:
		progression["aero_tokens"] = int(progression.get("aero_tokens", 0)) + rollover_aero
		progression["gems"] = int(progression["aero_tokens"])
		mission_state_changed = true
	if mission_state_changed:
		if not AirportProgressionStore.save_state(progression):
			hud.set_operation_status("Mission progress could not be initialized safely.", "warning")
			return
	coins = int(progression.get("coins", coins))
	gems = int(progression.get("aero_tokens", progression.get("gems", gems)))
	player_xp = int(progression.get("xp", 0))
	player_level = updated_level
	progression_ready = true
	npc_director.remaining = maxf(float(progression.get("npc_remaining", 90.0)), 0.0)
	npc_director.last_npc = String(progression.get("npc_last", ""))
	npc_director.enabled = bool(progression.get("npc_enabled", true))
	super._start_gameplay()
	restoring_wallet = true
	passenger_economy.set_passengers(float(progression.get("passenger_balance", 20.0)))
	restoring_wallet = false
	career_screen = AirportCareerScreen.new()
	career_screen.claim_requested.connect(_claim_career_reward)
	career_screen.guidance_requested.connect(_guide_career)
	career_screen.aircraft_purchase_requested.connect(_purchase_career_aircraft)
	career_screen.npc_toggle_requested.connect(_toggle_npc_traffic)
	career_screen.activity_requested.connect(
		_on_career_activity_requested
	)
	add_child(career_screen)
	mission_pass_screen = MissionPassScreen.new()
	mission_pass_screen.reroll_requested.connect(_on_mission_reroll_requested)
	mission_pass_screen.guidance_requested.connect(_on_mission_guidance_requested)
	mission_pass_screen.pass_reward_claim_requested.connect(_on_pass_reward_claim_requested)
	mission_pass_screen.claim_all_requested.connect(_on_pass_claim_all_requested)
	mission_pass_screen.product_purchase_requested.connect(_on_mission_product_purchase_requested)
	mission_pass_screen.booster_activate_requested.connect(_on_booster_activate_requested)
	mission_pass_screen.resource_choice_requested.connect(_on_pass_resource_choice_requested)
	add_child(mission_pass_screen)

	charter_screen = CharterScreen.new()
	charter_screen.accept_requested.connect(_on_charter_accept_requested)
	charter_screen.claim_requested.connect(_on_charter_claim_requested)
	charter_screen.close_requested.connect(_on_charter_closed)
	add_child(charter_screen)

	alliance_operations_screen = AllianceOperationsScreen.new()
	alliance_operations_screen.claim_requested.connect(
		_on_alliance_milestone_claim_requested
	)
	alliance_operations_screen.close_requested.connect(
		_on_alliance_operations_closed
	)
	add_child(alliance_operations_screen)
	if social_airport_screen != null:
		social_airport_screen.alliance_operations_requested.connect(
			_on_alliance_operations_requested
		)

	airport_challenge_screen = AirportChallengeScreen.new()
	airport_challenge_screen.claim_requested.connect(
		_on_airport_challenge_claim_requested
	)
	airport_challenge_screen.close_requested.connect(
		_on_airport_challenge_closed
	)
	add_child(airport_challenge_screen)

	dispatch_challenge_screen = DispatchChallengeScreen.new()
	dispatch_challenge_screen.start_requested.connect(
		_on_dispatch_start_requested
	)
	dispatch_challenge_screen.claim_requested.connect(
		_on_dispatch_claim_requested
	)
	dispatch_challenge_screen.close_requested.connect(
		_on_dispatch_closed
	)
	add_child(dispatch_challenge_screen)

	activities_hub_screen = ActivitiesHubScreen.new()
	activities_hub_screen.mode_requested.connect(
		_on_activity_mode_requested
	)
	activities_hub_screen.close_requested.connect(
		_on_activities_hub_closed
	)
	add_child(activities_hub_screen)

	activity_intro_screen = ActivityIntroScreen.new()
	activity_intro_screen.continue_requested.connect(
		_on_activity_intro_continue
	)
	activity_intro_screen.close_requested.connect(
		_on_activity_intro_closed
	)
	add_child(activity_intro_screen)

	mission_billing_bridge = MissionProductBillingBridge.new()
	mission_billing_bridge.purchase_verified.connect(_on_mission_purchase_verified)
	mission_billing_bridge.unavailable.connect(_on_mission_billing_unavailable)
	add_child(mission_billing_bridge)
	if rewarded_passenger_ad_bridge != null:
		rewarded_passenger_ad_bridge.action_reward_granted.connect(_on_rewarded_action_completed)
		rewarded_passenger_ad_bridge.action_unavailable.connect(_on_rewarded_action_unavailable)
	_install_career_pin()
	_apply_live_boosters(true)
	_refresh_career_ui()
	_refresh_mission_ui()
	if CharterRules.ensure_state(progression, player_level, Time.get_unix_time_from_system()):
		_save_checkpoint()
	_refresh_charter_ui()
	if AllianceOperationsRules.ensure_state(
		progression,
		Time.get_unix_time_from_system()
	):
		_save_checkpoint()
	_refresh_alliance_operations_ui()
	if AirportChallengeRules.ensure_state(
		progression,
		player_level,
		Time.get_unix_time_from_system()
	):
		_save_checkpoint()
	_refresh_airport_challenge_ui()
	if DispatchChallengeRules.ensure_state(
		progression,
		player_level,
		Time.get_unix_time_from_system()
	):
		_save_checkpoint()
	_refresh_dispatch_ui()
	_refresh_activities_hub()
	_drain_passenger_rewards()
	_drain_resource_choice_grants()

func _process(delta: float) -> void:
	super._process(delta)
	if not gameplay_started or not progression_ready or delta <= 0.0:
		return
	var own_waiting := false
	for request in pending_arrivals:
		var plane: AircraftPrototype = request.get("aircraft")
		if is_instance_valid(plane) and not plane.is_social_visitor():
			own_waiting = true
			break
	var npc_active := false
	for value in social_visitor_aircraft.values():
		var plane := value as AircraftPrototype
		if is_instance_valid(plane) and _is_npc(plane):
			npc_active = true
			break
	var contact := npc_director.advance(delta, player_level, airport_grid, stand_occupancy,
		own_waiting, npc_active, social_visitor_aircraft.size())
	if not contact.is_empty():
		_start_npc_visit(contact)
	checkpoint_elapsed += delta
	career_refresh_elapsed += delta
	if checkpoint_elapsed >= 5.0:
		checkpoint_elapsed = 0.0
		_save_checkpoint()
	if career_refresh_elapsed >= 1.0:
		career_refresh_elapsed = 0.0
		_deploy_reserve_aircraft()
		_drain_passenger_rewards()
		_drain_resource_choice_grants()
		_apply_live_boosters()
		var charter_changed := CharterRules.ensure_state(
			progression,
			player_level,
			Time.get_unix_time_from_system()
		)
		if charter_changed:
			_save_checkpoint()
		_refresh_career_ui()
		_refresh_mission_ui()
		_refresh_charter_ui()
		var alliance_changed := AllianceOperationsRules.ensure_state(
			progression,
			Time.get_unix_time_from_system()
		)
		if alliance_changed:
			_save_checkpoint()
		_refresh_alliance_operations_ui()
		var challenge_changed := AirportChallengeRules.ensure_state(
			progression,
			player_level,
			Time.get_unix_time_from_system()
		)
		if challenge_changed:
			_save_checkpoint()
		_refresh_airport_challenge_ui()
		var dispatch_changed := DispatchChallengeRules.ensure_state(
			progression,
			player_level,
			Time.get_unix_time_from_system()
		)
		if dispatch_changed:
			_save_checkpoint()
			var dispatch_data := _dispatch_snapshot()
			if String(dispatch_data.get("status", "")) == "READY":
				hud.set_operation_status(
					"Dispatch complete • %d pts • %s • max combo x%d" % [
						int(dispatch_data.get("score", 0)),
						String(dispatch_data.get("tier_name", "No medal")),
						int(dispatch_data.get("max_combo", 0))
					],
					"success"
				)
		_refresh_dispatch_ui()
		_refresh_activities_hub()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		if progression_ready and is_instance_valid(passenger_economy):
			_save_checkpoint()

func _install_career_pin() -> void:
	# Replace the old static objective with compact career + mission actions.
	for child in hud.interface_root.get_children():
		if not child is PanelContainer:
			continue
		for label in child.get_children():
			if label is Label and label.text.begins_with("BUILD YOUR AIRPORT"):
				child.remove_child(label)
				label.queue_free()
				child.offset_left = -440
				var actions := HBoxContainer.new()
				actions.add_theme_constant_override("separation", 7)
				child.add_child(actions)
				career_pin = Button.new()
				career_pin.clip_text = true
				career_pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				career_pin.custom_minimum_size = Vector2(230, 48)
				career_pin.add_theme_font_size_override("font_size", 12)
				GameUIStyle.apply_button(career_pin, "nav", true)
				career_pin.pressed.connect(_open_career)
				actions.add_child(career_pin)
				mission_pin = Button.new()
				mission_pin.clip_text = true
				mission_pin.custom_minimum_size = Vector2(165, 48)
				mission_pin.add_theme_font_size_override("font_size", 12)
				GameUIStyle.apply_button(mission_pin, "nav", true)
				mission_pin.pressed.connect(
					_request_activity_entry.bind("missions")
				)
				actions.add_child(mission_pin)
				return

func _spawn_aircraft_demos() -> void:
	_deploy_reserve_aircraft()

func _deploy_reserve_aircraft() -> void:
	if not progression_ready or deploying or ground_services == null:
		return
	deploying = true
	var runtime: Dictionary = progression.get("aircraft_runtime", {})
	for item in progression.get("owned_aircraft", []):
		var uid := String(item.get("uid", ""))
		if uid.is_empty() or deployed_owned.has(uid):
			continue
		var type_id := String(item.get("type", ""))
		var profile := AircraftCatalog.get_profile(type_id)
		if profile.is_empty():
			continue
		var saved: Dictionary = runtime.get(uid, {})
		var phase := String(saved.get("phase", ""))
		var returning := phase in ["EN_ROUTE", "HOLDING_FOR_ARRIVAL", "APPROACH", "LANDING_ROLL", "TAXIING_IN"]
		var route_info: Dictionary = {}
		if not returning:
			var stands := NpcTrafficDirector.free_ready_stands(airport_grid, String(profile["size"]), stand_occupancy)
			if stands.is_empty():
				continue
			route_info = airport_grid.get_departure_route_for_stand(stands[0], String(profile["size"]))
		var aircraft := CareerAircraft.new()
		aircraft.configure_aircraft_type(type_id)
		aircraft.configure_taxi_traffic(taxi_traffic)
		# Player-owned aircraft use the tactile handling loop by default.
		# The second flag is the future paid size-class automation hook.
		aircraft.configure_handling_mode(
			true,
			false
		)
		aircraft.handling_action_requested.connect(
			_on_aircraft_handling_action_requested
		)
		aircraft.name = "SO-%03d" % int(uid.trim_prefix("owned-"))
		aircraft.z_index = 80
		aircraft.set_meta("owned_uid", uid)
		aircraft.set_meta("career_flight_token", String(saved.get("token", "")))
		aircraft.set_meta("passengers_paid", bool(saved.get("paid", false)))
		var plan: Dictionary = saved.get("plan", {})
		if plan.is_empty() and runtime.is_empty() and uid in ["owned-1", "owned-2"]:
			plan = _create_current_flight_plan(
				profile,
				DestinationCatalog.starter_destination(profile)
			)
		aircraft.assign_flight_plan(plan)
		var label := String(aircraft.name)
		aircraft.state_changed.connect(_on_demo_aircraft_state_changed.bind(aircraft, label))
		aircraft.departed.connect(_on_demo_aircraft_departed.bind(aircraft, label))
		aircraft.arrival_requested.connect(_on_demo_arrival_requested.bind(aircraft, label))
		aircraft.arrival_completed.connect(_on_demo_arrival_completed.bind(aircraft, label))
		add_child(aircraft)
		deployed_owned[uid] = aircraft
		aircraft_demos.append(aircraft)
		_apply_event_visual_to_aircraft(aircraft, current_event_snapshot)
		if returning:
			aircraft.visible = false
			var elapsed := maxf(Time.get_unix_time_from_system() - float(saved.get("saved_at", Time.get_unix_time_from_system())), 0.0)
			aircraft.flight_remaining = maxf(float(saved.get("remaining", 0.0)) - elapsed, 0.0)
			if phase == "EN_ROUTE" and aircraft.flight_remaining > 0.0:
				aircraft._set_state("EN_ROUTE")
			else:
				aircraft._set_state("HOLDING_FOR_ARRIVAL")
				_on_demo_arrival_requested(aircraft, label)
		else:
			var stand_uid := int(route_info.get("stand_uid", -1))
			aircraft.set_departure_route(route_info["route"], String(profile["size"]), stand_uid, int(route_info.get("runway_uid", -1)))
			stand_occupancy[stand_uid] = aircraft
			ground_services.request_turnaround(
				aircraft,
				label,
				false,
				aircraft.uses_manual_handling()
			)
	deploying = false

func _release_stand(aircraft: AircraftPrototype) -> void:
	super._release_stand(aircraft)
	call_deferred("_deploy_reserve_aircraft")

func _on_demo_aircraft_state_changed(state: String, aircraft: AircraftPrototype, label: String) -> void:
	super._on_demo_aircraft_state_changed(state, aircraft, label)
	if not aircraft.is_social_visitor() and state == "LOADING":
		aircraft.set_meta("passengers_paid", true)

func _on_passenger_boarding_requested(aircraft: AircraftPrototype, label: String) -> void:
	if (
		is_instance_valid(aircraft)
		and not aircraft.is_social_visitor()
		and bool(
			aircraft.get_meta(
				"passengers_paid",
				false
			)
		)
		and (
			not aircraft.uses_manual_handling()
			or aircraft.uses_handling_automation()
		)
	):
		aircraft.clear_handling_action()
		ground_services.approve_passenger_loading(aircraft)
		return
	super._on_passenger_boarding_requested(
		aircraft,
		label
	)
	_save_checkpoint()

func _on_demo_aircraft_departed(aircraft: AircraftPrototype, label: String) -> void:
	var sequence := int(progression.get("flight_sequence", 0)) + 1
	progression["flight_sequence"] = sequence
	aircraft.set_meta("career_flight_token", "flight:%s:%d" % [String(progression.get("airport_id", "")), sequence])
	super._on_demo_aircraft_departed(aircraft, label)
	var booster_profile := MissionBoosterRules.active_profile(
		progression,
		Time.get_unix_time_from_system()
	)
	var duration_multiplier := float(booster_profile.get("flight_duration", 1.0))
	if duration_multiplier < 0.999:
		aircraft.flight_remaining = maxf(
			aircraft.flight_remaining * duration_multiplier,
			1.0
		)
		hud.set_operation_status(
			"%s departed • Tailwind active • travel time −10%%" % label,
			"success"
		)
	_record_dispatch_action("departure")
	_save_checkpoint()

func _apply_completed_flight_reward(aircraft: AircraftPrototype, label: String) -> void:
	var token := String(aircraft.get_meta("career_flight_token", ""))
	if token.is_empty() or (progression.get("seen_events", {}) as Dictionary).has(token):
		return
	var plan := aircraft.get_flight_plan()
	var booster_profile := MissionBoosterRules.active_profile(
		progression,
		Time.get_unix_time_from_system()
	)
	var boosted_reward := false
	var gold_multiplier := float(booster_profile.get("flight_gold", 1.0))
	var xp_multiplier := float(booster_profile.get("flight_xp", 1.0))
	if gold_multiplier > 1.001:
		plan["coin_reward"] = int(round(float(plan.get("coin_reward", 0)) * gold_multiplier))
		boosted_reward = true
	if xp_multiplier > 1.001:
		plan["xp_reward"] = int(round(float(plan.get("xp_reward", 0)) * xp_multiplier))
		boosted_reward = true
	if boosted_reward:
		aircraft.assign_flight_plan(plan)
	var boarded := aircraft.get_boarded_passengers()
	var coins_before := coins
	var xp_before := player_xp
	var resources_before := _resource_inventory_total()
	var mastery_before := _mastery_hours_for_aircraft(aircraft)
	super._apply_completed_flight_reward(aircraft, label)
	var resources_after := _resource_inventory_total()
	var mastery_after := _mastery_hours_for_aircraft(aircraft)
	AirportProgressionRules.record_event(progression, {"id": token, "kind": "flight_return",
		"aircraft": aircraft.aircraft_type_id, "country": plan.get("country_code", ""), "visitor": false}, player_level)
	var challenge_payload := {
		"passengers": boarded,
		"coins": maxi(coins - coins_before, 0),
		"xp": maxi(player_xp - xp_before, 0),
		"country": String(plan.get("country_code", "")),
		"flight_minutes": maxi(int(round(float(plan.get("duration_seconds", 0.0)) / 60.0)), 0),
		"distance_km": maxi(int(round(float(plan.get("distance_km", 0.0)))), 0),
		"mastery_minutes": maxi(int(round(maxf(mastery_after - mastery_before, 0.0) * 60.0)), 0),
		"resources": maxi(resources_after - resources_before, 0)
	}
	_record_mission_event("flight", challenge_payload)
	var challenge_points := AirportChallengeRules.record_flight(
		progression,
		player_level,
		challenge_payload,
		Time.get_unix_time_from_system()
	)
	if challenge_points > 0:
		_record_mission_event(
			"challenge_points",
			{"points": challenge_points}
		)
		var challenge_theme := AirportChallengeRules.theme_for_week(
			AirportChallengeRules.week_key(Time.get_unix_time_from_system())
		)
		hud.set_operation_status(
			"%s returned • +%d %s points" % [
				label,
				challenge_points,
				String(challenge_theme.get("short_name", "challenge"))
			],
			"success"
		)
	_record_alliance_activity("flight")
	# A completed route is not an implicit order to charge passengers and fly it again.
	aircraft.assign_flight_plan({})
	aircraft.set_meta("passengers_paid", false)
	aircraft.set_meta("career_flight_token", "")
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_alliance_operations_ui()
	_refresh_airport_challenge_ui()
	_record_dispatch_action("return")

func _on_world_map_flight_assignment_requested(aircraft: AircraftPrototype, destination_id: String) -> void:
	if not is_instance_valid(aircraft) or not aircraft.can_change_flight_plan():
		super._on_world_map_flight_assignment_requested(aircraft, destination_id)
		return
	var destination := DestinationCatalog.get_destination(destination_id)
	if destination.is_empty() or player_level < int(destination.get("unlock_level", 1)) or not FlightRules.can_fly(aircraft.get_aircraft_profile(), destination):
		super._on_world_map_flight_assignment_requested(aircraft, destination_id)
		return
	aircraft.set_meta("passengers_paid", false)
	super._on_world_map_flight_assignment_requested(aircraft, destination_id)
	_save_checkpoint()

func _capture_state() -> Dictionary:
	var next := progression.duplicate(true)
	next["coins"] = coins
	next["xp"] = player_xp
	next["gems"] = gems
	next["aero_tokens"] = gems
	if is_instance_valid(passenger_economy):
		next["passenger_balance"] = passenger_economy.passengers
	next["npc_remaining"] = npc_director.remaining
	next["npc_last"] = npc_director.last_npc
	next["npc_enabled"] = npc_director.enabled
	var runtime: Dictionary = next.get("aircraft_runtime", {})
	for uid in deployed_owned:
		var plane := deployed_owned[uid] as AircraftPrototype
		if not is_instance_valid(plane):
			continue
		runtime[uid] = {"phase": plane.state, "plan": plane.get_flight_plan(),
			"remaining": plane.get_flight_remaining_seconds(), "saved_at": Time.get_unix_time_from_system(),
			"paid": bool(plane.get_meta("passengers_paid", false)), "token": String(plane.get_meta("career_flight_token", ""))}
	next["aircraft_runtime"] = runtime
	return next

func _save_checkpoint() -> bool:
	if not progression_ready or restoring_wallet:
		return false
	var next := _capture_state()
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Progress could not be saved. Check device storage before closing the game.", "warning")
		return false
	progression = next
	return true

func _airport_career_snapshot() -> Dictionary:
	var medium_ready := not NpcTrafficDirector.free_ready_stands(airport_grid, "M", {}).is_empty()
	return {"buildings": airport_grid.placed_buildings.duplicate(true),
		"parcels": airport_grid.export_owned_parcels(), "medium_ready": medium_ready}

func _career_snapshot() -> Dictionary:
	return {
		"state": _capture_state(),
		"airport": _airport_career_snapshot(),
		"level": player_level,
		"active_owned": deployed_owned.keys(),
		"npc_enabled": npc_director.enabled,
		"activities": _activities_snapshot()
	}

func _mission_snapshot() -> Dictionary:
	var state := _capture_state()
	state.erase("aircraft_runtime")
	state.erase("npc_remaining")
	state.erase("passenger_balance")
	var weekly: Array = (state.get("mission_pass", {}) as Dictionary).get("weekly", [])
	var current_week := ""
	if not weekly.is_empty():
		current_week = String((weekly[weekly.size() - 1] as Dictionary).get("period_key", ""))
	return {
		"state": state,
		"level": player_level,
		"week_key": current_week,
		"unix_time": float(int(Time.get_unix_time_from_system() / 60.0) * 60),
		"rewarded_ad_connected": rewarded_passenger_ad_bridge != null and rewarded_passenger_ad_bridge.provider_connected,
		"resource_inventory": resource_inventory.duplicate(true),
		"resource_choice_country_codes": _available_resource_choice_country_codes(),
		"billing_connected": mission_billing_bridge != null and mission_billing_bridge.provider_connected
	}

func _refresh_mission_ui() -> void:
	if mission_pass_screen == null or not progression_ready:
		return
	var changed := MissionPassRules.ensure_state(progression, Time.get_unix_time_from_system(), player_level)
	if changed:
		_save_checkpoint()
	mission_pass_screen.set_snapshot(_mission_snapshot())
	var claimable := MissionPassRules.claimable_count(progression)
	var completed := MissionPassRules.completed_daily_count(progression)
	if mission_pin != null:
		mission_pin.text = "MISSIONS\n%d REWARD%s READY" % [claimable, "" if claimable == 1 else "S"] if claimable > 0 else "MISSIONS\nDAILY %d / 4" % completed
		GameUIStyle.apply_button(mission_pin, "gold" if claimable > 0 else "nav", true)
	if hud != null:
		hud.set_mission_activity_attention(claimable > 0)
	hud.set_player_data(player_level, coins, gems)
	hud.set_level_progress(
		player_xp,
		AirportProgressionRules.xp_for_level(player_level),
		AirportProgressionRules.xp_for_level(mini(player_level + 1, AirportProgressionRules.MAX_LEVEL)),
		player_level >= AirportProgressionRules.MAX_LEVEL
	)

func _charter_parcel_owned() -> bool:
	return (airport_grid.export_owned_parcels() as Array).has(
		CharterDistrictLayout.PARCEL_ID
	)


func _charter_parcel_ready() -> bool:
	return bool(
		airport_grid.get_charter_district_activation_status().get(
			"can_activate",
			false
		)
	)


func _charter_snapshot() -> Dictionary:
	return CharterRules.snapshot(
		_capture_state(),
		player_level,
		_charter_parcel_owned(),
		_charter_parcel_ready(),
		Time.get_unix_time_from_system()
	)


func _refresh_charter_ui() -> void:
	if not progression_ready:
		return
	var unlocked := CharterRules.is_unlocked(player_level)
	var active: Dictionary = (
		(progression.get("charter", {}) as Dictionary).get("active", {})
	)
	var attention := String(active.get("phase", "")) == "READY"
	hud.set_charter_available(unlocked, attention)
	if charter_screen != null:
		charter_screen.set_snapshot(_charter_snapshot())
	if airport_grid != null:
		airport_grid.set_charter_visual_state(
			CharterRules.visual_snapshot(
				progression,
				player_level,
				_charter_parcel_owned(),
				Time.get_unix_time_from_system()
			)
		)


func _on_charter_accept_requested(offer_id: String) -> void:
	var activation := airport_grid.get_charter_district_activation_status()
	var next := CharterRules.accept_contract(
		_capture_state(),
		offer_id,
		player_level,
		bool(activation.get("can_activate", false)),
		Time.get_unix_time_from_system()
	)
	if next.is_empty():
		hud.set_operation_status(
			String(activation.get("reason", "Cargo Charter cannot start right now.")),
			"warning"
		)
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Charter was not accepted because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	if MissionPassRules.enable_activity_missions(
		progression,
		"charter"
	):
		_save_checkpoint()
	_refresh_charter_ui()
	var accepted_active: Dictionary = (
		(progression.get("charter", {}) as Dictionary).get("active", {})
	)
	hud.set_operation_status(
		"%s accepted • %s • loading started" % [
			String(accepted_active.get("contract_type_name", "Cargo Charter")),
			String(accepted_active.get("city", "route"))
		],
		"success"
	)


func _on_charter_claim_requested() -> void:
	var result := CharterRules.claim_contract(
		_capture_state(),
		player_level,
		Time.get_unix_time_from_system()
	)
	if result.is_empty():
		hud.set_operation_status("Charter reward is not ready yet.", "warning")
		return
	var next: Dictionary = result.get("state", {})
	var reward: Dictionary = result.get("reward", {})
	if next.is_empty() or not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Charter reward remains available because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	_record_mission_event(
		"charter_complete",
		{
			"resource_amount": int(
				reward.get("resource_amount", 1)
			)
		}
	)
	_update_level()
	_save_checkpoint()
	_drain_resource_choice_grants()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_charter_ui()
	hud.set_player_data(player_level, coins, gems)
	ProfileStore.add_economy_stats({
		"charters_completed": 1,
		"charter_coins": int(reward.get("coins", 0)),
		"charter_xp": int(reward.get("xp", 0)),
		"resources_earned": maxi(int(reward.get("resource_amount", 1)), 0)
	})
	hud.set_operation_status(
		"%s complete • %s • +%d coins • +%d XP • +%d %s" % [
			String(reward.get("contract_type_name", "Cargo Charter")),
			String(reward.get("city", "route")),
			int(reward.get("coins", 0)),
			int(reward.get("xp", 0)),
			int(reward.get("resource_amount", 1)),
			String(reward.get("resource_name", "resource"))
		],
		"success"
	)


func _on_charter_closed() -> void:
	hud.set_operation_status("Returned to airport operations.")


func _alliance_operations_snapshot() -> Dictionary:
	return AllianceOperationsRules.snapshot(
		_capture_state(),
		Time.get_unix_time_from_system(),
		social_airport_service != null
			and social_airport_service.provider_connected,
		social_airport_service != null
			and social_airport_service.local_simulation_enabled
	)


func _refresh_alliance_operations_ui() -> void:
	if alliance_operations_screen == null or not progression_ready:
		return
	alliance_operations_screen.set_snapshot(
		_alliance_operations_snapshot()
	)
	if hud != null:
		hud.set_alliance_activity_attention(
			ActivityProgressionRules.is_level_unlocked(
				"alliance",
				player_level
			)
			and _has_alliance_contact()
			and AllianceOperationsRules.claimable_count(
				progression,
				Time.get_unix_time_from_system()
			) > 0
		)


func _on_alliance_operations_requested() -> void:
	if social_airport_screen != null:
		social_airport_screen.close_screen()
	_request_activity_entry("alliance")


func _on_alliance_operations_closed() -> void:
	if social_airport_screen != null and social_airport_service != null:
		social_airport_screen.open_screen(
			_social_only_snapshot(
				social_airport_service.get_snapshot()
			)
		)


func _on_alliance_milestone_claim_requested(
	milestone_id: String
) -> void:
	var result := AllianceOperationsRules.claim_milestone(
		_capture_state(),
		milestone_id,
		Time.get_unix_time_from_system()
	)
	if result.is_empty():
		hud.set_operation_status(
			"Alliance milestone is not ready to claim.",
			"warning"
		)
		return
	var next: Dictionary = result.get("state", {})
	var reward: Dictionary = result.get("reward", {})
	if next.is_empty() or not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Alliance reward remains available because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_charter_ui()
	_refresh_alliance_operations_ui()
	hud.set_player_data(player_level, coins, gems)
	hud.set_operation_status(
		"%s • %s claimed • +%d coins • +%d XP" % [
			String(reward.get("project_name", "Alliance Operations")),
			String(reward.get("name", "Alliance milestone")),
			int(reward.get("coins", 0)),
			int(reward.get("xp", 0))
		],
		"success"
	)


func _airport_challenge_snapshot() -> Dictionary:
	return AirportChallengeRules.snapshot(
		_capture_state(),
		player_level,
		Time.get_unix_time_from_system()
	)


func _refresh_airport_challenge_ui() -> void:
	if not progression_ready:
		return
	var data := _airport_challenge_snapshot()
	if airport_challenge_screen != null:
		airport_challenge_screen.set_snapshot(data)
	if hud != null:
		hud.set_challenge_available(
			bool(data.get("unlocked", false)),
			AirportChallengeRules.claimable_count(
				progression,
				player_level,
				Time.get_unix_time_from_system()
			) > 0
		)


func _on_airport_challenge_closed() -> void:
	hud.set_operation_status("Returned to airport operations.")


func _on_airport_challenge_claim_requested(milestone_id: String) -> void:
	var result := AirportChallengeRules.claim_milestone(
		_capture_state(),
		player_level,
		milestone_id,
		Time.get_unix_time_from_system()
	)
	if result.is_empty():
		hud.set_operation_status(
			"That weekly challenge reward is not ready yet.",
			"warning"
		)
		return
	var next: Dictionary = result.get("state", {})
	var reward: Dictionary = result.get("reward", {})
	if next.is_empty() or not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Challenge reward remains available because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	gems = int(next.get("aero_tokens", next.get("gems", gems)))
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_charter_ui()
	_refresh_alliance_operations_ui()
	_refresh_airport_challenge_ui()
	hud.set_player_data(player_level, coins, gems)
	var aero := int(reward.get("aero", 0))
	hud.set_operation_status(
		"%s claimed • +%d coins • +%d XP%s" % [
			String(reward.get("name", "Challenge reward")),
			int(reward.get("coins", 0)),
			int(reward.get("xp", 0)),
			" • +%d Aero" % aero if aero > 0 else ""
		],
		"success"
	)


func _open_missions() -> void:
	if career_screen != null:
		career_screen.close_screen()
	mission_pass_screen.open_screen(_mission_snapshot())

func _on_mission_guidance_requested(mission: Dictionary) -> void:
	var metric := String(mission.get("metric", ""))
	mission_pass_screen.close_screen()
	match metric:
		"npc_services":
			career_screen.open_screen(
				_career_snapshot(),
				"NPC Visitors"
			)
		"passive_passengers":
			super._on_navigation_requested("more")
		"dispatch_shifts":
			_request_activity_entry("dispatch")
		"challenge_points":
			_request_activity_entry("challenge")
		"alliance_points":
			_request_activity_entry("alliance")
		"charter_contracts":
			_request_activity_entry("charter")
		_:
			super._on_navigation_requested("world")

func _resource_inventory_total() -> int:
	var total := 0
	for amount_variant in resource_inventory.values():
		total += maxi(int(amount_variant), 0)
	return total

func _record_mission_event(event_kind: String, payload: Dictionary) -> void:
	if not progression_ready:
		return
	var before_tier := MissionPassRules.pass_level(progression)
	var result := MissionPassRules.record_event(
		progression,
		event_kind,
		payload,
		Time.get_unix_time_from_system(),
		player_level
	)
	var completed: Array = result.get("completed", [])
	if completed.is_empty():
		return
	var after_tier := MissionPassRules.pass_level(progression)
	var message := "MISSION COMPLETE" if completed.size() == 1 else "%d MISSIONS COMPLETE" % completed.size()
	message += " • +%d PASS POINTS" % int(result.get("points_added", 0))
	if after_tier > before_tier:
		message += " • TIER %d UNLOCKED" % after_tier
	hud.set_operation_status(message, "success")

func _on_mission_reroll_requested(mission_id: String, use_ad: bool) -> void:
	if use_ad:
		if rewarded_passenger_ad_bridge == null or not rewarded_passenger_ad_bridge.provider_connected:
			hud.set_operation_status("Rewarded mission reroll is unavailable until an ad provider is connected.", "warning")
			return
		pending_mission_ad_id = mission_id
		rewarded_passenger_ad_bridge.request_ad_for("mission_reroll")
		return
	if not MissionPassRules.reroll_daily(
		progression,
		mission_id,
		false,
		Time.get_unix_time_from_system(),
		player_level
	):
		hud.set_operation_status("Daily mission cannot be rerolled.", "warning")
		return
	_save_checkpoint()
	_refresh_mission_ui()

func _on_rewarded_action_completed(action_id: String) -> void:
	if action_id != "mission_reroll":
		return
	var mission_id := pending_mission_ad_id
	pending_mission_ad_id = ""
	if mission_id.is_empty():
		return
	if MissionPassRules.reroll_daily(
		progression,
		mission_id,
		true,
		Time.get_unix_time_from_system(),
		player_level
	):
		_save_checkpoint()
		_refresh_mission_ui()
		hud.set_operation_status("Daily mission rerolled after rewarded ad.", "success")

func _on_rewarded_action_unavailable(action_id: String) -> void:
	if action_id != "mission_reroll":
		return
	pending_mission_ad_id = ""
	hud.set_operation_status("Rewarded mission reroll is unavailable right now.", "warning")


func _available_resource_choice_country_codes() -> Array[String]:
	# Resource-choice crates are global by design. Home country and personal
	# route range determine travel progression, not permanent material access.
	var result: Array[String] = []
	for country_variant in CountryCatalog.get_countries():
		var country: Dictionary = country_variant
		var code := String(country.get("id", ""))
		if CountryResourceCatalog.resources_for_country(code).size() == 3:
			result.append(code)
	result.sort()
	return result

func _on_pass_resource_choice_requested(resource_id: String) -> void:
	var resource := CountryResourceCatalog.get_resource(resource_id)
	if resource.is_empty():
		hud.set_operation_status("That country resource is not available.", "warning")
		return
	var allowed := _available_resource_choice_country_codes()
	if not allowed.has(String(resource.get("country_code", ""))):
		hud.set_operation_status(
			"That country resource is not available in the launch catalog.",
			"warning"
		)
		return
	var next := MissionPassRules.reserve_resource_choice(
		_capture_state(),
		resource_id,
		1
	)
	if next.is_empty():
		hud.set_operation_status("No Country Resource Crate is available.", "warning")
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Crate was not consumed because progress could not be saved.", "warning")
		return
	progression = next
	_drain_resource_choice_grants()
	_refresh_mission_ui()

func _drain_resource_choice_grants() -> void:
	if not progression_ready:
		return
	var pending: Array = progression.get("pending_resource_grants", [])
	if pending.is_empty():
		return
	for grant_variant in pending.duplicate(true):
		var grant: Dictionary = grant_variant
		var grant_id := String(grant.get("id", ""))
		var resource_id := String(grant.get("resource_id", ""))
		var amount := maxi(int(grant.get("amount", 1)), 1)
		if grant_id.is_empty() or CountryResourceCatalog.get_resource(resource_id).is_empty():
			continue
		var updated_profile := ProfileStore.apply_resource_reward_receipt(
			grant_id,
			resource_id,
			amount
		)
		if updated_profile.is_empty():
			hud.set_operation_status("Resource reward is safely queued and will retry after the profile can be saved.", "warning")
			return
		current_profile = updated_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)
		var next := MissionPassRules.complete_resource_grant(
			_capture_state(),
			grant_id
		)
		if next.is_empty():
			return
		if not AirportProgressionStore.save_state(next):
			# The profile receipt makes retrying this grant idempotent.
			hud.set_operation_status("Resource granted; receipt cleanup will retry automatically.", "warning")
			return
		progression = next
		var resource := CountryResourceCatalog.get_resource(resource_id)
		hud.set_operation_status(
			"Country Resource Crate • +%d %s" % [
				amount,
				String(resource.get("name", "resource"))
			],
			"success"
		)

func _on_pass_reward_claim_requested(tier_number: int, track: String) -> void:
	var next := MissionPassRules.claim_pass_reward(_capture_state(), tier_number, track)
	_apply_claimed_mission_state(next, "Airport Pass reward claimed.")

func _on_pass_claim_all_requested() -> void:
	var next := MissionPassRules.claim_all_available(_capture_state())
	_apply_claimed_mission_state(next, "Available Airport Pass rewards claimed.")

func _apply_claimed_mission_state(next: Dictionary, success_message: String) -> void:
	if next.is_empty():
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Reward remains available because progress could not be saved.", "warning")
		return
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	gems = int(next.get("aero_tokens", next.get("gems", gems)))
	_update_level()
	_drain_passenger_rewards()
	_refresh_career_ui()
	_refresh_mission_ui()
	hud.set_operation_status(success_message, "success")

func _on_booster_activate_requested(booster_id: String) -> void:
	var next := _capture_state()
	if not MissionBoosterRules.activate(
		next,
		booster_id,
		Time.get_unix_time_from_system()
	):
		hud.set_operation_status("That booster is not available in your inventory.", "warning")
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Booster was not consumed because progress could not be saved.", "warning")
		return
	progression = next
	_apply_live_boosters(true)
	_refresh_mission_ui()
	var definition := MissionBoosterRules.definition(booster_id)
	hud.set_operation_status(
		"%s active • 2 hours added" % String(definition.get("title", "Booster")),
		"success"
	)


func _apply_live_boosters(force: bool = false) -> void:
	if not progression_ready:
		return
	var profile := MissionBoosterRules.active_profile(
		progression,
		Time.get_unix_time_from_system()
	)
	var signature := hash(profile)
	if not force and signature == last_booster_signature:
		return
	last_booster_signature = signature
	if ground_services != null:
		ground_services.set_global_service_speed_multiplier(
			float(profile.get("ground_service_speed", 1.0))
		)
	if passenger_economy != null:
		passenger_economy.set_global_production_multiplier(
			float(profile.get("passenger_production", 1.0))
		)


func _on_mission_product_purchase_requested(product_id: String) -> void:
	if mission_billing_bridge == null:
		_on_mission_billing_unavailable(product_id)
		return
	mission_billing_bridge.request_purchase(product_id)

func _on_mission_billing_unavailable(product_id: String) -> void:
	var product := MissionPassCatalog.product(product_id)
	var title := String(product.get("title", "Store purchase"))
	hud.set_operation_status(
		"%s is unavailable until the platform billing provider is connected." % title,
		"warning"
	)

func _on_mission_purchase_verified(
	product_id: String,
	purchase_token: String
) -> void:
	if grant_verified_mission_product(product_id, purchase_token):
		var product := MissionPassCatalog.product(product_id)
		hud.set_operation_status(
			"Purchase verified • %s" % String(product.get("title", "reward granted")),
			"success"
		)

func set_mission_billing_provider_connected(value: bool) -> void:
	if mission_billing_bridge == null:
		return
	mission_billing_bridge.set_provider_connected(value)
	_refresh_mission_ui()

func complete_mission_purchase_from_provider(
	store_product_id: String,
	purchase_token: String
) -> void:
	if mission_billing_bridge != null:
		mission_billing_bridge.complete_purchase_from_provider(
			store_product_id,
			purchase_token
		)

func complete_mission_restore_from_provider(
	store_product_id: String,
	purchase_token: String
) -> void:
	if mission_billing_bridge != null:
		mission_billing_bridge.complete_restore_from_provider(
			store_product_id,
			purchase_token
		)

func grant_verified_mission_product(
	product_id: String,
	purchase_token: String
) -> bool:
	# Billing adapters call this only after platform-side verification.
	MissionPassRules.ensure_state(progression, Time.get_unix_time_from_system(), player_level)
	var next := MissionPassRules.grant_verified_product(
		_capture_state(),
		product_id,
		purchase_token
	)
	if next.is_empty() or not AirportProgressionStore.save_state(next):
		return false
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	gems = int(next.get("aero_tokens", next.get("gems", gems)))
	_refresh_career_ui()
	_refresh_mission_ui()
	return true

func _refresh_career_ui() -> void:
	if career_screen == null or not progression_ready:
		return
	var data := _career_snapshot()
	# Runtime timers are not UI data: excluding them avoids rebuilding buttons every second.
	(data["state"] as Dictionary).erase("aircraft_runtime")
	(data["state"] as Dictionary).erase("npc_remaining")
	(data["state"] as Dictionary).erase("passenger_balance")
	career_screen.set_snapshot(data)
	if career_pin != null:
		var status := AirportProgressionRules.quest_status(progression, data["airport"], player_level)
		var quest: Dictionary = status.get("quest", {})
		career_pin.text = "CAREER COMPLETE" if quest.is_empty() else "%s\n%s" % [
			"CAREER • REWARD READY" if bool(status.get("ready", false)) else "CAREER %d / %d" % [int(status.get("count", 0)), int(status.get("target", 1))], String(quest.get("title", ""))]
		GameUIStyle.apply_button(career_pin, "gold" if bool(status.get("ready", false)) else "nav", true)
	hud.set_player_data(player_level, coins, gems)
	hud.set_level_progress(
		player_xp,
		AirportProgressionRules.xp_for_level(player_level),
		AirportProgressionRules.xp_for_level(mini(player_level + 1, AirportProgressionRules.MAX_LEVEL)),
		player_level >= AirportProgressionRules.MAX_LEVEL
	)

func _open_career() -> void:
	if mission_pass_screen != null:
		mission_pass_screen.close_screen()
	career_screen.open_screen(_career_snapshot())

func _claim_career_reward(quest_id: String) -> void:
	var next := AirportProgressionRules.claim(_capture_state(), quest_id, _airport_career_snapshot(), player_level)
	if next.is_empty():
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Reward not claimed: unable to save. It remains available.", "warning")
		return
	progression = next
	player_xp = int(progression.get("xp", player_xp))
	_update_level()
	_drain_passenger_rewards()
	_refresh_career_ui()

func _drain_passenger_rewards() -> void:
	if not is_instance_valid(passenger_economy) or int(progression.get("pending_passengers", 0)) <= 0:
		return
	var room := maxi(int(floor(float(passenger_economy.get_capacity()) - passenger_economy.passengers)), 0)
	var amount := mini(room, int(progression.get("pending_passengers", 0)))
	if amount <= 0:
		return
	var next := _capture_state()
	next["pending_passengers"] = int(next["pending_passengers"]) - amount
	next["passenger_balance"] = passenger_economy.passengers + float(amount)
	if not AirportProgressionStore.save_state(next):
		return
	progression = next
	restoring_wallet = true
	passenger_economy.set_passengers(float(next["passenger_balance"]))
	restoring_wallet = false
	# The change signal may immediately board a queued aircraft; save that debit too.
	_save_checkpoint()

func _purchase_career_aircraft(aircraft_id: String) -> void:
	var next := AirportProgressionRules.purchase_aircraft(_capture_state(), aircraft_id, player_level)
	if next.is_empty():
		hud.set_operation_status("Aircraft order blocked by level, coins or fleet capacity.", "warning")
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status("Aircraft not purchased: unable to save. No coins were spent.", "warning")
		return
	progression = next
	coins = int(next["coins"])
	_deploy_reserve_aircraft()
	_save_checkpoint()
	_refresh_career_ui()

func _update_level() -> void:
	var old_level := player_level
	player_level = AirportProgressionRules.level_for_xp(player_xp)
	if player_level > old_level:
		var aero_awarded := MissionPassRules.aero_tokens_for_level_range(
			old_level,
			player_level
		)
		if aero_awarded > 0:
			gems += aero_awarded
			progression["aero_tokens"] = gems
			progression["gems"] = gems
		var unlocked_names: Array[String] = []
		for reached_level in range(old_level + 1, player_level + 1):
			for name_variant in AirportProgressionPacing.unlock_names(
				reached_level
			):
				var unlock_name := String(name_variant)
				if not unlocked_names.has(unlock_name):
					unlocked_names.append(unlock_name)
		var unlock_text := (
			" • UNLOCKED: %s" % " / ".join(unlocked_names)
			if not unlocked_names.is_empty()
			else ""
		)
		hud.set_operation_status(
			"AIRPORT LEVEL %d • +%d Aero Tokens%s" % [
				player_level,
				aero_awarded,
				unlock_text
			],
			"success"
		)
		_refresh_activities_hub()
	if world_map != null:
		world_map.player_level = player_level
	if fleet_screen != null:
		fleet_screen.player_level = player_level

func _on_career_activity_requested(mode_id: String) -> void:
	if career_screen != null:
		career_screen.close_screen()
	_request_activity_entry(mode_id)


func _guide_career(quest: Dictionary) -> void:
	var objective: Dictionary = quest.get("objective", {})
	var kind := String(objective.get("kind", ""))
	career_screen.close_screen()
	match kind:
		"flight", "countries":
			var model := String(objective.get("aircraft", ""))
			var selected := -1
			for index in range(aircraft_demos.size()):
				if aircraft_demos[index].aircraft_type_id == model:
					selected = index
					if aircraft_demos[index].can_change_flight_plan():
						break
			if selected < 0:
				career_screen.open_screen(_career_snapshot(), "Aircraft Orders")
				return
			world_map.selected_aircraft_index = selected
			world_map.selected_destination_id = String(objective.get("destination", "brussels"))
			super._on_navigation_requested("world")
		"own_aircraft":
			career_screen.open_screen(_career_snapshot(), "Aircraft Orders")
		"building":
			var id := String(objective.get("building", ""))
			if int(objective.get("upgrade_level", 1)) > 1:
				for building in airport_grid.placed_buildings:
					if String(building.get("definition_id", "")) == id:
						_open_building_management(building)
						return
			_on_building_selected(id)
		"parcel":
			airport_grid.select_parcel(String(objective.get("parcel", "north")))
			camera_controller.focus_world_position(airport_grid.get_parcel_world_center(String(objective.get("parcel", "north"))), 0.42, 0.72)
		"regional_ready":
			for id in ["regional_runway", "medium_stand", "regional_fuel"]:
				var found := false
				for building in airport_grid.placed_buildings:
					if building.get("definition_id", "") == id:
						found = true
				if not found:
					_on_building_selected(id)
					return
			hud.set_operation_status("Connect the medium stand to a regional runway and all required services using taxiways and service roads.", "warning")
		"npc_service":
			career_screen.open_screen(_career_snapshot(), "NPC Visitors")

func _toggle_npc_traffic(enabled: bool) -> void:
	npc_director.enabled = enabled
	_save_checkpoint()
	_refresh_career_ui()

func _is_npc(aircraft: AircraftPrototype) -> bool:
	return aircraft.is_social_visitor() and String(aircraft.get_social_visit_data().get("relationship", "")) == "npc"

func _start_npc_visit(contact: Dictionary) -> void:
	if social_airport_service == null:
		return
	social_airport_service.sequence += 1
	var request := SocialFlightRules.create_visit_request(contact, social_airport_service.sequence)
	var id := String(request.get("visit_id", ""))
	if id.is_empty():
		return
	social_airport_service.active_visits[id] = {"request": request.duplicate(true), "status": "INBOUND", "aircraft": null}
	_on_social_visit_requested(request)

func _on_social_visit_requested(request: Dictionary) -> void:
	if String(request.get("relationship", "")) != "npc":
		super._on_social_visit_requested(request)
		return
	var visit_id := String(request.get("visit_id", ""))
	if visit_id.is_empty() or social_visitor_aircraft.has(visit_id):
		return
	var aircraft := CareerAircraft.new()
	aircraft.configure_aircraft_type(String(request.get("aircraft_type_id", "pico_p8")))
	NpcTrafficDirector.apply_behavior(aircraft)
	aircraft.configure_taxi_traffic(taxi_traffic)
	aircraft.configure_social_visit(request)
	aircraft.assign_flight_plan(SocialFlightRules.create_social_flight_plan(request))
	aircraft.name = "NPC-" + String(request.get("airport_code", "APT"))
	aircraft.z_index = 96
	var label := String(aircraft.name)
	aircraft.state_changed.connect(_on_social_aircraft_state_changed.bind(aircraft, label, visit_id))
	aircraft.departed.connect(_on_social_aircraft_departed.bind(aircraft, label, visit_id))
	aircraft.arrival_completed.connect(_on_social_arrival_completed.bind(aircraft, label, visit_id))
	add_child(aircraft)
	social_visitor_aircraft[visit_id] = aircraft
	social_airport_service.register_visit_aircraft(visit_id, aircraft)
	aircraft.prepare_social_inbound()
	if not _assign_arrival_if_possible(aircraft, label):
		pending_arrivals.append({"aircraft": aircraft, "label": label, "wait_seconds": 0.0})
	hud.set_operation_status("%s is visiting with a %s • NPC traffic" % [request.get("display_name", "Pilot"), aircraft.aircraft_display_name], "success")

func _on_social_aircraft_departed(aircraft: AircraftPrototype, label: String, visit_id: String) -> void:
	if not is_instance_valid(aircraft) or aircraft.state != "EN_ROUTE" or bool(aircraft.get_meta("settled", false)):
		return
	aircraft.set_meta("settled", true)
	var request := aircraft.get_social_visit_data()
	if _is_npc(aircraft):
		var event := {"id": visit_id, "kind": "npc_service", "npc_id": request.get("contact_id", ""), "size": aircraft.aircraft_size}
		if AirportProgressionRules.record_event(progression, event, player_level):
			var seats := int(aircraft.get_aircraft_profile().get("passengers", 8))
			var reward := {"coins": 50 + seats * 2, "xp": 6 + ceili(float(seats) / 8.0), "resources_won": [], "relationship": "npc"}
			coins += int(reward["coins"])
			player_xp += int(reward["xp"])
			_record_mission_event("npc_service", {"coins": int(reward["coins"]), "xp": int(reward["xp"])})
			social_airport_service.complete_visit(visit_id, reward, {})
			hud.set_operation_status("%s serviced • %d XP • NPCs do not generate friendship or remote-owner rewards" % [label, int(reward["xp"])], "success")
		social_visitor_aircraft.erase(visit_id)
		aircraft.call_deferred("queue_free")
	else:
		var ledger: Dictionary = progression.get("friendships", {})
		var contact := String(request.get("contact_id", ""))
		var rank := FriendshipRules.status(ledger.get(contact, {}))
		super._on_social_aircraft_departed(aircraft, label, visit_id)
		if not social_airport_service.completed_visits.is_empty():
			var completed: Dictionary = social_airport_service.completed_visits[0]
			var reward: Dictionary = completed.get("host_reward", {})
			coins += int(floor(float(reward.get("coins", 0)) * float(rank.get("coin_bonus", 0.0))))
		progression["friendships"] = FriendshipRules.record_completion(ledger, request, Time.get_date_string_from_system(true))
		if String(request.get("relationship", "")) == "alliance":
			_record_alliance_activity("alliance_visit")
	_record_dispatch_action("visitor_service")
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_alliance_operations_ui()

func _on_social_passenger_gift_requested(
	contact_id: String
) -> void:
	if social_airport_service == null:
		return
	var contact := social_airport_service.get_contact(contact_id)
	var before := ProfileStore.get_outgoing_friend_gift_status(contact_id)
	super._on_social_passenger_gift_requested(contact_id)
	var after := ProfileStore.get_outgoing_friend_gift_status(contact_id)
	if (
		String(contact.get("relationship", "")) == "alliance"
		and not bool(before.get("sent_today", false))
		and bool(after.get("sent_today", false))
	):
		_record_alliance_activity("alliance_gift")
		_save_checkpoint()
		_refresh_alliance_operations_ui()


func _record_alliance_activity(
	action: String,
	amount: int = 1
) -> bool:
	if (
		not ActivityProgressionRules.is_level_unlocked(
			"alliance",
			player_level
		)
		or not _has_alliance_contact()
	):
		return false
	var before := int(
		(progression.get("alliance_ops", {}) as Dictionary).get(
			"personal_points",
			0
		)
	)
	var changed := AllianceOperationsRules.record_action(
		progression,
		action,
		amount,
		Time.get_unix_time_from_system()
	)
	if not changed:
		return false
	MissionPassRules.enable_activity_missions(
		progression,
		"alliance"
	)
	var after := int(
		(progression.get("alliance_ops", {}) as Dictionary).get(
			"personal_points",
			before
		)
	)
	var points_added := maxi(after - before, 0)
	if points_added > 0:
		_record_mission_event(
			"alliance_points",
			{"points": points_added}
		)
	return true


func _social_only_snapshot(snapshot: Dictionary) -> Dictionary:
	var filtered := snapshot.duplicate(true)
	filtered["alliance_operations_level"] = (
		ActivityProgressionRules.ALLIANCE_UNLOCK_LEVEL
	)
	filtered["alliance_operations_level_unlocked"] = (
		ActivityProgressionRules.is_level_unlocked(
			"alliance",
			player_level
		)
	)
	for key in ["active_visits", "recent_completed"]:
		var rows: Array = []
		for row in snapshot.get(key, []):
			if String(row.get("relationship", "")) != "npc":
				rows.append(row)
		filtered[key] = rows
	return filtered

func _on_social_snapshot_changed(snapshot: Dictionary) -> void:
	super._on_social_snapshot_changed(_social_only_snapshot(snapshot))
	if progression_ready:
		_refresh_activities_hub()

func _on_navigation_requested(tab: String) -> void:
	if career_screen != null:
		career_screen.close_screen()
	if mission_pass_screen != null:
		mission_pass_screen.close_screen()
	if activities_hub_screen != null and activities_hub_screen.is_open() and tab != "activities":
		activities_hub_screen.close_screen(true)
	if dispatch_challenge_screen != null and dispatch_challenge_screen.is_open() and tab != "activities":
		dispatch_challenge_screen.close_screen(true)
	if tab == "activities":
		if charter_screen != null and charter_screen.is_open():
			charter_screen.close_screen()
		if alliance_operations_screen != null and alliance_operations_screen.is_open():
			alliance_operations_screen.close_screen(true)
		if airport_challenge_screen != null and airport_challenge_screen.is_open():
			airport_challenge_screen.close_screen(true)
		if dispatch_challenge_screen != null and dispatch_challenge_screen.is_open():
			dispatch_challenge_screen.close_screen(true)
		_refresh_activities_hub()
		activities_hub_screen.open_screen(_activities_snapshot())
		return
	if tab == "challenge":
		if not AirportChallengeRules.is_unlocked(player_level):
			hud.set_operation_status(
				"Weekly Airport Challenge unlocks at Airport Level %d." % AirportChallengeRules.UNLOCK_LEVEL,
				"warning"
			)
			return
		if airport_challenge_screen != null:
			airport_challenge_screen.open_screen(_airport_challenge_snapshot())
		return
	if tab == "charter":
		if not CharterRules.is_unlocked(player_level):
			hud.set_operation_status(
				"Cargo Charter unlocks at Airport Level %d." % CharterRules.UNLOCK_LEVEL,
				"warning"
			)
			return
		if charter_screen != null:
			charter_screen.open_screen(_charter_snapshot())
		return
	if charter_screen != null and charter_screen.is_open():
		charter_screen.close_screen()
	if alliance_operations_screen != null and alliance_operations_screen.is_open():
		alliance_operations_screen.close_screen(true)
	if airport_challenge_screen != null and airport_challenge_screen.is_open():
		airport_challenge_screen.close_screen(true)
	super._on_navigation_requested(tab)
	if tab in ["social", "alliance"] and social_airport_service != null:
		social_airport_screen.set_snapshot(_social_only_snapshot(social_airport_service.get_snapshot()))

func _has_alliance_contact() -> bool:
	if social_airport_service == null:
		return false
	for contact_variant in social_airport_service.get_snapshot().get("contacts", []):
		var contact: Dictionary = contact_variant
		if String(contact.get("relationship", "")) == "alliance":
			return true
	return false


func _event_has_claimable_reward() -> bool:
	if not bool(current_event_snapshot.get("active", false)):
		return false
	for quest_variant in current_event_snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		if (
			bool(quest.get("unlocked", false))
			and bool(quest.get("complete", false))
			and not bool(quest.get("claimed", false))
		):
			return true
	for milestone_variant in current_event_snapshot.get("alliance_milestones", []):
		var milestone: Dictionary = milestone_variant
		if bool(milestone.get("reached", false)) and not bool(milestone.get("claimed", false)):
			return true
	return false


func _activities_snapshot() -> Dictionary:
	var mission_claimable := MissionPassRules.claimable_count(progression)
	var mission_completed := MissionPassRules.completed_daily_count(progression)
	var mission_new := ActivityProgressionRules.is_newly_unlocked(
		progression,
		"missions",
		player_level
	)
	var charter := _charter_snapshot()
	var charter_active: Dictionary = charter.get("active", {})
	var charter_phase := String(charter_active.get("phase", ""))
	var charter_attention := charter_phase == "READY"
	var charter_unlocked := bool(charter.get("unlocked", false))
	var charter_new := (
		charter_unlocked
		and ActivityProgressionRules.is_newly_unlocked(
			progression,
			"charter",
			player_level
		)
	)
	var charter_status := "UNLOCKS AT LEVEL %d" % CharterRules.UNLOCK_LEVEL
	var charter_detail := "Dedicated cargo contracts and guaranteed country resources."
	var charter_action := "OPEN CHARTER"
	if charter_unlocked:
		if not bool(charter.get("parcel_owned", false)):
			charter_status = "LOGISTICS DISTRICT REQUIRED"
			charter_detail = "Purchase the Logistics District to activate cargo operations."
		elif not bool(charter.get("parcel_ready", false)):
			charter_status = "DISTRICT BLOCKED"
			charter_detail = "Move conflicting buildings out of the Charter footprint."
		elif charter_phase == "READY":
			charter_status = "REWARD READY"
			charter_detail = "Completed Cargo Charter is waiting to be claimed."
			charter_action = "CLAIM / VIEW"
		elif not charter_active.is_empty():
			charter_status = "%s • %s" % [
				String(charter_active.get("contract_type_badge", "CHARTER")),
				charter_phase.replace("_", " ").to_upper()
			]
			charter_detail = "%s to %s • %s remaining" % [
				String(charter_active.get("contract_type_name", "Cargo Charter")),
				String(charter_active.get("city", "Cargo route")),
				_format_activity_time(int(charter_active.get("remaining_seconds", 0)))
			]
		else:
			var charter_offers: Array = charter.get("offers", [])
			charter_status = "%d CONTRACTS AVAILABLE" % charter_offers.size()
			var offer_badges: Array[String] = []
			for offer_variant in charter_offers:
				var charter_offer: Dictionary = offer_variant
				offer_badges.append(
					String(charter_offer.get("contract_type_badge", "CHARTER"))
				)
			charter_detail = "%s • board refreshes in %s" % [
				" / ".join(offer_badges),
				_format_activity_time(int(charter.get("board_rotation_seconds", 0)))
			]

	var challenge := _airport_challenge_snapshot()
	var challenge_attention := AirportChallengeRules.claimable_count(
		progression,
		player_level,
		Time.get_unix_time_from_system()
	) > 0
	var challenge_unlocked := bool(challenge.get("unlocked", false))
	var challenge_new := (
		challenge_unlocked
		and ActivityProgressionRules.is_newly_unlocked(
			progression,
			"challenge",
			player_level
		)
	)
	challenge_attention = challenge_unlocked and challenge_attention
	var challenge_status := "UNLOCKS AT LEVEL %d" % AirportChallengeRules.UNLOCK_LEVEL
	var challenge_detail := "Weekly score track based on your normal passenger flights."
	if challenge_unlocked:
		challenge_status = "%s • %d PTS" % [
			String(challenge.get("theme_short_name", "Weekly")).to_upper(),
			int(challenge.get("score", 0))
		]
		var next_target := int(challenge.get("next_target", 0))
		challenge_detail = (
			"%s • all milestones complete" % String(challenge.get("theme_description", ""))
			if next_target <= 0
			else "%s • %d pts to next reward • %s left" % [
				String(challenge.get("theme_description", "")),
				maxi(next_target - int(challenge.get("score", 0)), 0),
				_format_activity_time(int(challenge.get("seconds_remaining", 0)))
			]
		)

	var alliance := _alliance_operations_snapshot()
	var has_alliance := _has_alliance_contact()
	var alliance_level_unlocked := ActivityProgressionRules.is_level_unlocked(
		"alliance",
		player_level
	)
	var alliance_enabled := alliance_level_unlocked and has_alliance
	var alliance_new := (
		alliance_enabled
		and ActivityProgressionRules.is_newly_unlocked(
			progression,
			"alliance",
			player_level
		)
	)
	var alliance_attention := (
		alliance_enabled
		and AllianceOperationsRules.claimable_count(
			progression,
			Time.get_unix_time_from_system()
		) > 0
	)
	var alliance_status := (
		"%s • %d PTS" % [
			String(alliance.get("project_short_name", "Alliance")).to_upper(),
			int(alliance.get("alliance_total", 0))
		]
		if alliance_enabled
		else (
			"UNLOCKS AT LEVEL %d"
			% ActivityProgressionRules.ALLIANCE_UNLOCK_LEVEL
			if not alliance_level_unlocked
			else "ALLIANCE REQUIRED"
		)
	)
	var alliance_detail := (
		"%s • %d personal pts • %s left" % [
			String(alliance.get("project_description", "")),
			int(alliance.get("personal_points", 0)),
			_format_activity_time(
				int(alliance.get("seconds_remaining", 0))
			)
		]
		if alliance_enabled
		else (
			"Alliance Operations opens after you have mastered solo airport challenges."
			if not alliance_level_unlocked
			else "Join or connect an Alliance to take part in cooperative weekly goals."
		)
	)

	var dispatch := _dispatch_snapshot()
	var dispatch_unlocked := bool(dispatch.get("unlocked", false))
	var dispatch_new := (
		dispatch_unlocked
		and ActivityProgressionRules.is_newly_unlocked(
			progression,
			"dispatch",
			player_level
		)
	)
	var dispatch_status_code := String(dispatch.get("status", "IDLE"))
	var dispatch_attention := (
		dispatch_unlocked
		and bool(dispatch.get("reward_available", false))
	)
	var dispatch_status := "UNLOCKS AT LEVEL %d" % DispatchChallengeRules.UNLOCK_LEVEL
	var dispatch_detail := "Three-minute live operations shift using your real airport."
	var dispatch_action := "OPEN DISPATCH"
	if dispatch_unlocked:
		match dispatch_status_code:
			"RUNNING":
				dispatch_status = "LIVE • %d PTS • COMBO x%d • %s LEFT" % [
					int(dispatch.get("score", 0)),
					int(dispatch.get("combo_count", 0)),
					_format_activity_time(int(dispatch.get("remaining_seconds", 0)))
				]
				dispatch_detail = "Clean operations build bonus points; taxi holds cost 4 points and break the combo."
			"READY":
				dispatch_status = "%s • %d PTS • MAX COMBO x%d" % [
					String(dispatch.get("tier_name", "RESULT")).to_upper(),
					int(dispatch.get("score", 0)),
					int(dispatch.get("max_combo", 0))
				]
				dispatch_detail = (
					"Daily reward ready • +%d combo pts • −%d congestion pts." % [
						int(dispatch.get("combo_bonus", 0)),
						int(dispatch.get("penalty_points", 0))
					]
					if dispatch_attention
					else "Shift complete • finish the result to start another run."
				)
				dispatch_action = "VIEW RESULT"
			_:
				dispatch_status = "READY • BEST %d" % int(dispatch.get("best_score", 0))
				dispatch_detail = (
					"Daily reward already claimed • practice runs still improve your best."
					if bool(dispatch.get("reward_claimed", false))
					else "3-minute shift • Bronze 30 • Silver 65 • Gold 105 • clean combos accelerate scoring."
				)

	var event_active := bool(current_event_snapshot.get("active", false))
	var event_level_unlocked := ActivityProgressionRules.is_level_unlocked(
		"event",
		player_level
	)
	var event_enabled := event_active and event_level_unlocked
	var event_new := (
		event_enabled
		and ActivityProgressionRules.is_newly_unlocked(
			progression,
			"event",
			player_level
		)
	)
	var event_attention := (
		event_enabled
		and _event_has_claimable_reward()
	)
	var event_name := String(current_event_snapshot.get("name", "Seasonal Event"))
	var event_status := (
		"UNLOCKS AT LEVEL %d" % ActivityProgressionRules.EVENT_UNLOCK_LEVEL
		if not event_level_unlocked
		else (
			"PHASE %d / 3 • %s" % [
				int(current_event_snapshot.get("week", 1)),
				String(
					current_event_snapshot.get(
						"phase_name",
						"Event Phase"
					)
				).to_upper()
			]
			if event_active
			else "NO EVENT ACTIVE"
		)
	)
	var event_detail := (
		"Seasonal events unlock after the first few airport basics."
		if not event_level_unlocked
		else (
			"%s • %d/%d phase quests complete • %d days left" % [
				String(current_event_snapshot.get("phase_description", event_name)),
				int(current_event_snapshot.get("phase_quest_complete", 0)),
				maxi(int(current_event_snapshot.get("phase_quest_total", 0)), 1),
				int(current_event_snapshot.get("days_remaining", 0))
			]
			if event_active
			else "Limited-time events appear here when activated."
		)
	)

	var attention_count := 0
	for ready in [
		mission_claimable > 0,
		dispatch_attention,
		charter_attention,
		challenge_attention,
		alliance_attention,
		event_attention
	]:
		if ready:
			attention_count += 1

	var new_count := 0
	for is_new in [
		mission_new,
		event_new,
		dispatch_new,
		challenge_new,
		alliance_new,
		charter_new
	]:
		if is_new:
			new_count += 1

	return {
		"attention_count": attention_count,
		"new_count": new_count,
		"missions": {
			"title": "MISSIONS & PASS",
			"badge": "DAILY / WEEKLY",
			"new": mission_new,
			"status": (
				"%d REWARD%s READY" % [mission_claimable, "" if mission_claimable == 1 else "S"]
				if mission_claimable > 0
				else "DAILY %d / 4" % mission_completed
			),
			"detail": "Daily and weekly missions feed the monthly reward pass.",
			"attention": mission_claimable > 0,
			"enabled": true,
			"action": "OPEN MISSIONS"
		},
		"dispatch": {
			"title": "AIRPORT DISPATCH",
			"badge": "3-MINUTE LIVE SHIFT",
			"new": dispatch_new,
			"status": dispatch_status,
			"detail": dispatch_detail,
			"attention": dispatch_attention,
			"enabled": dispatch_unlocked,
			"action": dispatch_action,
			"locked_action": "LEVEL %d" % DispatchChallengeRules.UNLOCK_LEVEL
		},
		"charter": {
			"title": "CARGO CHARTER",
			"badge": "LOGISTICS",
			"new": charter_new,
			"status": charter_status,
			"detail": charter_detail,
			"attention": charter_attention,
			"enabled": charter_unlocked,
			"action": charter_action,
			"locked_action": "LEVEL %d" % CharterRules.UNLOCK_LEVEL
		},
		"challenge": {
			"title": "WEEKLY AIRPORT CHALLENGE",
			"new": challenge_new,
			"badge": (
				String(challenge.get("theme_short_name", "SOLO WEEKLY")).to_upper()
				if challenge_unlocked
				else "SOLO WEEKLY"
			),
			"status": challenge_status,
			"detail": challenge_detail,
			"attention": challenge_attention,
			"enabled": challenge_unlocked,
			"action": "OPEN CHALLENGE",
			"locked_action": "LEVEL %d" % AirportChallengeRules.UNLOCK_LEVEL
		},
		"alliance": {
			"title": "ALLIANCE OPERATIONS",
			"new": alliance_new,
			"badge": (
				String(alliance.get("project_short_name", "CO-OP WEEKLY")).to_upper()
				if has_alliance
				else "CO-OP WEEKLY"
			),
			"status": alliance_status,
			"detail": alliance_detail,
			"attention": alliance_attention,
			"enabled": alliance_enabled,
			"action": "OPEN ALLIANCE OPS",
			"locked_action": (
				"LEVEL %d" % ActivityProgressionRules.ALLIANCE_UNLOCK_LEVEL
				if not alliance_level_unlocked
				else "ALLIANCE REQUIRED"
			)
		},
		"event": {
			"title": event_name if event_active else "SEASONAL EVENT",
			"badge": "LIMITED TIME",
			"new": event_new,
			"status": event_status,
			"detail": event_detail,
			"attention": event_attention,
			"enabled": event_enabled,
			"action": "OPEN EVENT",
			"locked_action": (
				"LEVEL %d" % ActivityProgressionRules.EVENT_UNLOCK_LEVEL
				if not event_level_unlocked
				else "INACTIVE"
			)
		}
	}


func _dispatch_snapshot() -> Dictionary:
	var data := DispatchChallengeRules.snapshot(
		_capture_state(),
		player_level,
		Time.get_unix_time_from_system()
	)
	var operational_aircraft := 0
	var aircraft_at_stand := 0
	for aircraft_variant in aircraft_demos:
		var aircraft := aircraft_variant as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			continue
		operational_aircraft += 1
		if String(aircraft.state) in [
			"PARKED",
			"WAITING_FUEL",
			"UNLOADING",
			"SERVICING",
			"WAITING_PASSENGERS",
			"LOADING",
			"PUSHBACK_PREP",
			"READY_FOR_DESTINATION",
			"READY_FOR_DEPARTURE"
		]:
			aircraft_at_stand += 1
	for visitor_variant in social_visitor_aircraft.values():
		var visitor := visitor_variant as AircraftPrototype
		if visitor == null or not is_instance_valid(visitor):
			continue
		operational_aircraft += 1
		if String(visitor.state) in [
			"PARKED",
			"WAITING_FUEL",
			"UNLOADING",
			"SERVICING",
			"WAITING_PASSENGERS",
			"LOADING",
			"PUSHBACK_PREP",
			"READY_FOR_DESTINATION",
			"READY_FOR_DEPARTURE"
		]:
			aircraft_at_stand += 1
	data["airport_aircraft"] = operational_aircraft
	data["airport_at_stand"] = aircraft_at_stand
	data["passenger_stock"] = (
		passenger_economy.get_passengers()
		if passenger_economy != null
		else 0
	)
	data["passenger_capacity"] = (
		passenger_economy.get_capacity()
		if passenger_economy != null
		else 0
	)
	data["runway_queue"] = (
		runway_dispatcher.get_waiting_count()
		if runway_dispatcher != null
		else 0
	)
	data["ground_queue"] = (
		ground_services.get_waiting_count()
		if ground_services != null
		else 0
	)
	data["inbound_holding"] = pending_arrivals.size()
	return data


func _refresh_dispatch_ui() -> void:
	if not progression_ready:
		return
	var data := _dispatch_snapshot()
	if dispatch_challenge_screen != null:
		dispatch_challenge_screen.set_snapshot(data)
	if hud != null:
		hud.set_dispatch_shift(
			String(data.get("status", "IDLE")),
			int(data.get("score", 0)),
			int(data.get("remaining_seconds", 0)),
			int(data.get("combo_count", 0))
		)


func _on_dispatch_start_requested() -> void:
	var next := DispatchChallengeRules.start_shift(
		_capture_state(),
		player_level,
		Time.get_unix_time_from_system()
	)
	if next.is_empty():
		hud.set_operation_status(
			"Airport Dispatch cannot start right now.",
			"warning"
		)
		return
	if not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Dispatch shift could not start because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	_refresh_dispatch_ui()
	_refresh_activities_hub()
	if dispatch_challenge_screen != null:
		dispatch_challenge_screen.close_screen(true)
	hud.set_operation_status(
		"Airport Dispatch started • 3:00 on the clock • keep traffic moving",
		"success"
	)


func _on_dispatch_claim_requested() -> void:
	var result := DispatchChallengeRules.claim_result(
		_capture_state(),
		player_level,
		Time.get_unix_time_from_system()
	)
	if result.is_empty():
		hud.set_operation_status(
			"Dispatch result is not ready yet.",
			"warning"
		)
		return
	var next: Dictionary = result.get("state", {})
	var reward: Dictionary = result.get("reward", {})
	if next.is_empty() or not AirportProgressionStore.save_state(next):
		hud.set_operation_status(
			"Dispatch result remains available because progress could not be saved.",
			"warning"
		)
		return
	progression = next
	coins = int(next.get("coins", coins))
	player_xp = int(next.get("xp", player_xp))
	_record_mission_event(
		"dispatch_complete",
		{"score": int(reward.get("score", 0))}
	)
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()
	_refresh_mission_ui()
	_refresh_charter_ui()
	_refresh_alliance_operations_ui()
	_refresh_airport_challenge_ui()
	_refresh_dispatch_ui()
	_refresh_activities_hub()
	hud.set_player_data(player_level, coins, gems)
	if bool(reward.get("rewarded", false)):
		hud.set_operation_status(
			"%s • %d pts • max combo x%d • +%d coins • +%d XP" % [
				String(reward.get("tier_name", "Dispatch result")),
				int(reward.get("score", 0)),
				int(reward.get("max_combo", 0)),
				int(reward.get("coins", 0)),
				int(reward.get("xp", 0))
			],
			"success"
		)
	else:
		hud.set_operation_status(
			"Dispatch shift finished • %d points • no new daily reward" % int(
				reward.get("score", 0)
			),
			"normal"
		)


func _on_dispatch_closed() -> void:
	_refresh_activities_hub()
	if activities_hub_screen != null:
		activities_hub_screen.open_screen(_activities_snapshot())


func _record_dispatch_action(
	action: String,
	amount: int = 1
) -> int:
	if not progression_ready:
		return 0
	var points := DispatchChallengeRules.record_action(
		progression,
		player_level,
		action,
		amount,
		Time.get_unix_time_from_system()
	)
	if points == 0:
		return 0
	_save_checkpoint()
	_refresh_dispatch_ui()
	_refresh_activities_hub()
	var data := _dispatch_snapshot()
	if points < 0:
		hud.set_operation_status(
			"Dispatch %d • TAXI HOLD • combo broken • %d pts" % [
				points,
				int(data.get("score", 0))
			],
			"warning"
		)
	else:
		var combo := int(data.get("combo_count", 0))
		hud.set_operation_status(
			"Dispatch +%d • %d pts%s" % [
				points,
				int(data.get("score", 0)),
				" • COMBO x%d" % combo if combo >= 2 else ""
			],
			"success"
		)
	return points


func _refresh_activities_hub() -> void:
	if not progression_ready:
		return
	var data := _activities_snapshot()
	if activities_hub_screen != null:
		activities_hub_screen.set_snapshot(data)
	if hud != null:
		hud.set_activities_attention(
			int(data.get("attention_count", 0)) > 0
			or int(data.get("new_count", 0)) > 0
		)


func _on_activity_mode_requested(mode_id: String) -> void:
	if activities_hub_screen != null:
		activities_hub_screen.close_screen(true)
	_request_activity_entry(mode_id)


func _request_activity_entry(mode_id: String) -> void:
	if not _activity_entry_allowed(mode_id):
		var definition := ActivityProgressionRules.definition(mode_id)
		var unlock_level := int(definition.get("unlock_level", 1))
		var message := (
			"%s unlocks at Airport Level %d."
			% [
				String(definition.get("title", "This activity")),
				unlock_level
			]
		)
		if mode_id == "alliance" and player_level >= unlock_level:
			message = "Join or connect an Alliance before opening Alliance Operations."
		elif mode_id == "event" and player_level >= unlock_level:
			message = "No seasonal event is active right now."
		hud.set_operation_status(message, "warning")
		_refresh_activities_hub()
		return

	if ActivityProgressionRules.is_newly_unlocked(
		progression,
		mode_id,
		player_level
	):
		if activity_intro_screen != null:
			activity_intro_screen.open_intro(
				mode_id,
				ActivityProgressionRules.definition(mode_id)
			)
		return

	_open_activity_mode_direct(mode_id)


func _activity_entry_allowed(mode_id: String) -> bool:
	if not ActivityProgressionRules.is_level_unlocked(
		mode_id,
		player_level
	):
		return false
	match mode_id:
		"alliance":
			return _has_alliance_contact()
		"event":
			return bool(current_event_snapshot.get("active", false))
	return true


func _open_activity_mode_direct(mode_id: String) -> void:
	match mode_id:
		"missions":
			_open_missions()
		"dispatch":
			if dispatch_challenge_screen != null:
				dispatch_challenge_screen.open_screen(_dispatch_snapshot())
		"charter":
			_on_navigation_requested("charter")
		"challenge":
			_on_navigation_requested("challenge")
		"alliance":
			if alliance_operations_screen != null:
				alliance_operations_screen.open_screen(
					_alliance_operations_snapshot()
				)
		"event":
			super._on_navigation_requested("event")


func _on_activity_intro_continue(mode_id: String) -> void:
	if ActivityProgressionRules.mark_tutorial_seen(
		progression,
		mode_id
	):
		_save_checkpoint()
	_refresh_activities_hub()
	_open_activity_mode_direct(mode_id)


func _on_activity_intro_closed() -> void:
	_refresh_activities_hub()
	if activities_hub_screen != null:
		activities_hub_screen.open_screen(_activities_snapshot())


func _on_activities_hub_closed() -> void:
	hud.set_operation_status("Returned to airport operations.")


func _format_activity_time(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var days := int(total / 86400)
	var hours := int((total % 86400) / 3600)
	var minutes := int((total % 3600) / 60)
	if days > 0:
		return "%dd %02dh" % [days, hours]
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes


func _on_event_changed(snapshot: Dictionary) -> void:
	super._on_event_changed(snapshot)
	if progression_ready:
		_refresh_activities_hub()



func _on_aircraft_serviced(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	super._on_aircraft_serviced(aircraft, label)
	if (
		aircraft != null
		and is_instance_valid(aircraft)
		and not aircraft.is_social_visitor()
	):
		_record_dispatch_action("turnaround")


func _on_taxi_hold_changed(
	aircraft: AircraftPrototype,
	holding: bool,
	reason: String
) -> void:
	super._on_taxi_hold_changed(aircraft, holding, reason)
	if holding:
		_record_dispatch_action("taxi_hold")


func _show_aircraft_context(aircraft: AircraftPrototype) -> void:
	if _is_npc(aircraft):
		career_screen.open_screen(_career_snapshot(), "NPC Visitors")
		return
	super._show_aircraft_context(aircraft)

func _persist_airport_layout() -> void:
	super._persist_airport_layout()
	_save_checkpoint()
	_refresh_career_ui()

func _on_passenger_upgrade_requested(uid: int) -> void:
	super._on_passenger_upgrade_requested(uid)
	_save_checkpoint()
	_refresh_career_ui()

func _on_service_upgrade_requested(uid: int) -> void:
	super._on_service_upgrade_requested(uid)
	_save_checkpoint()
	_refresh_career_ui()

func _on_air_traffic_upgrade_requested(uid: int) -> void:
	super._on_air_traffic_upgrade_requested(uid)
	_save_checkpoint()
	_refresh_career_ui()

func _on_event_shop_coins_granted(amount: int) -> void:
	super._on_event_shop_coins_granted(amount)
	_save_checkpoint()

func _on_passive_passengers_generated(amount: int) -> void:
	super._on_passive_passengers_generated(amount)
	if amount <= 0:
		return
	_record_mission_event("passive_passengers", {"amount": amount})
	_refresh_mission_ui()


func _refresh_operations_analytics() -> void:
	# Recompute recommendations at most once per 750ms, not for every vehicle/ATC signal.
	var now := Time.get_ticks_msec()
	if now < next_analytics_refresh_ms:
		return
	next_analytics_refresh_ms = now + 750
	super._refresh_operations_analytics()


func _assign_arrival_if_possible(aircraft: AircraftPrototype, label: String) -> bool:
	if not is_instance_valid(aircraft) or not _is_npc(aircraft):
		return super._assign_arrival_if_possible(aircraft, label)
	# Keep the scheduler's infrastructure guarantee during actual runway selection.
	# A nearer, unserviced stand must not win over the eligible stand we found.
	var eligible_stands := NpcTrafficDirector.free_ready_stands(airport_grid, aircraft.aircraft_size, stand_occupancy)
	var candidates: Array[Dictionary] = []
	for option in airport_grid.get_arrival_route_options(aircraft.aircraft_size):
		if eligible_stands.has(int(option.get("stand_uid", -1))):
			var route: PackedVector2Array = option.get("route", PackedVector2Array())
			if route.size() >= 4:
				candidates.append(option)
	if candidates.is_empty():
		return false
	var selected := runway_dispatcher.select_best_runway_option(candidates, "arrival")
	if selected.is_empty():
		return false
	var stand_uid := int(selected.get("stand_uid", -1))
	var runway_uid := int(selected.get("runway_uid", -1))
	if stand_uid < 0 or runway_uid < 0:
		return false
	runway_dispatcher.record_assignment_decision(candidates, selected, "arrival")
	stand_occupancy[stand_uid] = aircraft
	aircraft.set_arrival_route(selected["route"], stand_uid, runway_uid)
	runway_dispatcher.request_arrival(aircraft, label)
	_refresh_operations_analytics()
	return true
