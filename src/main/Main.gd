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
var fleet_records: Array[Dictionary] = []
var next_fleet_uid := 1
var selected_fleet_uid := -1
var resource_inventory: Dictionary = {}

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
	hud.fleet_aircraft_selected.connect(_on_fleet_aircraft_selected)
	hud.fleet_aircraft_purchase_requested.connect(_on_fleet_aircraft_purchase_requested)
	hud.fleet_route_requested.connect(_on_fleet_route_requested)
	hud.world_aircraft_selected.connect(_on_fleet_aircraft_selected)
	hud.world_route_requested.connect(_on_fleet_route_requested)

	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	_refresh_player_hud()
	hud.set_airside_status(airport_grid.get_airside_status())
	hud.set_flight_status("Open FLEET to assign the first routes.")
	airport_grid.select_parcel("north")

	_setup_ground_services()
	_setup_runway_dispatcher()
	_spawn_starter_fleet()
	_refresh_fleet_panel()


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


func _spawn_starter_fleet() -> void:
	var routes: Array[Dictionary] = airport_grid.get_departure_routes("S")
	if routes.size() < 2:
		hud.set_operation_status(
			"Starter airport needs two connected S-class stands.",
			"warning"
		)
		return

	for index in range(2):
		var definition := AircraftCatalog.get_definition("pico_p8")
		var fleet_uid := _add_fleet_record(definition)
		var route_info: Dictionary = routes[index]
		_deploy_fleet_record(fleet_uid, route_info)

	if not fleet_records.is_empty():
		selected_fleet_uid = int(fleet_records[0].get("fleet_uid", -1))

	hud.set_operation_status(
		"2 starter Pico P8 aircraft parked • choose destinations in FLEET",
		"warning"
	)


func _add_fleet_record(definition: Dictionary) -> int:
	var fleet_uid := next_fleet_uid
	next_fleet_uid += 1
	fleet_records.append({
		"fleet_uid": fleet_uid,
		"aircraft_id": String(definition.get("id", "")),
		"label": "SO-%03d" % fleet_uid,
		"aircraft": null
	})
	return fleet_uid


func _deploy_fleet_record(fleet_uid: int, route_info: Dictionary) -> AircraftPrototype:
	var index := _fleet_record_index(fleet_uid)
	if index < 0:
		return null

	var record: Dictionary = fleet_records[index]
	var existing := record.get("aircraft") as AircraftPrototype
	if existing != null and is_instance_valid(existing):
		return existing

	var definition := AircraftCatalog.get_definition(
		String(record.get("aircraft_id", ""))
	)
	if definition.is_empty():
		return null

	var route: PackedVector2Array = route_info.get("route", PackedVector2Array())
	if route.size() < 2:
		return null

	var label := String(record.get("label", "Aircraft"))
	var aircraft := AircraftPrototype.new()
	aircraft.name = label
	aircraft.z_index = 80 + fleet_uid
	aircraft.configure_aircraft(definition)
	aircraft.state_changed.connect(
		_on_demo_aircraft_state_changed.bind(aircraft, label)
	)
	aircraft.departed.connect(
		_on_demo_aircraft_departed.bind(aircraft, label)
	)
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
	stand_occupancy[stand_uid] = aircraft
	aircraft_demos.append(aircraft)

	record["aircraft"] = aircraft
	fleet_records[index] = record
	return aircraft


func _fleet_record_index(fleet_uid: int) -> int:
	for index in range(fleet_records.size()):
		if int(fleet_records[index].get("fleet_uid", -1)) == fleet_uid:
			return index
	return -1


func _fleet_uid_for_aircraft(aircraft: AircraftPrototype) -> int:
	for record in fleet_records:
		if record.get("aircraft") == aircraft:
			return int(record.get("fleet_uid", -1))
	return -1


func _owned_aircraft_definitions() -> Array[Dictionary]:
	var owned: Array[Dictionary] = []
	for record in fleet_records:
		var definition := AircraftCatalog.get_definition(
			String(record.get("aircraft_id", ""))
		)
		if not definition.is_empty():
			owned.append(definition)
	return owned


func _find_free_departure_route(aircraft_size: String) -> Dictionary:
	var routes: Array[Dictionary] = airport_grid.get_departure_routes(
		aircraft_size
	)
	for route_info in routes:
		var stand_uid := int(route_info.get("stand_uid", -1))
		if stand_uid < 0 or stand_occupancy.has(stand_uid):
			continue
		if not _stand_has_compatible_fuel_route(stand_uid, aircraft_size):
			continue
		return route_info.duplicate(true)
	return {}


