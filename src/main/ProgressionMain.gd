extends "res://src/main/Main.gd"

# A narrow scene adapter keeps career/NPC state out of the large airport-operations controller.
var progression: Dictionary = {}
var progression_ready := false
var legacy_airport := false
var career_screen: AirportCareerScreen
var career_pin: Button
var npc_director := NpcTrafficDirector.new()
var deployed_owned: Dictionary = {}
var deploying := false
var checkpoint_elapsed := 0.0
var career_refresh_elapsed := 0.0
var restoring_wallet := false

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
		progression["passenger_balance"] = float(current_profile.get("passenger_balance", 20))
		if not AirportProgressionStore.save_state(progression):
			hud.set_operation_status("Cannot save airport progression. Check device storage.", "warning")
			return
	coins = int(progression.get("coins", coins))
	gems = int(progression.get("gems", gems))
	player_xp = int(progression.get("xp", 0))
	player_level = AirportProgressionRules.level_for_xp(player_xp)
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
	add_child(career_screen)
	_install_career_pin()
	_refresh_career_ui()
	_drain_passenger_rewards()

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
		_refresh_career_ui()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		if progression_ready and is_instance_valid(passenger_economy):
			_save_checkpoint()

func _install_career_pin() -> void:
	# Replace the old static objective panel, without placing another overlay on top of it.
	for child in hud.interface_root.get_children():
		if not child is PanelContainer:
			continue
		for label in child.get_children():
			if label is Label and label.text.begins_with("BUILD YOUR AIRPORT"):
				child.remove_child(label)
				label.queue_free()
				career_pin = Button.new()
				career_pin.clip_text = true
				career_pin.add_theme_font_size_override("font_size", 13)
				career_pin.pressed.connect(_open_career)
				child.add_child(career_pin)
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
		aircraft.name = "SO-%03d" % int(uid.trim_prefix("owned-"))
		aircraft.z_index = 80
		aircraft.set_meta("owned_uid", uid)
		aircraft.set_meta("career_flight_token", String(saved.get("token", "")))
		aircraft.set_meta("passengers_paid", bool(saved.get("paid", false)))
		var plan: Dictionary = saved.get("plan", {})
		if plan.is_empty() and runtime.is_empty() and uid in ["owned-1", "owned-2"]:
			plan = _create_current_flight_plan(profile, DestinationCatalog.get_destination("brussels"))
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
			ground_services.request_turnaround(aircraft, label, false)
	deploying = false

func _release_stand(aircraft: AircraftPrototype) -> void:
	super._release_stand(aircraft)
	call_deferred("_deploy_reserve_aircraft")

func _on_demo_aircraft_state_changed(state: String, aircraft: AircraftPrototype, label: String) -> void:
	super._on_demo_aircraft_state_changed(state, aircraft, label)
	if not aircraft.is_social_visitor() and state == "LOADING":
		aircraft.set_meta("passengers_paid", true)

func _on_passenger_boarding_requested(aircraft: AircraftPrototype, label: String) -> void:
	if is_instance_valid(aircraft) and not aircraft.is_social_visitor() and bool(aircraft.get_meta("passengers_paid", false)):
		ground_services.approve_passenger_loading(aircraft)
		return
	super._on_passenger_boarding_requested(aircraft, label)
	_save_checkpoint()

func _on_demo_aircraft_departed(aircraft: AircraftPrototype, label: String) -> void:
	var sequence := int(progression.get("flight_sequence", 0)) + 1
	progression["flight_sequence"] = sequence
	aircraft.set_meta("career_flight_token", "flight:%s:%d" % [String(progression.get("airport_id", "")), sequence])
	super._on_demo_aircraft_departed(aircraft, label)
	_save_checkpoint()

func _apply_completed_flight_reward(aircraft: AircraftPrototype, label: String) -> void:
	var token := String(aircraft.get_meta("career_flight_token", ""))
	if token.is_empty() or (progression.get("seen_events", {}) as Dictionary).has(token):
		return
	var plan := aircraft.get_flight_plan()
	super._apply_completed_flight_reward(aircraft, label)
	AirportProgressionRules.record_event(progression, {"id": token, "kind": "flight_return",
		"aircraft": aircraft.aircraft_type_id, "country": plan.get("country_code", ""), "visitor": false}, player_level)
	# A completed route is not an implicit order to charge passengers and fly it again.
	aircraft.assign_flight_plan({})
	aircraft.set_meta("passengers_paid", false)
	aircraft.set_meta("career_flight_token", "")
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()

func _on_world_map_flight_assignment_requested(aircraft: AircraftPrototype, destination_id: String) -> void:
	if not is_instance_valid(aircraft) or not aircraft.can_change_flight_plan():
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
	return {"state": _capture_state(), "airport": _airport_career_snapshot(), "level": player_level,
		"active_owned": deployed_owned.keys(), "npc_enabled": npc_director.enabled}

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

func _open_career() -> void:
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
	if player_level != old_level:
		hud.set_operation_status("AIRPORT LEVEL %d • new aircraft and buildings may be available" % player_level, "success")
	if world_map != null:
		world_map.player_level = player_level
	if fleet_screen != null:
		fleet_screen.player_level = player_level

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
	_update_level()
	_save_checkpoint()
	_refresh_career_ui()

func _social_only_snapshot(snapshot: Dictionary) -> Dictionary:
	var filtered := snapshot.duplicate(true)
	for key in ["active_visits", "recent_completed"]:
		var rows: Array = []
		for row in snapshot.get(key, []):
			if String(row.get("relationship", "")) != "npc":
				rows.append(row)
		filtered[key] = rows
	return filtered

func _on_social_snapshot_changed(snapshot: Dictionary) -> void:
	super._on_social_snapshot_changed(_social_only_snapshot(snapshot))

func _on_navigation_requested(tab: String) -> void:
	if career_screen != null:
		career_screen.close_screen()
	super._on_navigation_requested(tab)
	if tab in ["social", "alliance"] and social_airport_service != null:
		social_airport_screen.set_snapshot(_social_only_snapshot(social_airport_service.get_snapshot()))

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
