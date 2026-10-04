extends Node2D

@onready var airport_grid = $AirportGrid
@onready var camera_controller = $Camera
@onready var hud = $HUD

var player_level: int = 4
var coins: int = 18420
var gems: int = 120

var selected_building_id := ""
var selected_building_rotation := 0
var aircraft_demos: Array[AircraftPrototype] = []
var ground_services: GroundServiceDispatcher
var runway_dispatcher: RunwayDispatcher
var stand_occupancy: Dictionary = {}
var pending_arrivals: Array[Dictionary] = []
var world_map: WorldMapScreen


func _ready() -> void:
	camera_controller.world_tapped.connect(_on_world_tapped)
	airport_grid.parcel_selected.connect(_on_parcel_selected)
	airport_grid.network_status_changed.connect(_on_network_status_changed)

	hud.purchase_expansion_requested.connect(_on_purchase_expansion_requested)
	hud.building_selected.connect(_on_building_selected)
	hud.rotate_building_requested.connect(_on_rotate_building_requested)
	hud.confirm_building_requested.connect(_on_confirm_building_requested)
	hud.cancel_building_requested.connect(_on_cancel_building_requested)
	hud.navigation_requested.connect(_on_navigation_requested)

	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(player_level, coins, gems)
	hud.set_airside_status(airport_grid.get_airside_status())
	airport_grid.select_parcel("north")

	_setup_ground_services()
	_setup_runway_dispatcher()
	_setup_world_map()
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

		var profile_ids := ["aerolet_100", "aerolet_120"]
		var default_destinations := ["london", "paris"]
		var profile_id := profile_ids[index % profile_ids.size()]
		var destination_id := default_destinations[
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
		ground_services.request_fuel(aircraft, label)

	hud.set_operation_status(
		"%d aircraft awaiting turnaround" % aircraft_demos.size()
	)


func _on_aircraft_serviced(aircraft: AircraftPrototype, label: String) -> void:
	runway_dispatcher.request_departure(aircraft, label)


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
		"READY_FOR_DESTINATION":
			hud.set_operation_status(
				"%s fueled • choose destination" % label,
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
	ground_services.request_fuel(aircraft, label)


func _on_navigation_requested(tab: String) -> void:
	match tab:
		"world":
			world_map.open_map(aircraft_demos, player_level)
		"fleet":
			hud.set_operation_status("Fleet screen comes in a later pass.")
		"alliance":
			hud.set_operation_status("Alliance unlocks later.")
		"more":
			hud.set_operation_status("More/settings screen comes later.")


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

	if previous_state == "READY_FOR_DESTINATION":
		aircraft.mark_service_complete()
		runway_dispatcher.request_departure(aircraft, aircraft.name)


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