func _stand_has_compatible_fuel_route(
	stand_uid: int,
	aircraft_size: String
) -> bool:
	var stations := airport_grid.get_compatible_service_buildings(
		"fuel",
		aircraft_size
	)
	for station in stations:
		var route := airport_grid.get_service_route(
			int(station.get("uid", -1)),
			stand_uid
		)
		if route.size() >= 2:
			return true
	return false


func _purchase_status(definition: Dictionary) -> Dictionary:
	var required_level := int(definition.get("unlock_level", 1))
	var price := int(definition.get("purchase_price", 0))
	var size_class := String(definition.get("size_class", "S"))

	if player_level < required_level:
		return {
			"can_purchase": false,
			"reason": "🔒 LV %d" % required_level
		}
	if coins < price:
		return {
			"can_purchase": false,
			"reason": "NEED 🪙 %s" % _format_number(price - coins)
		}

	var infrastructure := airport_grid.get_aircraft_infrastructure_status(
		size_class
	)
	if not bool(infrastructure.get("hangar", false)):
		return {
			"can_purchase": false,
			"reason": "NEED %s HANGAR" % size_class
		}
	if not bool(infrastructure.get("stand_and_runway", false)):
		return {
			"can_purchase": false,
			"reason": "NEED %s STAND/RUNWAY" % size_class
		}
	if not bool(infrastructure.get("fuel", false)):
		return {
			"can_purchase": false,
			"reason": "NEED %s FUEL" % size_class
		}

	var capacity := FleetRules.capacity_status(
		airport_grid.get_hangar_sources(),
		_owned_aircraft_definitions(),
		definition
	)
	if not bool(capacity.get("allowed", false)):
		var blocking_size := String(capacity.get("blocking_size", size_class))
		return {
			"can_purchase": false,
			"reason": "%s HANGAR FULL" % blocking_size
		}

	return {
		"can_purchase": true,
		"reason": "BUY"
	}


func _refresh_fleet_panel() -> void:
	var owned_entries: Array[Dictionary] = []
	for record in fleet_records:
		var definition := AircraftCatalog.get_definition(
			String(record.get("aircraft_id", ""))
		)
		if definition.is_empty():
			continue

		var aircraft := record.get("aircraft") as AircraftPrototype
		var state := "HANGAR"
		var destination := ""
		var route_hint := "Stored in hangar • select a route when a stand is free."
		if aircraft != null and is_instance_valid(aircraft):
			state = aircraft.state
			var manifest := aircraft.get_flight_manifest()
			if not manifest.is_empty():
				destination = String(
					manifest.get("destination_name", "")
				)
				route_hint = "Assigned to %s • route locks once servicing starts." % destination
			elif state in ["WAITING_FUEL", "PARKED"]:
				route_hint = "Awaiting destination • choose a route below."
			else:
				route_hint = state.replace("_", " ").capitalize()

		owned_entries.append({
			"fleet_uid": int(record.get("fleet_uid", -1)),
			"label": String(record.get("label", "Aircraft")),
			"aircraft_id": String(definition.get("id", "")),
			"name": String(definition.get("name", "Aircraft")),
			"size_class": String(definition.get("size_class", "S")),
			"capacity": int(definition.get("capacity", 0)),
			"range_km": int(definition.get("range_km", 0)),
			"state": state,
			"destination_name": destination,
			"route_hint": route_hint
		})

	var catalog_entries: Array[Dictionary] = []
	for definition in AircraftCatalog.all():
		var entry := definition.duplicate(true)
		var status := _purchase_status(definition)
		entry["can_purchase"] = bool(status.get("can_purchase", false))
		entry["purchase_reason"] = String(status.get("reason", ""))
		catalog_entries.append(entry)

	var route_entries := _route_entries_for_selected()
	var capacity := FleetRules.capacity_status(
		airport_grid.get_hangar_sources(),
		_owned_aircraft_definitions()
	)
	hud.set_fleet_data(
		owned_entries,
		catalog_entries,
		route_entries,
		selected_fleet_uid,
		capacity
	)
	hud.set_world_data(
		owned_entries,
		route_entries,
		selected_fleet_uid,
		resource_inventory
	)


