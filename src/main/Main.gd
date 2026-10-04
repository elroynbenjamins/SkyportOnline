extends Node2D

@onready var airport_grid = $AirportGrid
@onready var camera_controller = $Camera
@onready var hud = $HUD

var player_level: int = 4
var coins: int = 18420
var gems: int = 120

var selected_building_id := ""
var selected_building_rotation := 0
var aircraft_demo: AircraftPrototype
var fuel_truck_demo: FuelTruckPrototype


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
	_spawn_aircraft_demo()


func _spawn_aircraft_demo() -> void:
	var route := airport_grid.get_first_departure_route("S")
	if route.size() < 2:
		hud.set_operation_status("No connected S-class stand/runway.", "warning")
		return

	aircraft_demo = AircraftPrototype.new()
	aircraft_demo.z_index = 80
	aircraft_demo.state_changed.connect(_on_demo_aircraft_state_changed)
	add_child(aircraft_demo)
	aircraft_demo.set_departure_route(route, "S")
	hud.set_operation_status("Aircraft parked • fuel required")
	_dispatch_demo_fuel_truck()


func _dispatch_demo_fuel_truck() -> void:
	if aircraft_demo == null:
		return

	var station := airport_grid.get_best_service_building("fuel", aircraft_demo.aircraft_size)
	if station.is_empty():
		hud.set_operation_status("No compatible fuel station.", "warning")
		return

	fuel_truck_demo = FuelTruckPrototype.new()
	fuel_truck_demo.z_index = 90
	fuel_truck_demo.service_started.connect(_on_demo_fuel_started)
	fuel_truck_demo.service_completed.connect(_on_demo_fuel_completed)
	fuel_truck_demo.returned_to_station.connect(_on_demo_fuel_returned)
	add_child(fuel_truck_demo)

	var service_speed := maxf(float(station.get("service_speed", 1.0)), 0.1)
	var service_duration := 6.0 / service_speed
	fuel_truck_demo.start_service(
		station["world_position"],
		aircraft_demo.position,
		service_duration
	)

	hud.set_operation_status(
		"Fuel truck dispatched • x%.1f speed" % service_speed
	)


func _on_demo_fuel_started() -> void:
	hud.set_operation_status("Fueling aircraft...")


func _on_demo_fuel_completed() -> void:
	if aircraft_demo != null:
		aircraft_demo.begin_departure_after_service()
	hud.set_operation_status("Fuel complete • preparing taxi", "success")


func _on_demo_fuel_returned() -> void:
	fuel_truck_demo = null


func _on_demo_aircraft_state_changed(state: String) -> void:
	match state:
		"TAXIING":
			hud.set_operation_status("Aircraft taxiing to runway")
		"HOLDING":
			hud.set_operation_status("Aircraft at runway end • ready", "success")
		"WAITING_FUEL":
			hud.set_operation_status("Aircraft parked • fuel required")


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
