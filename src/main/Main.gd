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
var stand_occupancy: Dictionary = {}
var pending_arrivals: Array[Dictionary] = []
var pending_passenger_departures: Array[Dictionary] = []
var processing_passenger_queue := false
var world_map: WorldMapScreen
var return_summary: FlightReturnSummary
var resource_inventory_screen: ResourceInventoryScreen
var passenger_upgrade_panel: PassengerUpgradePanel
var passenger_economy: PassengerEconomy
var current_profile: Dictionary = {}
var gameplay_started := false


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
	_setup_world_map()
	_setup_return_summary()
	_setup_passenger_system()
	_setup_resource_inventory()
	_setup_passenger_upgrade_panel()
	reward_rng.randomize()
	_spawn_aircraft_demos()


func _setup_ground_services() -> void:
	ground_services = GroundServiceDispatcher.new()
	ground_services.z_index = 85
	ground_services.configure(airport_grid)
	ground_services.status_changed.connect(_on_ground_service_status)
	ground_services.queue_changed.connect(_on_ground_service_queue_changed)
	add_child(ground_services)


func _setup_runway_dispatcher() -> void:
	runway_dispatcher = RunwayDispatcher.new()
	runway_dispatcher.status_changed.connect(_on_runway_status)
	runway_dispatcher.queue_changed.connect(_on_runway_queue_changed)
	add_child(runway_dispatcher)
	ground_services.aircraft_serviced.connect(_on_aircraft_serviced)


func _setup_world_map() -> void:
	world_map = WorldMapScreen.new()
	world_map.flight_assignment_requested.connect(
		_on_world_map_flight_assignment_requested
	)
	add_child(world_map)


func _setup_return_summary() -> void:
	return_summary = FlightReturnSummary.new()
	add_child(return_summary)


func _setup_passenger_system() -> void:
	var saved_upgrades: Dictionary = current_profile.get(
		"building_upgrades",
		{}
	).duplicate(true)
	airport_grid.apply_saved_building_upgrades(saved_upgrades)

	passenger_economy = PassengerEconomy.new()
	passenger_economy.changed.connect(_on_passenger_economy_changed)
	add_child(passenger_economy)
	passenger_economy.configure(
		airport_grid,
		float(current_profile.get("passenger_balance", 20))
	)


func _setup_resource_inventory() -> void:
	resource_inventory_screen = ResourceInventoryScreen.new()
	add_child(resource_inventory_screen)


func _setup_passenger_upgrade_panel() -> void:
	passenger_upgrade_panel = PassengerUpgradePanel.new()
	passenger_upgrade_panel.upgrade_requested.connect(
		_on_passenger_upgrade_requested
	)
	add_child(passenger_upgrade_panel)


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

		var destination := DestinationCatalog.get_destination(destination_id)
		var initial_plan := FlightRules.create_flight_plan(
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
		ground_services.request_turnaround(aircraft, label, false)

	hud.set_operation_status(
		"%d aircraft awaiting turnaround" % aircraft_demos.size()
	)


func _on_aircraft_serviced(aircraft: AircraftPrototype, label: String) -> void:
	_attempt_boarding_and_departure(aircraft, label)


func _on_runway_status(text: String, tone: String) -> void:
	hud.set_operation_status(text, tone)


func _on_runway_queue_changed(waiting: int, active: int) -> void:
	if waiting > 0:
		hud.set_operation_status(
			"Departure queue: %d waiting • %d runway active" % [waiting, active],
			"warning"
		)


func _on_ground_service_status(text: String, tone: String) -> void:
	hud.set_operation_status(text, tone)


func _on_ground_service_queue_changed(waiting: int, active: int) -> void:
	if waiting > 0:
		hud.set_operation_status(
			"Fuel queue: %d waiting • %d truck active" % [waiting, active],
			"warning"
		)


func _on_demo_aircraft_state_changed(
	state: String,
	aircraft: AircraftPrototype,
	label: String
) -> void:
	match state:
		"TAXIING_OUT":
			_release_stand(aircraft)
			hud.set_operation_status("%s taxiing to runway" % label)
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
				"%s completing pushback checks" % label
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
		"CLEARED":
			hud.set_operation_status("%s cleared for departure" % label, "success")
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
			"label": label
		})
		hud.set_operation_status(
			"%s holding • no free compatible stand" % label,
			"warning"
		)


func _assign_arrival_if_possible(
	aircraft: AircraftPrototype,
	label: String
) -> bool:
	var arrivals: Array[Dictionary] = airport_grid.get_arrival_routes(
		aircraft.aircraft_size
	)

	for route_info in arrivals:
		var stand_uid := int(route_info.get("stand_uid", -1))
		if stand_uid < 0 or stand_occupancy.has(stand_uid):
			continue

		var route: PackedVector2Array = route_info.get(
			"route",
			PackedVector2Array()
		)
		if route.size() < 4:
			continue

		var runway_uid := int(route_info.get("runway_uid", -1))
		stand_occupancy[stand_uid] = aircraft
		aircraft.set_arrival_route(route, stand_uid, runway_uid)
		runway_dispatcher.request_arrival(aircraft, label)
		return true

	return false