func _route_entries_for_selected() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := _fleet_record_index(selected_fleet_uid)
	if index < 0:
		return result

	var record: Dictionary = fleet_records[index]
	var definition := AircraftCatalog.get_definition(
		String(record.get("aircraft_id", ""))
	)
	if definition.is_empty():
		return result

	var aircraft := record.get("aircraft") as AircraftPrototype
	var can_assign_now := false
	var current_route_id := ""
	if aircraft == null or not is_instance_valid(aircraft):
		can_assign_now = not _find_free_departure_route(
			String(definition.get("size_class", "S"))
		).is_empty()
	else:
		var current_manifest := aircraft.get_flight_manifest()
		if not current_manifest.is_empty():
			current_route_id = String(
				current_manifest.get("route_id", "")
			)
		else:
			can_assign_now = aircraft.state in ["WAITING_FUEL", "PARKED"]

	for route in RouteCatalog.all():
		var entry := route.duplicate(true)
		var unlock_level := int(route.get("unlock_level", 1))
		var distance_km := int(route.get("distance_km", 0))
		var range_km := int(definition.get("range_km", 0))
		var aircraft_rank := AircraftCatalog.size_rank(
			String(definition.get("size_class", "S"))
		)
		var route_rank := AircraftCatalog.size_rank(
			String(route.get("max_aircraft_size", "XL"))
		)

		if player_level < unlock_level:
			entry["compatible"] = false
			entry["can_dispatch"] = false
			entry["reason"] = "🔒 AIRPORT LV %d" % unlock_level
		elif aircraft_rank > route_rank:
			entry["compatible"] = false
			entry["can_dispatch"] = false
			entry["reason"] = "%s-class aircraft too large" % String(
				definition.get("size_class", "S")
			)
		elif distance_km > range_km:
			entry["compatible"] = false
			entry["can_dispatch"] = false
			entry["reason"] = "Needs %d km range • aircraft has %d km" % [
				distance_km,
				range_km
			]
		else:
			var manifest := FlightEconomy.calculate_manifest(
				definition,
				route,
				player_level
			)
			for key in manifest.keys():
				entry[key] = manifest[key]
			entry["compatible"] = true
			entry["can_dispatch"] = can_assign_now
			if not can_assign_now and current_route_id.is_empty():
				entry["reason"] = "No free compatible stand"
			elif not current_route_id.is_empty():
				entry["reason"] = "Aircraft already assigned"

		entry["selected"] = (
			not current_route_id.is_empty()
			and current_route_id == String(route.get("id", ""))
		)
		result.append(entry)

	return result


func _on_fleet_aircraft_selected(fleet_uid: int) -> void:
	if _fleet_record_index(fleet_uid) < 0:
		return
	selected_fleet_uid = fleet_uid
	_refresh_fleet_panel()


func _on_fleet_aircraft_purchase_requested(aircraft_id: String) -> void:
	var definition := AircraftCatalog.get_definition(aircraft_id)
	if definition.is_empty():
		return

	var status := _purchase_status(definition)
	if not bool(status.get("can_purchase", false)):
		hud.set_flight_status(
			"Cannot buy %s • %s" % [
				String(definition.get("name", "Aircraft")),
				String(status.get("reason", "requirements not met"))
			],
			"warning"
		)
		_refresh_fleet_panel()
		return

	coins -= int(definition.get("purchase_price", 0))
	var fleet_uid := _add_fleet_record(definition)
	selected_fleet_uid = fleet_uid
	_refresh_player_hud()
	_refresh_fleet_panel()

	hud.set_flight_status(
		"%s purchased • stored in hangar as SO-%03d" % [
			String(definition.get("name", "Aircraft")),
			fleet_uid
		],
		"success"
	)


func _on_fleet_route_requested(fleet_uid: int, route_id: String) -> void:
	var index := _fleet_record_index(fleet_uid)
	if index < 0:
		return

	var record: Dictionary = fleet_records[index]
	var definition := AircraftCatalog.get_definition(
		String(record.get("aircraft_id", ""))
	)
	var route := RouteCatalog.get_definition(route_id)
	var manifest := FlightEconomy.calculate_manifest(
		definition,
		route,
		player_level
	)
	if manifest.is_empty():
		hud.set_flight_status("That route is not compatible.", "warning")
		return

	var aircraft := record.get("aircraft") as AircraftPrototype
	if aircraft == null or not is_instance_valid(aircraft):
		var route_info := _find_free_departure_route(
			String(definition.get("size_class", "S"))
		)
		if route_info.is_empty():
			hud.set_flight_status(
				"No free compatible stand is available for %s." % String(
					record.get("label", "Aircraft")
				),
				"warning"
			)
			_refresh_fleet_panel()
			return
		aircraft = _deploy_fleet_record(fleet_uid, route_info)
		if aircraft == null:
			return

	if not aircraft.get_flight_manifest().is_empty():
		hud.set_flight_status(
			"%s already has a route assigned." % String(
				record.get("label", "Aircraft")
			),
			"warning"
		)
		return

	if aircraft.state not in ["WAITING_FUEL", "PARKED"]:
		hud.set_flight_status(
			"%s is currently busy." % String(record.get("label", "Aircraft")),
			"warning"
		)
		return

	aircraft.assign_flight(manifest)
	var label := String(record.get("label", "Aircraft"))
	ground_services.request_fuel(aircraft, label)
	hud.set_flight_status(
		"%s → %s • %d/%d pax • %d min • 🪙 +%s net" % [
			label,
			String(manifest.get("destination_name", "Destination")),
			int(manifest.get("passengers", 0)),
			int(manifest.get("capacity", 0)),
			int(manifest.get("duration_minutes", 0)),
			_format_number(int(manifest.get("net_profit", 0)))
		],
		"success"
	)
	_refresh_fleet_panel()


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
	var resource_result := _award_country_resources(manifest)
	_refresh_player_hud()

	var settlement_text := "%s returned from %s • +🪙 %s net • +%d XP" % [
		label,
		String(manifest.get("destination_name", "route")),
		_format_number(profit),
		xp_reward
	]
	if not resource_result.is_empty():
		settlement_text += " • " + resource_result

	hud.set_flight_status(
		settlement_text,
		"success"
	)

	if player_level > previous_level:
		hud.set_operation_status(
			"Airport level %d reached • new aircraft/routes unlocked" % player_level,
			"success"
		)

	aircraft.clear_flight_manifest()


