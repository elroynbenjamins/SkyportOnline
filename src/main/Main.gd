extends Node2D

@onready var airport_grid = $AirportGrid
@onready var camera_controller = $Camera
@onready var hud = $HUD
@onready var airport_setup = $AirportSetup

var player_level: int = 4
var player_xp: int = 0
var coins: int = 18420
var gems: int = 120
var resource_inventory: Dictionary = {}
var reward_rng := RandomNumberGenerator.new()

var selected_building_id := ""
var selected_building_rotation := 0
var aircraft_demos: Array[AircraftPrototype] = []
var ground_services: GroundServiceDispatcher
var runway_dispatcher: RunwayDispatcher
var taxi_traffic: TaxiTrafficController
var stand_occupancy: Dictionary = {}
var pending_arrivals: Array[Dictionary] = []
var pending_passenger_departures: Array[Dictionary] = []
var processing_passenger_queue := false
var world_map: WorldMapScreen
var fleet_screen: FleetScreen
var aircraft_context_card: AircraftContextCard
var building_context_card: BuildingContextCard
var return_summary: FlightReturnSummary
var resource_inventory_screen: ResourceInventoryScreen
var passenger_upgrade_panel: PassengerUpgradePanel
var service_upgrade_panel: ServiceUpgradePanel
var air_traffic_upgrade_panel: AirTrafficUpgradePanel
var runway_strategy_panel: RunwayStrategyPanel
var passenger_economy: PassengerEconomy
var rewarded_passenger_ad_bridge: RewardedPassengerAdBridge
var event_manager: EventManager
var event_screen: EventScreen
var current_profile: Dictionary = {}
var gameplay_started := false
var current_event_snapshot: Dictionary = {}


func _process(delta: float) -> void:
	if not gameplay_started or delta <= 0.0:
		return

	for index in range(pending_arrivals.size()):
		var request: Dictionary = pending_arrivals[index]
		request["wait_seconds"] = float(
			request.get("wait_seconds", 0.0)
		) + delta
		pending_arrivals[index] = request


func _ready() -> void:
	camera_controller.world_tapped.connect(_on_world_tapped)
	airport_grid.parcel_selected.connect(_on_parcel_selected)
	airport_grid.network_status_changed.connect(_on_network_status_changed)
	airport_grid.building_selected_world.connect(_on_building_selected_world)

	hud.purchase_expansion_requested.connect(_on_purchase_expansion_requested)
	hud.building_selected.connect(_on_building_selected)
	hud.rotate_building_requested.connect(_on_rotate_building_requested)
	hud.confirm_building_requested.connect(_on_confirm_building_requested)
	hud.cancel_building_requested.connect(_on_cancel_building_requested)
	hud.navigation_requested.connect(_on_navigation_requested)
	airport_setup.airport_created.connect(_on_airport_created)

	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(player_level, coins, gems)
	hud.set_airside_status(airport_grid.get_airside_status())
	airport_grid.select_parcel("north")

	if ProfileStore.has_airport():
		current_profile = ProfileStore.load_profile()
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)
		airport_setup.close()
		_start_gameplay()
	else:
		hud.set_interface_visible(false)
		camera_controller.set_process_unhandled_input(false)
		airport_setup.open()


func _on_airport_created(profile: Dictionary) -> void:
	current_profile = profile.duplicate(true)
	resource_inventory = current_profile.get(
		"resource_inventory",
		{}
	).duplicate(true)
	_start_gameplay()


func _start_gameplay() -> void:
	if gameplay_started:
		return
	gameplay_started = true

	hud.set_interface_visible(true)
	camera_controller.set_process_unhandled_input(true)

	var country := CountryCatalog.get_country(
		String(current_profile.get("country_id", ""))
	)
	var country_name := String(
		country.get("name", current_profile.get("country_id", ""))
	)
	hud.set_airport_identity(
		String(current_profile.get("airport_name", "Skyport")),
		String(current_profile.get("airport_code", "APT")),
		country_name,
		String(current_profile.get("account_type", "guest"))
	)

	_setup_ground_services()
	_setup_runway_dispatcher()
	_setup_taxi_traffic()
	_setup_world_map()
	_setup_fleet_screen()
	_setup_aircraft_context_card()
	_setup_building_context_card()
	_setup_return_summary()
	_setup_passenger_system()
	_setup_event_system()
	_setup_rewarded_passenger_ad_bridge()
	_setup_resource_inventory()
	_setup_passenger_upgrade_panel()
	_setup_service_upgrade_panel()
	_setup_air_traffic_upgrade_panel()
	_setup_runway_strategy_panel()
	reward_rng.randomize()
	_spawn_aircraft_demos()


func _setup_ground_services() -> void:
	ground_services = GroundServiceDispatcher.new()
	ground_services.z_index = 85
	ground_services.configure(airport_grid)
	ground_services.status_changed.connect(_on_ground_service_status)
	ground_services.queue_changed.connect(_on_ground_service_queue_changed)
	ground_services.passenger_boarding_requested.connect(
		_on_passenger_boarding_requested
	)
	ground_services.departure_route_requested.connect(
		_on_departure_route_requested
	)
	add_child(ground_services)


func _setup_runway_dispatcher() -> void:
	runway_dispatcher = RunwayDispatcher.new()
	runway_dispatcher.status_changed.connect(_on_runway_status)
	runway_dispatcher.queue_changed.connect(_on_runway_queue_changed)
	runway_dispatcher.runway_visual_state_changed.connect(
		_on_runway_visual_state_changed
	)
	runway_dispatcher.atc_state_changed.connect(
		_on_atc_state_changed
	)
	add_child(runway_dispatcher)
	runway_dispatcher.configure(
		airport_grid,
		current_profile.get(
			"runway_strategies",
			{}
		)
	)
	hud.set_atc_state(
		runway_dispatcher.get_atc_snapshot()
	)
	ground_services.aircraft_serviced.connect(_on_aircraft_serviced)


func _setup_taxi_traffic() -> void:
	taxi_traffic = TaxiTrafficController.new()
	taxi_traffic.hold_changed.connect(
		_on_taxi_hold_changed
	)
	add_child(taxi_traffic)


func _setup_world_map() -> void:
	world_map = WorldMapScreen.new()
	world_map.flight_assignment_requested.connect(
		_on_world_map_flight_assignment_requested
	)
	add_child(world_map)


func _setup_fleet_screen() -> void:
	fleet_screen = FleetScreen.new()
	add_child(fleet_screen)


func _setup_aircraft_context_card() -> void:
	aircraft_context_card = AircraftContextCard.new()
	aircraft_context_card.choose_route_requested.connect(
		_on_aircraft_context_choose_route_requested
	)
	aircraft_context_card.fleet_requested.connect(
		_on_aircraft_context_fleet_requested
	)
	add_child(aircraft_context_card)


func _setup_building_context_card() -> void:
	building_context_card = BuildingContextCard.new()
	building_context_card.primary_action_requested.connect(
		_on_building_context_primary_action_requested
	)
	add_child(building_context_card)


func _setup_return_summary() -> void:
	return_summary = FlightReturnSummary.new()
	add_child(return_summary)


func _setup_passenger_system() -> void:
	var saved_upgrades: Dictionary = current_profile.get(
		"building_upgrades",
		{}
	).duplicate(true)
	airport_grid.apply_saved_building_upgrades(saved_upgrades)
	if runway_dispatcher != null:
		runway_dispatcher.refresh_air_traffic_control()

	passenger_economy = PassengerEconomy.new()
	passenger_economy.changed.connect(_on_passenger_economy_changed)
	passenger_economy.passive_passengers_generated.connect(
		_on_passive_passengers_generated
	)
	add_child(passenger_economy)
	passenger_economy.configure(
		airport_grid,
		float(current_profile.get("passenger_balance", 20))
	)


func _setup_event_system() -> void:
	event_screen = EventScreen.new()
	event_screen.quest_claim_requested.connect(
		_on_event_quest_claim_requested
	)
	event_screen.shop_purchase_requested.connect(
		_on_event_shop_purchase_requested
	)
	event_screen.shop_resource_choice_requested.connect(
		_on_event_shop_resource_choice_requested
	)
	event_screen.alliance_claim_requested.connect(
		_on_event_alliance_claim_requested
	)
	add_child(event_screen)

	event_manager = EventManager.new()
	event_manager.changed.connect(_on_event_changed)
	event_manager.message.connect(_on_event_message)
	event_manager.coins_granted.connect(
		_on_event_shop_coins_granted
	)
	event_manager.resource_granted.connect(
		_on_event_shop_resource_granted
	)
	add_child(event_manager)
	event_manager.configure(passenger_economy)
	_on_event_changed(event_manager.get_snapshot())


