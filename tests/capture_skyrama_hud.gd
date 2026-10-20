extends SceneTree

const WORLD_OUTPUT := "res://artifacts/skyrama_hud_world.png"
const BUILD_OUTPUT := "res://artifacts/skyrama_hud_build.png"
const BUILDING_CARD_OUTPUT := "res://artifacts/skyrama_building_card.png"
const AIRCRAFT_CARD_OUTPUT := "res://artifacts/skyrama_aircraft_card.png"
const COMPACT_CARD_OUTPUT := "res://artifacts/skyrama_compact_card.png"


func _init() -> void:
	call_deferred("_run")


func _capture(path: String) -> bool:
	for _frame in range(5):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("HUD QA viewport screenshot is empty.")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("Cannot save HUD QA screenshot: %s, error %d" % [path, error])
		return false
	return true


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)

	var backdrop := AirportBackdrop.new()
	world.add_child(backdrop)
	var grid := AirportGrid.new()
	world.add_child(grid)
	await process_frame
	grid.prepare_new_airport_builder_layout()

	var camera := Camera2D.new()
	camera.enabled = true
	camera.position = Vector2(0, 350)
	camera.zoom = Vector2(0.9, 0.9)
	world.add_child(camera)

	var hud = load("res://src/ui/HUD.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_build_catalog(BuildingCatalog.get_menu_definitions())
	hud.set_airport_identity("Skyport", "AMS", "Netherlands", "guest")
	hud.set_player_data(7, 42850, 120)
	hud.set_level_progress(1250, 0, 2000)
	hud.set_passenger_data(842, 1000, 2.0)
	hud.set_fuel_data(180, 360, 1.6)
	hud.set_airside_status(grid.get_airside_status())
	hud.set_operation_status("Aircraft ready • select Fleet to plan a flight")
	if not await _capture(WORLD_OUTPUT):
		quit(1)
		return

	hud._on_build_navigation_pressed()
	if not await _capture(BUILD_OUTPUT):
		quit(1)
		return

	hud._on_catalog_close_pressed()

	var building_card := BuildingContextCard.new()
	root.add_child(building_card)
	await process_frame
	building_card.show_building(
		{"uid": 10, "definition_id": "basic_fuel", "upgrade_level": 1},
		{
			"role": "Fuel service",
			"status": "Ready • no planes queued",
			"tone": "success",
			"stat_one": "SERVICE SPEED\nx1.00",
			"stat_two": "PLANES\n1",
			"description": "Fuel planes using their separate parking pads.",
			"primary_label": "UPGRADE",
			"primary_kind": "hud_mint",
			"show_move": true,
			"show_details": true
		}
	)
	if not await _capture(BUILDING_CARD_OUTPUT):
		quit(1)
		return
	building_card.close_card()

	var aircraft := AircraftPrototype.new()
	aircraft.name = "SO-001"
	world.add_child(aircraft)
	await process_frame
	aircraft.configure_aircraft_type("pico_p8")
	aircraft.configure_skyrama_handling(true)
	aircraft.start_simple_fueling(Vector2(95, 190), 75.0)
	var aircraft_card := AircraftContextCard.new()
	root.add_child(aircraft_card)
	await process_frame
	aircraft_card.show_aircraft(aircraft, {}, 60, 120)
	if not await _capture(AIRCRAFT_CARD_OUTPUT):
		quit(1)
		return

	root.size = Vector2i(820, 360)
	await process_frame
	aircraft_card._update_card_layout(Vector2i(820, 360))
	if not await _capture(COMPACT_CARD_OUTPUT):
		quit(1)
		return

	print("SKYRAMA_HUD_SCREENSHOTS_OK world=%s build=%s building=%s aircraft=%s compact=%s" % [
		WORLD_OUTPUT, BUILD_OUTPUT, BUILDING_CARD_OUTPUT,
		AIRCRAFT_CARD_OUTPUT, COMPACT_CARD_OUTPUT
	])
	quit(0)
