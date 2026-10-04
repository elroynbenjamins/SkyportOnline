extends SceneTree


var selected_building: Dictionary = {}
var primary_emitted := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := AirportGrid.new()
	root.add_child(grid)
	await process_frame

	grid.building_selected_world.connect(_on_building_selected)

	var fuel_world := grid.tile_to_world(Vector2(13, 13))
	grid.select_world_position(fuel_world)

	if selected_building.is_empty():
		_fail("Tapping a placed building should emit building selection.")
		return
	if String(
		selected_building.get("definition_id", "")
	) != "basic_fuel":
		_fail("Fuel-station tap should select the Basic Fuel Station.")
		return

	var card := BuildingContextCard.new()
	root.add_child(card)
	await process_frame

	card.show_building(
		selected_building,
		{
			"role": "Ground service",
			"status": "No queue • service available",
			"tone": "success",
			"stat_one": "SERVICE SPEED\nx1.00",
			"stat_two": "VEHICLES\n1",
			"primary_label": "UPGRADE",
			"primary_kind": "primary"
		}
	)

	if not card.is_open():
		_fail("Building context card should open.")
		return
	if not card.title_label.text.contains("Basic Fuel Station"):
		_fail("Building card should show selected building name.")
		return
	if not card.title_label.text.contains("LV 1"):
		_fail("Building card should show upgrade level.")
		return
	if card.building_image.texture == null:
		_fail("Building card should load the building icon.")
		return
	if not card.stat_one_label.text.contains("x1.00"):
		_fail("Building card should show service speed stat.")
		return
	if not card.stat_two_label.text.contains("1"):
		_fail("Building card should show vehicle capacity stat.")
		return
	if card.primary_button.text != "UPGRADE":
		_fail("Upgradeable service building should expose Upgrade action.")
		return

	card.primary_action_requested.connect(
		_on_primary_action_requested
	)
	card._on_primary_pressed()
	if not primary_emitted:
		_fail("Building card primary action should emit selected building.")
		return

	var stand := grid.get_building(5)
	if stand.is_empty():
		# Starter stand UIDs can shift as starter content evolves.
		for uid in range(1, 30):
			var candidate := grid.get_building(uid)
			if String(
				candidate.get("definition_id", "")
			) == "small_stand":
				stand = candidate
				break

	if stand.is_empty():
		_fail("Starter airport should contain a Small Stand.")
		return

	card.show_building(
		stand,
		{
			"role": "Infrastructure",
			"status": "Connected to taxiway network",
			"tone": "success",
			"stat_one": "AIRCRAFT\nS",
			"stat_two": "FOOTPRINT\n2x2",
			"primary_label": ""
		}
	)

	if card.primary_button.visible:
		_fail("Non-upgradeable stand should not show management action.")
		return

	card.close_card()
	if card.is_open():
		_fail("Building context card should close cleanly.")
		return

	print(
		"Building context passed: airport tap, icon, live stats, "
		+ "upgrade action and non-upgradeable building state."
	)
	quit(0)


func _on_building_selected(building: Dictionary) -> void:
	selected_building = building.duplicate(true)


func _on_primary_action_requested(
	_building: Dictionary
) -> void:
	primary_emitted = true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