func _setup_rewarded_passenger_ad_bridge() -> void:
	rewarded_passenger_ad_bridge = RewardedPassengerAdBridge.new()
	rewarded_passenger_ad_bridge.reward_granted.connect(
		_on_rewarded_passenger_ad_reward_granted
	)
	rewarded_passenger_ad_bridge.unavailable.connect(
		_on_rewarded_passenger_ad_unavailable
	)
	add_child(rewarded_passenger_ad_bridge)


func _setup_resource_inventory() -> void:
	resource_inventory_screen = ResourceInventoryScreen.new()
	resource_inventory_screen.rewarded_passenger_boost_requested.connect(
		_on_rewarded_passenger_boost_requested
	)
	add_child(resource_inventory_screen)


func _setup_passenger_upgrade_panel() -> void:
	passenger_upgrade_panel = PassengerUpgradePanel.new()
	passenger_upgrade_panel.upgrade_requested.connect(
		_on_passenger_upgrade_requested
	)
	add_child(passenger_upgrade_panel)


func _setup_service_upgrade_panel() -> void:
	service_upgrade_panel = ServiceUpgradePanel.new()
	service_upgrade_panel.upgrade_requested.connect(
		_on_service_upgrade_requested
	)
	add_child(service_upgrade_panel)


func _setup_air_traffic_upgrade_panel() -> void:
	air_traffic_upgrade_panel = AirTrafficUpgradePanel.new()
	air_traffic_upgrade_panel.upgrade_requested.connect(
		_on_air_traffic_upgrade_requested
	)
	add_child(air_traffic_upgrade_panel)


func _setup_runway_strategy_panel() -> void:
	runway_strategy_panel = RunwayStrategyPanel.new()
	runway_strategy_panel.strategy_requested.connect(
		_on_runway_strategy_requested
	)
	add_child(runway_strategy_panel)


func _spawn_aircraft_demos() -> void:
	var routes: Array[Dictionary] = airport_grid.get_departure_routes("S")
	if routes.is_empty():
		hud.set_operation_status("No connected S-class stand/runway.", "warning")
		return

	var count := mini(routes.size(), 2)
	for index in range(count):
		var route_info: Dictionary = routes[index]
		var route: PackedVector2Array = route_info.get("route", PackedVector2Array())
		if route.size() < 2:
			continue

		var label := "SO-%03d" % (index + 1)
		var aircraft := AircraftPrototype.new()

		var profile_ids: Array[String] = ["pico_p8", "pico_p8"]
		var default_destinations: Array[String] = ["brussels", "brussels"]
		var profile_id: String = profile_ids[index % profile_ids.size()]
		var destination_id: String = default_destinations[
			index % default_destinations.size()
		]
		aircraft.configure_aircraft_type(profile_id)
		aircraft.configure_taxi_traffic(taxi_traffic)

		var destination := DestinationCatalog.get_destination(destination_id)
		var initial_plan := _create_current_flight_plan(
			aircraft.get_aircraft_profile(),
			destination
		)
		aircraft.assign_flight_plan(initial_plan)
		aircraft.name = label
		aircraft.z_index = 80 + index
		aircraft.state_changed.connect(
			_on_demo_aircraft_state_changed.bind(aircraft, label)
		)
		aircraft.departed.connect(_on_demo_aircraft_departed.bind(aircraft, label))
		aircraft.arrival_requested.connect(
			_on_demo_arrival_requested.bind(aircraft, label)
		)
		aircraft.arrival_completed.connect(
			_on_demo_arrival_completed.bind(aircraft, label)
		)
		add_child(aircraft)

		var stand_uid := int(route_info.get("stand_uid", -1))
		var runway_uid := int(route_info.get("runway_uid", -1))
		aircraft.set_departure_route(
			route,
			"S",
			stand_uid,
			runway_uid
		)
		stand_occupancy[stand_uid] = aircraft
		aircraft_demos.append(aircraft)
		_apply_event_visual_to_aircraft(
			aircraft,
			current_event_snapshot
		)
		ground_services.request_turnaround(aircraft, label, false)

	hud.set_operation_status(
		"%d aircraft awaiting turnaround" % aircraft_demos.size()
	)