func _award_country_resources(manifest: Dictionary) -> String:
	var country_code := String(manifest.get("country_code", ""))
	if country_code.is_empty():
		return ""

	var chance := float(manifest.get("resource_drop_chance", 0.40))
	var drops := CountryCatalog.roll_resource_drops(
		country_code,
		chance
	)
	if drops.is_empty():
		return "No country resources this flight"

	var names := PackedStringArray()
	for drop in drops:
		var resource_id := String(drop.get("id", ""))
		if resource_id.is_empty():
			continue
		resource_inventory[resource_id] = int(
			resource_inventory.get(resource_id, 0)
		) + 1
		names.append("+1 " + String(drop.get("name", "Resource")))

	return ", ".join(names)


func _on_aircraft_serviced(aircraft: AircraftPrototype, label: String) -> void:
	runway_dispatcher.request_departure(aircraft, label)
	_refresh_fleet_panel()


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
					"%s → %s • %d/%d pax • ~%d min • est. 🪙 %s net" % [
						label,
						String(manifest.get("destination_name", "Destination")),
						int(manifest.get("passengers", 0)),
						int(manifest.get("capacity", 0)),
						int(manifest.get("duration_minutes", 0)),
						_format_number(int(manifest.get("net_profit", 0)))
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
			hud.set_operation_status("%s parked • awaiting route/fuel" % label)

	_refresh_fleet_panel()


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
	_refresh_fleet_panel()


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
	_refresh_fleet_panel()


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
	_refresh_fleet_panel()


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
		_refresh_fleet_panel()
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
	hud.set_flight_status(
		"%s is parked • choose its next destination in FLEET" % label,
		"warning"
	)
	_refresh_fleet_panel()


func _refresh_player_hud() -> void:
	hud.set_player_data(
		player_level,
		coins,
		gems,
		airport_xp,
		LevelProgression.xp_to_next(player_level)
	)


func _on_world_tapped(world_position: Vector2) -> void:
	if hud.is_management_overlay_open():
		return

	if not selected_building_id.is_empty():
		var status: Dictionary = airport_grid.set_build_preview(
			selected_building_id,
			world_position,
			selected_building_rotation
		)
		var definition: Dictionary = BuildingCatalog.get_definition(
			selected_building_id
		)
		hud.show_build_preview(definition, status, player_level, coins)
		return

	airport_grid.select_world_position(world_position)


func _on_network_status_changed(status: Dictionary) -> void:
	hud.set_airside_status(status)
	_refresh_fleet_panel()


func _on_parcel_selected(_parcel_id: String, parcel_data: Dictionary) -> void:
	if selected_building_id.is_empty() and not hud.is_management_overlay_open():
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
	_refresh_player_hud()
	hud.show_parcel(
		airport_grid.get_selected_parcel(),
		player_level,
		coins
	)
	_refresh_fleet_panel()


func _on_building_selected(building_id: String) -> void:
	var definition := BuildingCatalog.get_definition(building_id)
	if definition.is_empty():
		return

	hud.close_fleet()
	hud.close_world()
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
		status = airport_grid.refresh_build_preview(
			selected_building_rotation
		)
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
		hud.show_build_preview(
			definition,
			status,
			player_level,
			coins
		)
		return

	if not bool(status.get("valid", false)):
		hud.show_build_preview(
			definition,
			status,
			player_level,
			coins
		)
		return

	var placed: Dictionary = airport_grid.confirm_build_preview()
	if placed.is_empty():
		return

	coins -= cost
	_refresh_player_hud()
	hud.show_build_preview(definition, {}, player_level, coins)
	_refresh_fleet_panel()


func _on_cancel_building_requested() -> void:
	selected_building_id = ""
	selected_building_rotation = 0
	airport_grid.clear_build_preview()
	hud.exit_building_mode()


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[index] + result
		count += 1
	return result
