extends Node2D

@onready var airport_grid = $AirportGrid
@onready var camera_controller = $Camera
@onready var hud = $HUD

var player_level: int = 4
var airport_xp: int = 0
var coins: int = 18420
var gems: int = 120

var selected_building_id := ""
var selected_building_rotation := 0
var aircraft_demos: Array[AircraftPrototype] = []
var ground_services: GroundServiceDispatcher
var runway_dispatcher: RunwayDispatcher
var stand_occupancy: Dictionary = {}
var pending_arrivals: Array[Dictionary] = []


func _ready() -> void:
	camera_controller.world_tapped.connect(_on_world_tapped)
	airport_grid.parcel_selected.connect(_on_parcel_selected)
	airport_grid.network_status_changed.connect(_on_network_status_changed)

	hud.purchase_expansion_requested.connect(_on_purchase_expansion_requested)
	hud.building_selected.connect(_on_building_selected)
	hud.rotate_building_requested.connect(_on_rotate_building_requested)
	hud.confirm_building_requested.connect(_on_confirm_building_requested)
	hud.cancel_building_requested.connect(_on_cancel_building_requested)

	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_player_data(
		player_level,
		coins,
		gems,
		airport_xp,
		LevelProgression.xp_to_next(player_level)
	)
	hud.set_airside_status(airport_grid.get_airside_status())
	hud.set_flight_status("Assigning starter routes...")
	airport_grid.select_parcel("north")

	_setup_ground_services()
	_setup_runway_dispatcher()
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


func _spawn_aircraft_demos() -> void:
	var routes: Array[Dictionary] = airport_grid.get_departure_routes("S")
	if routes.is_empty():
		hud.set_operation_status("No connected S-class stand/runway.", "warning")
		return

	var starter_aircraft_ids := PackedStringArray(["pico_p8", "swift_s14"])
	var count := mini(mini(routes.size(), 2), starter_aircraft_ids.size())
	for index in range(count):
		var route_info: Dictionary = routes[index]
		var route: PackedVector2Array = route_info.get("route", PackedVector2Array())
		if route.size() < 2:
			continue

		var definition := AircraftCatalog.get_definition(starter_aircraft_ids[index])
		if definition.is_empty():
			continue

		var label := "SO-%03d" % (index + 1)
		var aircraft := AircraftPrototype.new()
		aircraft.name = label
		aircraft.z_index = 80 + index
		aircraft.configure_aircraft(definition)
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
			aircraft.aircraft_size,
			stand_uid,
			runway_uid
		)
		_assign_best_flight(aircraft, label)
		stand_occupancy[stand_uid] = aircraft
		aircraft_demos.append(aircraft)
		ground_services.request_fuel(aircraft, label)

	hud.set_operation_status(
		"%d aircraft awaiting turnaround" % aircraft_demos.size()
	)


func _assign_best_flight(aircraft: AircraftPrototype, label: String) -> bool:
	if aircraft == null or aircraft.aircraft_definition.is_empty():
		return false

	var manifest := FlightEconomy.best_manifest_for_aircraft(
		aircraft.aircraft_definition,
		player_level
	)
	if manifest.is_empty():
		hud.set_flight_status(
			"%s has no compatible route at airport Lv %d." % [label, player_level],
			"warning"
		)
		return false

	aircraft.assign_flight(manifest)
	hud.set_flight_status(
		"%s planned: %s → %s • %d/%d pax • ~%d min" % [
			label,
			String(manifest.get("route_name", "Route")),
			String(manifest.get("destination_name", "Destination")),
			int(manifest.get("passengers", 0)),
			int(manifest.get("capacity", 0)),
			int(manifest.get("duration_minutes", 0))
		]
	)
	return true


func _settle_completed_flight(
	aircraft: AircraftPrototype,
	label: String
) -> void:
	var manifest := aircraft.get_flight_manifest()
	if manifest.is_empty():
		return

	var profit := int(manifest.get("net_profit", 0))
	var xp_reward := int(manifest.get("xp_reward", 0))
	coins += profit

	var progression := LevelProgression.add_xp(
		player_level,
		airport_xp,
		xp_reward
	)
	var previous_level := player_level
	player_level = int(progression.get("level", player_level))
	airport_xp = int(progression.get("xp", airport_xp))

	hud.set_player_data(
		player_level,
		coins,
		gems,
		airport_xp,
		int(progression.get("xp_to_next", 0))
	)
	hud.set_flight_status(
		"%s returned from %s • +🪙 %d net • +%d XP" % [
			label,
			String(manifest.get("destination_name", "route")),
			profit,
			xp_reward
		],
		"success"
	)

	if player_level > previous_level:
		hud.set_operation_status(
			"Airport level %d reached • new unlocks available" % player_level,
			"success"
		)

	aircraft.clear_flight_manifest()


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
			var manifest := aircraft.get_flight_manifest()
			hud.set_operation_status("%s en route" % label, "success")
			if not manifest.is_empty():
				hud.set_flight_status(
					"%s → %s • %d/%d pax • ~%d min • est. 🪙 %d net" % [
						label,
						String(manifest.get("destination_name", "Destination")),
						int(manifest.get("passengers", 0)),
						int(manifest.get("capacity", 0)),
						int(manifest.get("duration_minutes", 0)),
						int(manifest.get("net_profit", 0))
					]
				)
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
	hud.set_operation_status("%s departed airport" % label, "success")
	var manifest := aircraft.get_flight_manifest()
	if not manifest.is_empty():
		hud.set_flight_status(
			"%s departed for %s • %d km • ~%d min" % [
				label,
				String(manifest.get("destination_name", "Destination")),
				int(manifest.get("distance_km", 0)),
				int(manifest.get("duration_minutes", 0))
			]
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
	_settle_completed_flight(aircraft, label)

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
	_assign_best_flight(aircraft, label)
	ground_services.request_fuel(aircraft, label)


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