func _on_departure_route_requested(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var options: Array[Dictionary] = (
		airport_grid.get_departure_route_options_for_stand(
		aircraft.stand_uid,
			aircraft.aircraft_size
		)
	)
	var selected: Dictionary = (
		runway_dispatcher.select_best_runway_option(
			options,
			"departure"
		)
	)
	if selected.is_empty():
		runway_dispatcher.release_departure_assignment(
			aircraft
		)
		hud.set_operation_status(
			"%s has no connected compatible runway" % label,
			"warning"
		)
		return

	runway_dispatcher.record_assignment_decision(
		options,
		selected,
		"departure"
	)

	var route: PackedVector2Array = selected.get(
		"route",
		PackedVector2Array()
	)
	if route.size() < 4:
		return

	var runway_uid := int(
		selected.get("runway_uid", -1)
	)
	aircraft.set_departure_route(
		route,
		aircraft.aircraft_size,
		int(selected.get("stand_uid", aircraft.stand_uid)),
		runway_uid
	)
	runway_dispatcher.reserve_departure_assignment(
		aircraft,
		runway_uid
	)

	if options.size() > 1:
		hud.set_operation_status(
			"%s assigned runway %d • balancing traffic" % [
				label,
				runway_uid
			]
		)


func _on_aircraft_serviced(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	runway_dispatcher.request_departure(aircraft, label)


func _on_passenger_boarding_requested(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	_attempt_boarding_and_departure(aircraft, label)


func _on_runway_status(text: String, tone: String) -> void:
	hud.set_operation_status(text, tone)


func _on_runway_visual_state_changed(
	runway_uid: int,
	state: Dictionary
) -> void:
	airport_grid.set_runway_visual_state(
		runway_uid,
		state
	)


func _on_atc_state_changed(
	snapshot: Dictionary
) -> void:
	hud.set_atc_state(snapshot)
	_refresh_operations_analytics()


func _operations_analytics_snapshot() -> Dictionary:
	var runway_snapshot: Dictionary = {}
	if runway_dispatcher != null:
		runway_snapshot = (
			runway_dispatcher.get_runway_analytics_snapshot()
		)

	var service_snapshot: Dictionary = {}
	if ground_services != null:
		service_snapshot = (
			ground_services.get_service_analytics_snapshot()
		)

	var waiting_required_total := 0
	for request_variant in pending_passenger_departures:
		var request: Dictionary = request_variant
		var aircraft := request.get(
			"aircraft"
		) as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			continue
		waiting_required_total += _passenger_requirement(
			aircraft
		)

	var passenger_snapshot := {
		"stock": 0,
		"capacity": 0,
		"production_per_minute": 0.0,
		"waiting_aircraft": pending_passenger_departures.size(),
		"waiting_required_total": waiting_required_total,
		"waiting_shortfall": 0
	}
	if passenger_economy != null:
		passenger_snapshot["stock"] = (
			passenger_economy.get_passengers()
		)
		passenger_snapshot["capacity"] = (
			passenger_economy.get_capacity()
		)
		passenger_snapshot["production_per_minute"] = (
			passenger_economy.get_production_per_minute()
		)
	passenger_snapshot["waiting_shortfall"] = maxi(
		waiting_required_total
		- int(passenger_snapshot.get("stock", 0)),
		0
	)

	var airside: Dictionary = airport_grid.get_airside_status()
	var total_current_hold_seconds := 0.0
	var max_current_hold_seconds := 0.0
	for request_variant in pending_arrivals:
		var request: Dictionary = request_variant
		var wait_seconds := maxf(
			float(
				request.get(
					"wait_seconds",
					0.0
				)
			),
			0.0
		)
		total_current_hold_seconds += wait_seconds
		max_current_hold_seconds = maxf(
			max_current_hold_seconds,
			wait_seconds
		)

	var stand_snapshot := {
		"total": int(
			airside.get("stands_total", 0)
		),
		"occupied": stand_occupancy.size(),
		"pending_arrivals": pending_arrivals.size(),
		"total_current_hold_seconds": total_current_hold_seconds,
		"max_current_hold_seconds": max_current_hold_seconds
	}

	var snapshot := {
		"runway": runway_snapshot,
		"services": service_snapshot,
		"passengers": passenger_snapshot,
		"stands": stand_snapshot
	}
	snapshot["analysis"] = OperationsAnalyticsRules.analyze(
		snapshot
	)
	snapshot["payoff"] = OperationsPayoffEstimator.estimate(
		snapshot,
		airport_grid,
		resource_inventory,
		player_level,
		coins
	)
	return snapshot


func _refresh_operations_analytics() -> void:
	if hud == null:
		return
	hud.set_operations_analytics(
		_operations_analytics_snapshot()
	)


func _on_taxi_hold_changed(
	aircraft: AircraftPrototype,
	holding: bool,
	reason: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	if not holding:
		return

	hud.set_operation_status(
		"%s taxi hold • %s" % [
			String(aircraft.name),
			reason
		],
		"warning"
	)


func _on_runway_queue_changed(waiting: int, active: int) -> void:
	if waiting > 0:
		hud.set_operation_status(
			"Runway queue: %d waiting • %d active" % [waiting, active],
			"warning"
		)


func _on_ground_service_status(text: String, tone: String) -> void:
	hud.set_operation_status(text, tone)


func _on_ground_service_queue_changed(waiting: int, active: int) -> void:
	if waiting > 0:
		hud.set_operation_status(
			"Ground service queue: %d waiting • %d vehicles active" % [
				waiting,
				active
			],
			"warning"
		)
	_refresh_operations_analytics()


func _on_demo_aircraft_state_changed(
	state: String,
	aircraft: AircraftPrototype,
	label: String
) -> void:
	match state:
		"TAXIING_OUT":
			_release_stand(aircraft)
			hud.set_operation_status(
				"%s taxiing to hold short" % label
			)
		"HOLD_SHORT":
			hud.set_operation_status(
				"%s holding short • awaiting runway" % label,
				"warning"
			)
		"CLEARED":
			hud.set_operation_status(
				"%s cleared onto runway" % label,
				"success"
			)
		"ENTERING_RUNWAY":
			hud.set_operation_status(
				"%s entering runway" % label
			)
		"LINE_UP":
			hud.set_operation_status("%s lined up for departure" % label)
		"TAKEOFF_ROLL":
			hud.set_operation_status("%s accelerating for takeoff" % label)
		"CLIMBING":
			hud.set_operation_status("%s airborne • climbing" % label, "success")
		"EN_ROUTE":
			hud.set_operation_status("%s en route" % label, "success")
		"HOLDING_FOR_ARRIVAL":
			hud.set_operation_status("%s inbound • awaiting stand/runway" % label)
		"APPROACH":
			hud.set_operation_status("%s on approach" % label)
		"LANDING_ROLL":
			hud.set_operation_status("%s landing" % label)
		"TAXIING_IN":
			hud.set_operation_status("%s taxiing to stand" % label)
		"PARKED":
			hud.set_operation_status("%s parked at stand" % label, "success")
		"UNLOADING":
			hud.set_operation_status(
				"%s unloading passengers / cargo" % label
			)
		"SERVICING":
			hud.set_operation_status(
				"%s fuel / cabin / catering service" % label
			)
		"LOADING":
			hud.set_operation_status(
				"%s loading passengers / cargo" % label
			)
		"PUSHBACK_PREP":
			hud.set_operation_status(
				"%s awaiting / completing tug pushback" % label
			)
		"READY_FOR_DESTINATION":
			hud.set_operation_status(
				"%s fueled • choose destination" % label,
				"warning"
			)
		"WAITING_PASSENGERS":
			var required := _passenger_requirement(aircraft)
			hud.set_operation_status(
				"%s waiting for passengers • needs %d" % [
					label,
					required
				],
				"warning"
			)
		"READY_FOR_DEPARTURE":
			hud.set_operation_status(
				"%s ready • waiting for runway" % label,
				"warning"
			)
		"WAITING_FUEL":
			hud.set_operation_status("%s parked • fuel required" % label)


func _on_demo_aircraft_departed(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	var plan := aircraft.get_flight_plan()
	hud.set_operation_status(
		"%s → %s • %s" % [
			label,
			String(plan.get("city", "destination")),
			FlightRules.format_duration(
				aircraft.get_flight_remaining_seconds()
			)
		],
		"success"
	)


func _on_demo_arrival_requested(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if not _assign_arrival_if_possible(aircraft, label):
		pending_arrivals.append({
			"aircraft": aircraft,
			"label": label,
			"wait_seconds": 0.0
		})
		_refresh_operations_analytics()
		hud.set_operation_status(
			"%s holding • no free compatible stand" % label,
			"warning"
		)


func _assign_arrival_if_possible(
	aircraft: AircraftPrototype,
	label: String
) -> bool:
	var candidates: Array[Dictionary] = []
	for route_info in airport_grid.get_arrival_route_options(
		aircraft.aircraft_size
	):
		var stand_uid := int(
			route_info.get("stand_uid", -1)
		)
		if (
			stand_uid < 0
			or stand_occupancy.has(stand_uid)
		):
			continue

		var route: PackedVector2Array = route_info.get(
			"route",
			PackedVector2Array()
		)
		if route.size() < 4:
			continue
		candidates.append(
			route_info.duplicate(true)
		)

	if candidates.is_empty():
		return false

	var selected: Dictionary = (
		runway_dispatcher.select_best_runway_option(
			candidates,
			"arrival"
		)
	)
	if selected.is_empty():
		return false

	runway_dispatcher.record_assignment_decision(
		candidates,
		selected,
		"arrival"
	)

	var stand_uid := int(
		selected.get("stand_uid", -1)
	)
	var runway_uid := int(
		selected.get("runway_uid", -1)
	)
	var route: PackedVector2Array = selected.get(
		"route",
		PackedVector2Array()
	)
	if (
		stand_uid < 0
		or runway_uid < 0
		or route.size() < 4
	):
		return false

	stand_occupancy[stand_uid] = aircraft
	_refresh_operations_analytics()
	aircraft.set_arrival_route(
		route,
		stand_uid,
		runway_uid
	)
	runway_dispatcher.request_arrival(
		aircraft,
		label
	)

	if candidates.size() > 1:
		hud.set_operation_status(
			"%s inbound • runway %d selected" % [
				label,
				runway_uid
			]
		)
	return true


func _release_stand(aircraft: AircraftPrototype) -> void:
	var stand_uid := aircraft.stand_uid
	if stand_uid < 0:
		return

	if stand_occupancy.get(stand_uid) == aircraft:
		stand_occupancy.erase(stand_uid)
	_try_assign_pending_arrivals()
	_refresh_operations_analytics()


func _try_assign_pending_arrivals() -> void:
	var index := 0
	while index < pending_arrivals.size():
		var request: Dictionary = pending_arrivals[index]
		var aircraft := request.get("aircraft") as AircraftPrototype
		var label := String(request.get("label", "Aircraft"))

		if aircraft == null or not is_instance_valid(aircraft):
			pending_arrivals.remove_at(index)
			continue

		if _assign_arrival_if_possible(aircraft, label):
			pending_arrivals.remove_at(index)
			continue

		index += 1


func _on_demo_arrival_completed(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	_apply_completed_flight_reward(aircraft, label)

	var route_info: Dictionary = airport_grid.get_departure_route_for_stand(
		aircraft.stand_uid,
		aircraft.aircraft_size
	)
	if route_info.is_empty():
		hud.set_operation_status(
			"%s parked but has no departure route" % label,
			"warning"
		)
		return

	var route: PackedVector2Array = route_info.get(
		"route",
		PackedVector2Array()
	)
	aircraft.set_departure_route(
		route,
		aircraft.aircraft_size,
		int(route_info.get("stand_uid", -1)),
		int(route_info.get("runway_uid", -1))
	)
	ground_services.request_turnaround(aircraft, label, true)


func _apply_completed_flight_reward(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	var plan := aircraft.get_flight_plan()
	var profile := aircraft.get_aircraft_profile()
	if plan.is_empty() or profile.is_empty():
		return

	var reward := FlightRewardRules.create_return_reward(
		profile,
		plan,
		reward_rng
	)
	if reward.is_empty():
		return

	var old_mastery_hours := _mastery_hours_for_aircraft(aircraft)
	var old_mastery_stars := AircraftMastery.stars_for_hours(
		old_mastery_hours
	)
	reward["base_coins"] = int(reward.get("coins", 0))
	reward["base_xp"] = int(reward.get("xp", 0))
	reward["coins"] = AircraftMastery.apply_coin_bonus(
		int(reward.get("coins", 0)),
		old_mastery_hours
	)
	reward["xp"] = AircraftMastery.apply_xp_bonus(
		int(reward.get("xp", 0)),
		old_mastery_hours
	)

	coins += int(reward.get("coins", 0))
	player_xp += int(reward.get("xp", 0))

	var resources_won: Array = reward.get("resources_won", [])
	var updated_profile := ProfileStore.add_resource_drops(resources_won)
	if not updated_profile.is_empty():
		current_profile = updated_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)
	else:
		for resource in resources_won:
			var resource_id := String(resource.get("id", ""))
			if resource_id.is_empty():
				continue
			var amount := int(resource.get("amount", 1))
			resource_inventory[resource_id] = (
				int(resource_inventory.get(resource_id, 0)) + amount
			)

	var completed_hours := maxf(
		float(plan.get("flight_hours", 0.0)),
		0.0
	)
	var mastery_profile := ProfileStore.add_aircraft_mastery_hours(
		aircraft.aircraft_type_id,
		completed_hours
	)
	if not mastery_profile.is_empty():
		current_profile = mastery_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)

	var new_mastery_hours := _mastery_hours_for_aircraft(aircraft)
	var new_mastery_stars := AircraftMastery.stars_for_hours(
		new_mastery_hours
	)
	reward["mastery_hours_before"] = old_mastery_hours
	reward["mastery_hours_after"] = new_mastery_hours
	reward["mastery_stars_before"] = old_mastery_stars
	reward["mastery_stars_after"] = new_mastery_stars
	reward["mastery_star_up"] = new_mastery_stars > old_mastery_stars
	reward["aircraft_name"] = aircraft.aircraft_display_name

	var economy_profile := ProfileStore.add_economy_stats({
		"flights_completed": 1,
		"flight_coins": int(reward.get("coins", 0)),
		"flight_xp": int(reward.get("xp", 0)),
		"resources_earned": resources_won.size()
	})
	if not economy_profile.is_empty():
		current_profile = economy_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)

	if event_manager != null:
		event_manager.record_metric("flights_completed", 1)
		event_manager.record_metric(
			"flight_coins",
			int(reward.get("coins", 0))
		)
		event_manager.record_metric(
			"resources_earned",
			resources_won.size()
		)
		event_manager.record_destination_flight(
			String(plan.get("destination_id", ""))
		)

	var route_profile := ProfileStore.record_route_completion(
		String(plan.get("destination_id", "")),
		aircraft.get_boarded_passengers(),
		int(reward.get("coins", 0)),
		int(reward.get("xp", 0)),
		resources_won.size(),
		String(plan.get("demand_condition_id", "normal"))
	)
	if not route_profile.is_empty():
		current_profile = route_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)
		if world_map != null:
			world_map.set_route_history(
				current_profile.get("route_history", {})
			)

	_process_priority_contract_return(
		plan,
		reward
	)

	if fleet_screen != null:
		fleet_screen.set_mastery_hours(
			current_profile.get("aircraft_mastery_hours", {})
		)
	if aircraft_context_card != null:
		aircraft_context_card.set_mastery_hours(
			current_profile.get(
				"aircraft_mastery_hours",
				{}
			)
		)

	hud.set_player_data(player_level, coins, gems)
	return_summary.show_reward(
		label,
		reward,
		resource_inventory
	)
	hud.set_operation_status(
		"%s returned from %s • rewards collected" % [
			label,
			String(reward.get("city", "destination"))
		],
		"success"
	)


func _process_priority_contract_return(
	plan: Dictionary,
	reward: Dictionary
) -> void:
	var result := ProfileStore.record_priority_contract_return(
		plan
	)
	if result.is_empty():
		return

	var saved_profile: Dictionary = result.get(
		"profile",
		{}
	)
	if not saved_profile.is_empty():
		current_profile = saved_profile

	if world_map != null:
		world_map.set_priority_contract_progress(
			current_profile.get(
				"priority_contract_progress",
				{}
			)
		)

	if not bool(result.get("completed_now", false)):
		return

	var bonus_coins := int(
		plan.get("priority_contract_bonus_coins", 0)
	)
	var bonus_xp := int(
		plan.get("priority_contract_bonus_xp", 0)
	)
	var bonus_resources: Array = (
		plan.get(
			"priority_contract_bonus_resources",
			[]
		) as Array
	).duplicate(true)

	coins += bonus_coins
	player_xp += bonus_xp

	var resource_amount := 0
	for resource in bonus_resources:
		resource_amount += maxi(
			int(resource.get("amount", 1)),
			0
		)

	var resource_profile := ProfileStore.add_resource_drops(
		bonus_resources
	)
	if not resource_profile.is_empty():
		current_profile = resource_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)

	var economy_profile := ProfileStore.add_economy_stats({
		"contract_bonus_coins": bonus_coins,
		"contract_bonus_xp": bonus_xp,
		"resources_earned": resource_amount,
		"priority_contracts_completed": 1
	})
	if not economy_profile.is_empty():
		current_profile = economy_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)

	reward["priority_contract_bonus"] = {
		"coins": bonus_coins,
		"xp": bonus_xp,
		"resources": bonus_resources,
		"contract_id": String(
			plan.get("priority_contract_id", "")
		)
	}

	if world_map != null:
		world_map.set_priority_contract_progress(
			current_profile.get(
				"priority_contract_progress",
				{}
			)
		)

	hud.set_operation_status(
		"Priority Contract complete • bonus rewards awarded",
		"success"
	)


func _on_navigation_requested(tab: String) -> void:
	if aircraft_context_card != null:
		aircraft_context_card.close_card()
	if building_context_card != null:
		building_context_card.close_card()

	match tab:
		"world":
			world_map.open_map(
				aircraft_demos,
				player_level,
				current_profile.get(
					"aircraft_mastery_hours",
					{}
				),
				passenger_economy.get_passengers(),
				passenger_economy.get_capacity(),
				current_profile.get("route_history", {}),
				String(current_profile.get("airport_id", "")),
				current_profile.get(
					"priority_contract_progress",
					{}
				)
			)
		"fleet":
			fleet_screen.open_fleet(
				aircraft_demos,
				player_level,
				current_profile.get(
					"aircraft_mastery_hours",
					{}
				)
			)
		"event":
			if event_manager != null and event_manager.has_active_event():
				event_screen.open_event(event_manager.get_snapshot())
			else:
				hud.set_operation_status("No event is active right now.")
		"alliance":
			hud.set_operation_status("Alliance unlocks later.")
		"more":
			resource_inventory_screen.open_inventory(
				resource_inventory,
				passenger_economy.get_passengers(),
				passenger_economy.get_capacity(),
				passenger_economy.get_production_per_minute(),
				rewarded_passenger_ad_bridge.provider_connected,
				current_profile.get("economy_stats", {})
			)


func _refresh_aircraft_event_visuals(
	snapshot: Dictionary
) -> void:
	for aircraft in aircraft_demos:
		if aircraft == null or not is_instance_valid(aircraft):
			continue
		_apply_event_visual_to_aircraft(
			aircraft,
			snapshot
		)


func _apply_event_visual_to_aircraft(
	aircraft: AircraftPrototype,
	snapshot: Dictionary
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	if not bool(snapshot.get("active", false)):
		aircraft.set_event_visual(
			false,
			"",
			"",
			false
		)
		return

	var theme := String(snapshot.get("theme", ""))
	var featured_destinations: Array = snapshot.get(
		"featured_destinations",
		[]
	)
	var destination_id := String(
		aircraft.get_flight_plan().get(
			"destination_id",
			""
		)
	)
	var featured := featured_destinations.has(
		destination_id
	)
	var route_currency := maxi(
		int(snapshot.get("featured_route_currency", 0)),
		0
	)
	var marker := ""
	if featured:
		if route_currency > 0:
			marker = "+%d" % route_currency
		else:
			marker = String(
				snapshot.get(
					"featured_marker_text",
					"WINTER"
				)
			)

	var owned_cosmetics: Dictionary = current_profile.get(
		"owned_cosmetics",
		{}
	)
	var livery_id := ""
	if not theme.is_empty():
		livery_id = "event_%s_pico_livery" % theme
	var livery_enabled := (
		aircraft.aircraft_type_id == "pico_p8"
		and not livery_id.is_empty()
		and bool(
			owned_cosmetics.get(
				livery_id,
				false
			)
		)
	)

	aircraft.set_event_visual(
		featured,
		theme,
		marker,
		livery_enabled
	)


func _on_event_changed(snapshot: Dictionary) -> void:
	current_event_snapshot = snapshot.duplicate(true)

	var refreshed_profile := ProfileStore.load_profile()
	if not refreshed_profile.is_empty():
		current_profile = refreshed_profile
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)

	var owned_cosmetics: Dictionary = current_profile.get(
		"owned_cosmetics",
		{}
	).duplicate(true)
	airport_grid.set_event_visual_state(
		snapshot,
		owned_cosmetics
	)
	hud.set_build_catalog(
		BuildingCatalog.get_menu_definitions(
			owned_cosmetics
		)
	)
	_refresh_aircraft_event_visuals(snapshot)

	var active := bool(snapshot.get("active", false))
	hud.set_event_available(
		active,
		String(snapshot.get("name", "Event"))
	)

	var claimable := false
	for quest_variant in snapshot.get("quests", []):
		var quest: Dictionary = quest_variant
		if (
			bool(quest.get("unlocked", false))
			and bool(quest.get("complete", false))
			and not bool(quest.get("claimed", false))
		):
			claimable = true
			break

	if not claimable:
		for milestone_variant in snapshot.get(
			"alliance_milestones",
			[]
		):
			var milestone: Dictionary = milestone_variant
			if (
				bool(milestone.get("reached", false))
				and not bool(milestone.get("claimed", false))
			):
				claimable = true
				break

	hud.set_event_attention(active and claimable)

	if event_screen != null and event_screen.is_open():
		event_screen.refresh(snapshot)


func _on_event_message(text: String, tone: String) -> void:
	hud.set_operation_status(text, tone)


func _on_event_quest_claim_requested(quest_id: String) -> void:
	if event_manager != null:
		event_manager.claim_quest(quest_id)


func _on_event_shop_purchase_requested(item_id: String) -> void:
	if event_manager != null:
		event_manager.purchase_shop_item(item_id)


func _on_event_shop_resource_choice_requested(
	item_id: String,
	resource_id: String
) -> void:
	if event_manager != null:
		event_manager.purchase_resource_choice(
			item_id,
			resource_id
		)


func _on_event_shop_coins_granted(amount: int) -> void:
	var granted := maxi(amount, 0)
	if granted <= 0:
		return

	coins += granted
	hud.set_player_data(player_level, coins, gems)

	var updated := ProfileStore.add_economy_stats({
		"event_shop_coins": granted
	})
	if not updated.is_empty():
		current_profile = updated


func _on_event_shop_resource_granted(
	resource_id: String,
	amount: int
) -> void:
	if resource_id.is_empty() or amount <= 0:
		return

	var updated := ProfileStore.add_resource_drops([
		{
			"id": resource_id,
			"amount": amount
		}
	])
	if not updated.is_empty():
		current_profile = updated
		resource_inventory = current_profile.get(
			"resource_inventory",
			{}
		).duplicate(true)
	else:
		resource_inventory[resource_id] = (
			int(resource_inventory.get(resource_id, 0))
			+ amount
		)


func _on_event_alliance_claim_requested(milestone_id: String) -> void:
	if event_manager != null:
		event_manager.claim_alliance_milestone(milestone_id)


func _create_current_flight_plan(
	profile: Dictionary,
	destination: Dictionary
) -> Dictionary:
	var base_plan := FlightRules.create_flight_plan(
		profile,
		destination
	)
	if base_plan.is_empty():
		return {}

	var condition := DynamicDemandRules.condition_for(
		String(destination.get("id", ""))
	)
	var conditioned_plan := DynamicDemandRules.apply_to_flight_plan(
		base_plan,
		condition
	)

	var contract := RouteContractRules.active_contract(
		player_level,
		String(current_profile.get("airport_id", ""))
	)
	var contract_state := RouteContractRules.progress_for(
		contract,
		current_profile.get(
			"priority_contract_progress",
			{}
		)
	)
	return RouteContractRules.apply_to_flight_plan(
		conditioned_plan,
		contract,
		contract_state
	)


func _on_world_map_flight_assignment_requested(
	aircraft: AircraftPrototype,
	destination_id: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var destination := DestinationCatalog.get_destination(destination_id)
	var profile := aircraft.get_aircraft_profile()
	if destination.is_empty() or profile.is_empty():
		world_map.set_assignment_status("Unable to create this flight.")
		return

	if player_level < int(destination.get("unlock_level", 1)):
		world_map.set_assignment_status("Destination is still level-locked.")
		return

	if not FlightRules.can_fly(profile, destination):
		world_map.set_assignment_status("Destination is outside aircraft range.")
		return

	if not aircraft.can_change_flight_plan():
		world_map.set_assignment_status("Aircraft is already committed to a flight.")
		return

	var previous_state := aircraft.state
	var plan := _create_current_flight_plan(profile, destination)
	aircraft.assign_flight_plan(plan)
	_apply_event_visual_to_aircraft(
		aircraft,
		current_event_snapshot
	)

	var route_passengers := _passenger_requirement(aircraft)
	world_map.set_assignment_status(
		"%s → %s • %d passengers • %s" % [
			aircraft.name,
			String(destination.get("city", "")),
			route_passengers,
			FlightRules.format_duration(
				float(plan.get("duration_seconds", 0.0))
			)
		]
	)

	if previous_state == "READY_FOR_DESTINATION":
		ground_services.resume_after_destination(aircraft)
	elif previous_state == "WAITING_PASSENGERS":
		_attempt_boarding_and_departure(
			aircraft,
			String(aircraft.name)
		)


func _on_world_tapped(world_position: Vector2) -> void:
	if not selected_building_id.is_empty():
		var status: Dictionary = airport_grid.set_build_preview(
			selected_building_id,
			world_position,
			selected_building_rotation
		)
		var definition: Dictionary = BuildingCatalog.get_definition(
			selected_building_id
		)
		hud.show_build_preview(
			definition,
			status,
			player_level,
			coins
		)
		return

	var tapped_aircraft := _aircraft_at_world_position(
		world_position
	)
	if tapped_aircraft != null:
		_show_aircraft_context(tapped_aircraft)
		return

	if aircraft_context_card != null:
		aircraft_context_card.close_card()
	if building_context_card != null:
		building_context_card.close_card()
	airport_grid.select_world_position(world_position)


func _aircraft_at_world_position(
	world_position: Vector2
) -> AircraftPrototype:
	var closest: AircraftPrototype = null
	var closest_distance := INF

	for aircraft in aircraft_demos:
		if (
			aircraft == null
			or not is_instance_valid(aircraft)
			or not aircraft.contains_world_point(world_position)
		):
			continue

		var distance := aircraft.global_position.distance_to(
			world_position
		)
		if distance < closest_distance:
			closest = aircraft
			closest_distance = distance

	return closest


func _show_aircraft_context(
	aircraft: AircraftPrototype
) -> void:
	if (
		aircraft_context_card == null
		or passenger_economy == null
	):
		return

	if building_context_card != null:
		building_context_card.close_card()

	aircraft_context_card.show_aircraft(
		aircraft,
		current_profile.get(
			"aircraft_mastery_hours",
			{}
		),
		passenger_economy.get_passengers(),
		passenger_economy.get_capacity()
	)


func _on_aircraft_context_choose_route_requested(
	aircraft: AircraftPrototype
) -> void:
	var index := aircraft_demos.find(aircraft)
	if index < 0:
		return

	world_map.selected_aircraft_index = index
	_on_navigation_requested("world")


func _on_aircraft_context_fleet_requested(
	aircraft: AircraftPrototype
) -> void:
	var index := aircraft_demos.find(aircraft)
	if index < 0:
		return

	fleet_screen.selected_index = index
	_on_navigation_requested("fleet")


func _on_rewarded_passenger_boost_requested() -> void:
	rewarded_passenger_ad_bridge.request_ad()


func _on_rewarded_passenger_ad_unavailable() -> void:
	hud.set_operation_status(
		"Rewarded passenger boost is ready, but no ad provider is connected.",
		"warning"
	)


func _on_rewarded_passenger_ad_reward_granted() -> void:
	var added := PassengerSupportRules.grant_rewarded_ad_passengers(
		passenger_economy
	)
	if added <= 0:
		hud.set_operation_status(
			"Passenger storage is already full.",
			"warning"
		)
	else:
		hud.set_operation_status(
			"Rewarded ad complete • +%d passengers" % added,
			"success"
		)

	resource_inventory_screen.open_inventory(
		resource_inventory,
		passenger_economy.get_passengers(),
		passenger_economy.get_capacity(),
		passenger_economy.get_production_per_minute(),
		rewarded_passenger_ad_bridge.provider_connected,
		current_profile.get("economy_stats", {})
	)


func _on_passive_passengers_generated(amount: int) -> void:
	if amount <= 0:
		return

	var updated := ProfileStore.add_economy_stats({
		"passengers_generated": amount
	})
	if not updated.is_empty():
		current_profile = updated


func _on_passenger_economy_changed(
	passengers: int,
	capacity: int,
	per_minute: float
) -> void:
	hud.set_passenger_data(passengers, capacity, per_minute)
	if world_map != null:
		world_map.set_passenger_stock(passengers, capacity)
	if aircraft_context_card != null:
		aircraft_context_card.set_passenger_stock(
			passengers,
			capacity
		)
	var updated := ProfileStore.save_passenger_balance(passengers)
	if not updated.is_empty():
		current_profile = updated

	_refresh_waiting_passenger_cards()
	if not processing_passenger_queue:
		_try_board_waiting_aircraft()
	_refresh_operations_analytics()


func _mastery_hours_for_aircraft(
	aircraft: AircraftPrototype
) -> float:
	if aircraft == null:
		return 0.0
	var mastery: Dictionary = current_profile.get(
		"aircraft_mastery_hours",
		{}
	)
	return maxf(
		float(mastery.get(aircraft.aircraft_type_id, 0.0)),
		0.0
	)


func _passenger_requirement(aircraft: AircraftPrototype) -> int:
	var profile := aircraft.get_aircraft_profile()
	return PassengerDemandRules.required_from_plan(
		profile,
		aircraft.get_flight_plan(),
		_mastery_hours_for_aircraft(aircraft)
	)


func _attempt_boarding_and_departure(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	var required := _passenger_requirement(aircraft)
	if required <= 0:
		_remove_passenger_waiter(aircraft)
		ground_services.approve_passenger_loading(aircraft)
		return

	processing_passenger_queue = true
	var boarded := passenger_economy.spend_passengers(required)
	processing_passenger_queue = false

	if boarded:
		_remove_passenger_waiter(aircraft)
		aircraft.record_boarded_passengers(required)
		_record_boarded_passengers(required)
		ground_services.approve_passenger_loading(aircraft)
		hud.set_operation_status(
			"%s received %d passengers • boarding started" % [
				label,
				required
			],
			"success"
		)
		return

	aircraft.mark_waiting_passengers()
	if not _is_passenger_waiter(aircraft):
		pending_passenger_departures.append({
			"aircraft": aircraft,
			"label": label
		})

	aircraft.set_turnaround_status(
		"Passengers %d / %d\nWAITING" % [
			passenger_economy.get_passengers(),
			required
		],
		"warning"
	)
	hud.set_operation_status(
		"%s waiting for passengers • %d / %d available" % [
			label,
			passenger_economy.get_passengers(),
			required
		],
		"warning"
	)


func _try_board_waiting_aircraft() -> void:
	if processing_passenger_queue:
		return

	processing_passenger_queue = true
	var index := 0
	while index < pending_passenger_departures.size():
		var request: Dictionary = pending_passenger_departures[index]
		var aircraft := request.get("aircraft") as AircraftPrototype
		var label := String(request.get("label", "Aircraft"))

		if aircraft == null or not is_instance_valid(aircraft):
			pending_passenger_departures.remove_at(index)
			continue

		var required := _passenger_requirement(aircraft)
		if passenger_economy.get_passengers() < required:
			index += 1
			continue

		if not passenger_economy.spend_passengers(required):
			index += 1
			continue

		pending_passenger_departures.remove_at(index)
		aircraft.record_boarded_passengers(required)
		_record_boarded_passengers(required)
		ground_services.approve_passenger_loading(aircraft)
		hud.set_operation_status(
			"%s received %d passengers • boarding started" % [
				label,
				required
			],
			"success"
		)

	processing_passenger_queue = false


func _refresh_waiting_passenger_cards() -> void:
	for request in pending_passenger_departures:
		var aircraft := request.get("aircraft") as AircraftPrototype
		if aircraft == null or not is_instance_valid(aircraft):
			continue
		var required := _passenger_requirement(aircraft)
		aircraft.set_turnaround_status(
			"Passengers %d / %d\nWAITING" % [
				passenger_economy.get_passengers(),
				required
			],
			"warning"
		)


func _record_boarded_passengers(amount: int) -> void:
	if amount <= 0:
		return
	if event_manager != null:
		event_manager.record_metric("passengers_boarded", amount)
	var updated := ProfileStore.add_economy_stats({
		"passengers_boarded": amount
	})
	if not updated.is_empty():
		current_profile = updated


func _is_passenger_waiter(aircraft: AircraftPrototype) -> bool:
	for request in pending_passenger_departures:
		if request.get("aircraft") == aircraft:
			return true
	return false


func _remove_passenger_waiter(aircraft: AircraftPrototype) -> void:
	for index in range(pending_passenger_departures.size() - 1, -1, -1):
		if pending_passenger_departures[index].get("aircraft") == aircraft:
			pending_passenger_departures.remove_at(index)


func _on_building_selected_world(
	building: Dictionary
) -> void:
	if building.is_empty():
		return

	if aircraft_context_card != null:
		aircraft_context_card.close_card()
	_close_building_management_panels()

	if building_context_card != null:
		building_context_card.show_building(
			building,
			_building_context_summary(building)
		)


func _on_building_context_primary_action_requested(
	building: Dictionary
) -> void:
	if building_context_card != null:
		building_context_card.close_card()
	_open_building_management(building)


func _open_building_management(
	building: Dictionary
) -> void:
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	var building_id := String(
		building.get("definition_id", "")
	)
	if definition.is_empty():
		return

	_close_building_management_panels()

	if building_id.contains("runway"):
		var strategies: Dictionary = current_profile.get(
			"runway_strategies",
			{}
		)
		var building_key: String = airport_grid.get_building_key(
			building
		)
		var strategy := RunwayStrategyRules.normalize(
			String(
				strategies.get(
					building_key,
					RunwayStrategyRules.AUTO
				)
			)
		)
		var analytics_snapshot := (
			runway_dispatcher.get_runway_analytics_snapshot()
		)
		var recommendation: Dictionary = (
			analytics_snapshot.get(
				"recommendation",
				{}
			)
		)
		runway_strategy_panel.open_runway(
			building,
			strategy,
			airport_grid.get_runway_buildings().size(),
			runway_dispatcher.get_runway_analytics(
				int(building.get("uid", -1))
			),
			recommendation
		)
		return

	if AirTrafficUpgradeCatalog.is_upgradeable(
		building_id
	):
		air_traffic_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	if bool(
		definition.get(
			"passenger_generator",
			false
		)
	):
		passenger_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	if ServiceUpgradeCatalog.is_upgradeable(
		building_id
	):
		service_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return


func _close_building_management_panels() -> void:
	if passenger_upgrade_panel != null:
		passenger_upgrade_panel.close_panel()
	if runway_strategy_panel != null:
		runway_strategy_panel.close_panel()
	if service_upgrade_panel != null:
		service_upgrade_panel.close_panel()
	if air_traffic_upgrade_panel != null:
		air_traffic_upgrade_panel.close_panel()


func _building_context_summary(
	building: Dictionary
) -> Dictionary:
	var building_id := String(
		building.get("definition_id", "")
	)
	var definition := BuildingCatalog.get_definition(
		building_id
	)
	if definition.is_empty():
		return {}

	var level := int(building.get("upgrade_level", 1))
	var summary := {
		"role": String(
			definition.get("category", "Airport")
		),
		"status": "Operational",
		"tone": "success",
		"description": String(
			definition.get("description", "")
		),
		"stat_one": "LEVEL\n%d" % level,
		"stat_two": "FOOTPRINT\n%s" % (
			_context_footprint_text(definition, building)
		),
		"primary_label": "",
		"primary_kind": "primary",
		"show_details": false
	}

	if building_id.contains("runway"):
		return _runway_context_summary(
			building,
			definition,
			summary
		)

	if AirTrafficUpgradeCatalog.is_upgradeable(
		building_id
	):
		return _atc_context_summary(
			building,
			definition,
			summary
		)

	if bool(
		definition.get(
			"passenger_generator",
			false
		)
	):
		return _passenger_building_context_summary(
			building,
			definition,
			summary
		)

	if ServiceUpgradeCatalog.is_upgradeable(
		building_id
	):
		return _service_building_context_summary(
			building,
			definition,
			summary
		)

	var connected_uids: Array = airport_grid.get_airside_status().get(
		"connected_uids",
		[]
	)
	if (
		building_id.contains("stand")
		or building_id.contains("hangar")
	):
		var uid := int(building.get("uid", -1))
		var connected := connected_uids.has(uid)
		summary["status"] = (
			"Connected to taxiway network"
			if connected
			else "Needs taxiway connection"
		)
		summary["tone"] = "success" if connected else "warning"
		summary["stat_one"] = "AIRCRAFT\n%s" % (
			_context_size_text(definition)
		)

	return summary


func _passenger_building_context_summary(
	building: Dictionary,
	definition: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var result := summary.duplicate(true)
	var building_id := String(building.get("definition_id", ""))
	var level := int(building.get("upgrade_level", 1))
	var stats := PassengerUpgradeCatalog.passenger_stats(
		building_id,
		level
	)
	result["role"] = "Passenger generation"
	result["stat_one"] = "PRODUCTION\n+%.1f/min" % float(
		stats.get("passengers_per_minute", 0.0)
	)
	result["stat_two"] = "STORAGE\n%d" % int(
		stats.get("storage", 0)
	)
	if not PassengerUpgradeCatalog.get_next_level(
		building_id,
		level
	).is_empty():
		result["primary_label"] = "UPGRADE"
		result["primary_kind"] = "primary"
	else:
		result["status"] = "Maximum upgrade level"
		result["tone"] = "success"
	return result


func _service_building_context_summary(
	building: Dictionary,
	definition: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var result := summary.duplicate(true)
	var building_id := String(building.get("definition_id", ""))
	var level := int(building.get("upgrade_level", 1))
	var service_types := ServiceUpgradeCatalog.service_types(
		building_id
	)
	var max_speed := 0.0
	var max_capacity := 0
	for service_type in service_types:
		var stats := ServiceUpgradeCatalog.effective_service_stats(
			building_id,
			service_type,
			level
		)
		max_speed = maxf(
			max_speed,
			float(stats.get("service_speed", 0.0))
		)
		max_capacity = maxi(
			max_capacity,
			int(stats.get("vehicle_capacity", 0))
		)

	var waiting_by_service := ground_services.get_waiting_by_service()
	var waiting := 0
	for service_type in service_types:
		waiting += int(
			waiting_by_service.get(
				service_type,
				0
			)
		)

	result["role"] = "Ground service"
	result["stat_one"] = "SERVICE SPEED\nx%.2f" % max_speed
	result["stat_two"] = "VEHICLES\n%d" % max_capacity
	if waiting > 0:
		result["status"] = "%d service request%s waiting" % [
			waiting,
			"" if waiting == 1 else "s"
		]
		result["tone"] = "warning"
	else:
		result["status"] = "No queue • service available"
		result["tone"] = "success"

	if not ServiceUpgradeCatalog.get_next_level(
		building_id,
		level
	).is_empty():
		result["primary_label"] = "UPGRADE"
		result["primary_kind"] = "primary"
	return result


func _atc_context_summary(
	building: Dictionary,
	definition: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var result := summary.duplicate(true)
	var building_id := String(building.get("definition_id", ""))
	var level := int(building.get("upgrade_level", 1))
	var preview := AirTrafficUpgradeCatalog.separation_preview(
		building_id,
		level
	)
	var multiplier := float(
		preview.get("multiplier", 1.0)
	)
	result["role"] = "Air traffic control"
	result["stat_one"] = "SEPARATION\nx%.2f" % multiplier
	result["stat_two"] = "DEP→DEP\n%.1fs" % float(
		preview.get("departure_departure", 0.0)
	)
	result["status"] = "Runway sequencing optimized"
	result["tone"] = "success"
	if not AirTrafficUpgradeCatalog.get_next_level(
		building_id,
		level
	).is_empty():
		result["primary_label"] = "UPGRADE ATC"
		result["primary_kind"] = "gold"
	else:
		result["status"] = "Maximum ATC level"
	return result


func _runway_context_summary(
	building: Dictionary,
	definition: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var result := summary.duplicate(true)
	var runway_uid := int(building.get("uid", -1))
	var strategy := runway_dispatcher.get_runway_strategy(
		runway_uid
	)
	var analytics := runway_dispatcher.get_runway_analytics(
		runway_uid
	)
	var utilization := float(
		analytics.get("utilization_pct", 0.0)
	)
	var wait_seconds := float(
		analytics.get("average_wait_seconds", 0.0)
	)

	result["role"] = "Runway"
	result["stat_one"] = "STRATEGY\n%s" % (
		RunwayStrategyRules.short_label(strategy)
	)
	result["stat_two"] = "UTIL / WAIT\n%.0f%% • %.1fs" % [
		utilization,
		wait_seconds
	]
	result["primary_label"] = "RUNWAY STRATEGY"
	result["primary_kind"] = "gold"

	var analytics_snapshot := (
		runway_dispatcher.get_runway_analytics_snapshot()
	)
	var recommendation: Dictionary = analytics_snapshot.get(
		"recommendation",
		{}
	)
	if not recommendation.is_empty():
		result["status"] = String(
			recommendation.get(
				"title",
				"Runway operational"
			)
		)
		result["tone"] = String(
			recommendation.get(
				"tone",
				"normal"
			)
		)
	else:
		result["status"] = "Runway operational"
		result["tone"] = "success"
	return result


func _context_size_text(
	definition: Dictionary
) -> String:
	var sizes: PackedStringArray = definition.get(
		"sizes",
		PackedStringArray()
	)
	if sizes.is_empty():
		return "—"
	return "/".join(sizes)


func _context_footprint_text(
	definition: Dictionary,
	building: Dictionary
) -> String:
	var footprint: Vector2i = definition.get(
		"footprint",
		Vector2i.ONE
	)
	if int(building.get("rotation", 0)) % 2 == 1:
		footprint = Vector2i(
			footprint.y,
			footprint.x
		)
	return "%dx%d" % [
		footprint.x,
		footprint.y
	]


func _on_passenger_upgrade_requested(building_uid: int) -> void:
	var building: Dictionary = airport_grid.get_building(building_uid)
	if building.is_empty():
		return

	var building_id := String(building.get("definition_id", ""))
	var current_level := int(building.get("upgrade_level", 1))
	var next := PassengerUpgradeCatalog.get_next_level(
		building_id,
		current_level
	)
	if next.is_empty():
		return

	var coin_cost := int(next.get("coin_cost", 0))
	if coins < coin_cost:
		passenger_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	var resource_cost: Dictionary = next.get(
		"resource_cost",
		{}
	).duplicate(true)
	var building_key: String = airport_grid.get_building_key(building)
	var updated_profile: Dictionary = ProfileStore.apply_building_upgrade(
		building_key,
		int(next.get("level", current_level + 1)),
		resource_cost
	)
	if updated_profile.is_empty():
		passenger_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	coins -= coin_cost
	current_profile = updated_profile
	resource_inventory = current_profile.get(
		"resource_inventory",
		{}
	).duplicate(true)

	airport_grid.set_building_upgrade_level(
		building_uid,
		int(next.get("level", current_level + 1))
	)
	passenger_economy.refresh_building_stats()
	hud.set_player_data(player_level, coins, gems)

	var refreshed: Dictionary = airport_grid.get_building(building_uid)
	passenger_upgrade_panel.open_building(
		refreshed,
		resource_inventory,
		coins
	)
	hud.set_operation_status(
		"%s upgraded to Lv %d" % [
			String(
				BuildingCatalog.get_definition(building_id).get(
					"name",
					"Passenger building"
				)
			),
			int(next.get("level", current_level + 1))
		],
		"success"
	)


func _on_service_upgrade_requested(
	building_uid: int
) -> void:
	var building: Dictionary = airport_grid.get_building(building_uid)
	if building.is_empty():
		return

	var building_id := String(
		building.get("definition_id", "")
	)
	var current_level := int(
		building.get("upgrade_level", 1)
	)
	var next := ServiceUpgradeCatalog.get_next_level(
		building_id,
		current_level
	)
	if next.is_empty():
		return

	var coin_cost := int(next.get("coin_cost", 0))
	if coins < coin_cost:
		service_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	var resource_cost: Dictionary = next.get(
		"resource_cost",
		{}
	).duplicate(true)
	var building_key: String = airport_grid.get_building_key(
		building
	)
	var updated_profile := ProfileStore.apply_building_upgrade(
		building_key,
		int(next.get("level", current_level + 1)),
		resource_cost
	)
	if updated_profile.is_empty():
		service_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	coins -= coin_cost
	current_profile = updated_profile
	resource_inventory = current_profile.get(
		"resource_inventory",
		{}
	).duplicate(true)

	airport_grid.set_building_upgrade_level(
		building_uid,
		int(next.get("level", current_level + 1))
	)
	hud.set_player_data(player_level, coins, gems)

	var refreshed: Dictionary = airport_grid.get_building(building_uid)
	service_upgrade_panel.open_building(
		refreshed,
		resource_inventory,
		coins
	)
	hud.set_operation_status(
		"%s upgraded to Lv %d" % [
			String(
				BuildingCatalog.get_definition(
					building_id
				).get("name", "Service building")
			),
			int(next.get("level", current_level + 1))
		],
		"success"
	)


func _on_runway_strategy_requested(
	runway_uid: int,
	strategy: String
) -> void:
	var runway: Dictionary = airport_grid.get_building(
		runway_uid
	)
	if runway.is_empty():
		return

	var building_key: String = airport_grid.get_building_key(
		runway
	)
	var updated_profile := ProfileStore.set_runway_strategy(
		building_key,
		strategy
	)
	if updated_profile.is_empty():
		return

	current_profile = updated_profile
	var strategies: Dictionary = current_profile.get(
		"runway_strategies",
		{}
	)
	runway_dispatcher.set_runway_strategies(
		strategies
	)

	var analytics_snapshot := (
		runway_dispatcher.get_runway_analytics_snapshot()
	)
	runway_strategy_panel.open_runway(
		runway,
		runway_dispatcher.get_runway_strategy(
			runway_uid
		),
		airport_grid.get_runway_buildings().size(),
		runway_dispatcher.get_runway_analytics(
			runway_uid
		),
		analytics_snapshot.get(
			"recommendation",
			{}
		)
	)
	hud.set_operation_status(
		"Runway %d strategy • %s" % [
			runway_uid,
			RunwayStrategyRules.display_name(
				strategy
			)
		],
		"success"
	)


func _on_air_traffic_upgrade_requested(
	building_uid: int
) -> void:
	var building: Dictionary = airport_grid.get_building(
		building_uid
	)
	if building.is_empty():
		return

	var building_id := String(
		building.get("definition_id", "")
	)
	var current_level := int(
		building.get("upgrade_level", 1)
	)
	var next := AirTrafficUpgradeCatalog.get_next_level(
		building_id,
		current_level
	)
	if next.is_empty():
		return

	var coin_cost := int(
		next.get("coin_cost", 0)
	)
	if coins < coin_cost:
		air_traffic_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	var resource_cost: Dictionary = next.get(
		"resource_cost",
		{}
	).duplicate(true)
	var building_key: String = airport_grid.get_building_key(
		building
	)
	var updated_profile: Dictionary = (
		ProfileStore.apply_building_upgrade(
			building_key,
			int(
				next.get(
					"level",
					current_level + 1
				)
			),
			resource_cost
		)
	)
	if updated_profile.is_empty():
		air_traffic_upgrade_panel.open_building(
			building,
			resource_inventory,
			coins
		)
		return

	coins -= coin_cost
	current_profile = updated_profile
	resource_inventory = current_profile.get(
		"resource_inventory",
		{}
	).duplicate(true)

	airport_grid.set_building_upgrade_level(
		building_uid,
		int(
			next.get(
				"level",
				current_level + 1
			)
		)
	)
	runway_dispatcher.refresh_air_traffic_control()
	hud.set_player_data(player_level, coins, gems)

	var refreshed: Dictionary = airport_grid.get_building(
		building_uid
	)
	air_traffic_upgrade_panel.open_building(
		refreshed,
		resource_inventory,
		coins
	)
	hud.set_operation_status(
		"ATC upgraded to Lv %d • runway separation reduced" % int(
			next.get(
				"level",
				current_level + 1
			)
		),
		"success"
	)


func _on_network_status_changed(status: Dictionary) -> void:
	hud.set_airside_status(status)


func _on_parcel_selected(_parcel_id: String, parcel_data: Dictionary) -> void:
	if selected_building_id.is_empty():
		hud.show_parcel(parcel_data, player_level, coins)


func _on_purchase_expansion_requested() -> void:
	var parcel_data: Dictionary = airport_grid.get_selected_parcel()
	if parcel_data.is_empty() or parcel_data.get("owned", false):
		return

	var required_level: int = int(parcel_data.get("level", 1))
	var cost: int = int(parcel_data.get("cost", 0))
	if player_level < required_level or coins < cost:
		hud.show_parcel(parcel_data, player_level, coins)
		return

	coins -= cost
	airport_grid.purchase_selected()
	hud.set_player_data(player_level, coins, gems)
	hud.show_parcel(airport_grid.get_selected_parcel(), player_level, coins)


func _on_building_selected(building_id: String) -> void:
	if aircraft_context_card != null:
		aircraft_context_card.close_card()
	if building_context_card != null:
		building_context_card.close_card()

	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return

	selected_building_id = building_id
	selected_building_rotation = 0
	airport_grid.clear_parcel_selection()
	airport_grid.clear_build_preview()
	hud.enter_building_mode(definition)
	hud.show_build_preview(definition, {}, player_level, coins)


func _on_rotate_building_requested() -> void:
	if selected_building_id.is_empty():
		return

	var definition := BuildingCatalog.get_definition(selected_building_id)
	if definition.is_empty() or not bool(definition.get("rotatable", false)):
		return

	selected_building_rotation = (selected_building_rotation + 1) % 2
	var status: Dictionary = {}
	if airport_grid.has_build_preview():
		status = airport_grid.refresh_build_preview(selected_building_rotation)
	hud.show_build_preview(definition, status, player_level, coins)


func _on_confirm_building_requested() -> void:
	if selected_building_id.is_empty():
		return

	var definition := BuildingCatalog.get_definition(selected_building_id)
	if definition.is_empty():
		return

	var required_level := int(definition["level"])
	var cost := int(definition["cost"])
	var status: Dictionary = airport_grid.get_build_preview_status()

	if player_level < required_level or coins < cost:
		hud.show_build_preview(definition, status, player_level, coins)
		return

	if not bool(status.get("valid", false)):
		hud.show_build_preview(definition, status, player_level, coins)
		return

	var placed: Dictionary = airport_grid.confirm_build_preview()
	if placed.is_empty():
		return

	coins -= cost
	if event_manager != null:
		event_manager.record_metric("buildings_placed", 1)
	if (
		bool(
			definition.get(
				"air_traffic_control",
				false
			)
		)
		or String(
			definition.get("id", "")
		).contains("runway")
	):
		runway_dispatcher.refresh_air_traffic_control()
		runway_dispatcher.set_runway_strategies(
			current_profile.get(
				"runway_strategies",
				{}
			)
		)
	hud.set_player_data(player_level, coins, gems)
	hud.show_build_preview(definition, {}, player_level, coins)


func _on_cancel_building_requested() -> void:
	selected_building_id = ""
	selected_building_rotation = 0
	airport_grid.clear_build_preview()
	hud.exit_building_mode()