func _release_stand(aircraft: AircraftPrototype) -> void:
	var stand_uid := aircraft.stand_uid
	if stand_uid < 0:
		return

	if stand_occupancy.get(stand_uid) == aircraft:
		stand_occupancy.erase(stand_uid)
	_try_assign_pending_arrivals()


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


func _on_navigation_requested(tab: String) -> void:
	match tab:
		"world":
			world_map.open_map(
				aircraft_demos,
				player_level,
				current_profile.get(
					"aircraft_mastery_hours",
					{}
				)
			)
		"fleet":
			hud.set_operation_status("Fleet screen comes in a later pass.")
		"alliance":
			hud.set_operation_status("Alliance unlocks later.")
		"more":
			resource_inventory_screen.open_inventory(
				resource_inventory,
				passenger_economy.get_passengers(),
				passenger_economy.get_capacity(),
				passenger_economy.get_production_per_minute()
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
	var plan := FlightRules.create_flight_plan(profile, destination)
	aircraft.assign_flight_plan(plan)

	world_map.set_assignment_status(
		"%s assigned to %s • %s" % [
			aircraft.name,
			String(destination.get("city", "")),
			FlightRules.format_duration(
				float(plan.get("duration_seconds", 0.0))
			)
		]
	)

	if previous_state in ["READY_FOR_DESTINATION", "WAITING_PASSENGERS"]:
		aircraft.mark_service_complete()
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
		var definition: Dictionary = BuildingCatalog.get_definition(selected_building_id)
		hud.show_build_preview(definition, status, player_level, coins)
		return

	airport_grid.select_world_position(world_position)


func _on_passenger_economy_changed(
	passengers: int,
	capacity: int,
	per_minute: float
) -> void:
	hud.set_passenger_data(passengers, capacity, per_minute)
	var updated := ProfileStore.save_passenger_balance(passengers)
	if not updated.is_empty():
		current_profile = updated

	if not processing_passenger_queue:
		_try_board_waiting_aircraft()


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
	var base_passengers := maxi(int(profile.get("passengers", 0)), 0)
	return AircraftMastery.passenger_requirement(
		base_passengers,
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
		runway_dispatcher.request_departure(aircraft, label)
		return

	processing_passenger_queue = true
	var boarded := passenger_economy.spend_passengers(required)
	processing_passenger_queue = false

	if boarded:
		_remove_passenger_waiter(aircraft)
		if aircraft.state == "WAITING_PASSENGERS":
			aircraft.mark_service_complete()
		hud.set_operation_status(
			"%s boarded %d passengers • awaiting runway" % [
				label,
				required
			],
			"success"
		)
		runway_dispatcher.request_departure(aircraft, label)
		return

	aircraft.mark_waiting_passengers()
	if not _is_passenger_waiter(aircraft):
		pending_passenger_departures.append({
			"aircraft": aircraft,
			"label": label
		})

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
		aircraft.mark_service_complete()
		runway_dispatcher.request_departure(aircraft, label)
		hud.set_operation_status(
			"%s boarded %d passengers • released for departure" % [
				label,
				required
			],
			"success"
		)

	processing_passenger_queue = false


func _is_passenger_waiter(aircraft: AircraftPrototype) -> bool:
	for request in pending_passenger_departures:
		if request.get("aircraft") == aircraft:
			return true
	return false


func _remove_passenger_waiter(aircraft: AircraftPrototype) -> void:
	for index in range(pending_passenger_departures.size() - 1, -1, -1):
		if pending_passenger_departures[index].get("aircraft") == aircraft:
			pending_passenger_departures.remove_at(index)


func _on_building_selected_world(building: Dictionary) -> void:
	var definition := BuildingCatalog.get_definition(
		String(building.get("definition_id", ""))
	)
	if not bool(definition.get("passenger_generator", false)):
		hud.set_operation_status(
			String(definition.get("name", "Airport building"))
		)
		return

	passenger_upgrade_panel.open_building(
		building,
		resource_inventory,
		coins
	)


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
	var updated_profile := ProfileStore.apply_building_upgrade(
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
	hud.set_player_data(player_level, coins, gems)
	hud.show_build_preview(definition, {}, player_level, coins)


func _on_cancel_building_requested() -> void:
	selected_building_id = ""
	selected_building_rotation = 0
	airport_grid.clear_build_preview()
	hud.exit_building_mode()
