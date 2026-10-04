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
	hud.set_player_data(player_level, coins, gems)
	hud.set_airside_status(airport_grid.get_airside_status())
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
	var routes := airport_grid.get_departure_routes("S")
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
		aircraft.name = label
		aircraft.z_index = 80 + index
		aircraft.state_changed.connect(_on_demo_aircraft_state_changed.bind(label))
		add_child(aircraft)
		aircraft.set_departure_route(
			route,
			"S",
			int(route_info.get("stand_uid", -1)),
			int(route_info.get("runway_uid", -1))
		)
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


func _on_demo_aircraft_state_changed(state: String, label: String) -> void:
	match state:
		"TAXIING":
			hud.set_operation_status("%s taxiing to runway" % label)
		"HOLDING":
			hud.set_operation_status("%s cleared runway" % label, "success")
		"READY_FOR_DEPARTURE":
			hud.set_operation_status("%s ready • waiting for runway" % label, "warning")
		"CLEARED":
			hud.set_operation_status("%s cleared for departure" % label, "success")
		"WAITING_FUEL":
			hud.set_operation_status("%s parked • fuel required" % label)


func _on_world_tapped(world_position: Vector2) -> void:
	if not selected_building_id.is_empty():
		var status := airport_grid.set_build_preview(
			selected_building_id,
			world_position,
			selected_building_rotation
		)
		var definition := BuildingCatalog.get_definition(selected_building_id)
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
	var status := airport_grid.get_build_preview_status()

	if player_level < required_level or coins < cost:
		hud.show_build_preview(definition, status, player_level, coins)
		return

	if not bool(status.get("valid", false)):
		hud.show_build_preview(definition, status, player_level, coins)
		return

	var placed := airport_grid.confirm_build_preview()
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
